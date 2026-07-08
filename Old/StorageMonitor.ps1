# =========================================================
# EXCHANGE ONLINE MAILBOX UTILITY & MANAGEMENT HUB
# =========================================================

# ---------------- CONFIGURATION ----------------

$Global:SandboxMode = $false  # Set to $false for real environment execution
$ScriptRunning      = $true
$RefreshIntervalSeconds = 30

# Mock states for Sandbox Mode tracking
$Global:SandboxArchiveEnabled   = $true
$Global:SandboxAutoExpandEnabled = $false
$Global:SandboxPolicy            = "Default-Archival-Policy"

# ---------------- GLOBAL HELPER FUNCTIONS ----------------

function Get-RawBytes {
    param($Value)

    if ($null -eq $Value) { return 0 }

    try {
        if ($Value.Value -and $Value.Value.ToBytes) {
            return [int64]$Value.Value.ToBytes()
        }
    } catch {}

    $StringStat = $Value.ToString()

    if ($StringStat -match '\((?<bytes>[\d,]+)\sbytes\)') {
        return [int64]($matches['bytes'] -replace ',', '')
    }

    $numericOnly = $StringStat -replace '[^\d]', ''

    if ($numericOnly -match '^\d+$') {
        return [int64]$numericOnly
    }

    return 0
}

function Wait-Console {
    Read-Host "`nPress Enter to continue"
}

function Write-ToggleStatus {
    param([bool]$State)
    if ($State) {
        Write-Host " [" -NoNewline; Write-Host "ON" -ForegroundColor Green -NoNewline; Write-Host "]"
    } else {
        Write-Host " [" -NoNewline; Write-Host "OFF" -ForegroundColor Red -NoNewline; Write-Host "]"
    }
}

function Get-ArchiveTagsFromPolicy {
    param([string]$PolicyName)

    $Tags = @()
    if ([string]::IsNullOrWhiteSpace($PolicyName)) { return $Tags }
    
    try {
        $Policy = Get-RetentionPolicy $PolicyName -ErrorAction Stop
        foreach ($TagName in $Policy.RetentionPolicyTagLinks) {
            try {
                $Tag = Get-RetentionPolicyTag $TagName -ErrorAction Stop
                if ($Tag.RetentionAction -eq "MoveToArchive") {
                    $Tags += $Tag
                }
            } catch {}
        }
    } catch {}
    return $Tags
}

function Connect-EXO {
    if ($Global:SandboxMode) { return "SANDBOX-ENVIRONMENT (OFFLINE)" }

    Write-Host "Verifying Exchange Online Session..." -ForegroundColor Gray
    try {
        $OrgInfo = Get-OrganizationConfig -ErrorAction Stop
    } catch {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
        Connect-ExchangeOnline -ShowBanner:$false
        $OrgInfo = Get-OrganizationConfig
    }

    return $(if ($OrgInfo.DisplayName) { $OrgInfo.DisplayName } else { $OrgInfo.Identity })
}

function Show-MainMenuHeader {
    param(
        [string]$Tenant,
        [bool]$Sandbox
    )
    Clear-Host
    $HeaderCol = if ($Sandbox) { "Yellow" } else { "Cyan" }

    Write-Host " === EXO MAILBOX TOOL [$Tenant] === " -BackgroundColor $HeaderCol -ForegroundColor Black
    Write-Host "------------------------------------------------------------"
    Write-Host " 1. Search for User"
    Write-Host " 2. Enter Email Manually"
    Write-Host " 3. Bulk Operations (via CSV)"
    Write-Host " 4. Export Mailboxes Report"
    Write-Host " 5. Switch Tenant / Sign Out"
    Write-Host " 0. Exit Script"
    Write-Host "------------------------------------------------------------"
}

# ---------------- EXPORT ENGINE MENU ----------------

function Invoke-MailboxExportMenu {
    $InExportMenu = $true
    $ExportLength = 0
    $ExportPath   = "$env:USERPROFILE\Desktop\MailboxReport.csv"

    while ($InExportMenu) {
        Clear-Host
        Write-Host " --- EXPORT MAILBOXES ENGINE --- " -BackgroundColor Cyan -ForegroundColor Black
        Write-Host "------------------------------------------------------------"
        Write-Host " 1. Start Export"
        Write-Host " 2. Choose Length Threshold (Current: $(if($ExportLength -eq 0){"All"}else{$ExportLength}))"
        Write-Host " 3. Modify Target File Path (Current: $ExportPath)"
        Write-Host " 0. Back"
        Write-Host "------------------------------------------------------------"

        $ExpChoice = Read-Host "Selection"

        switch ($ExpChoice) {
            "0" { $InExportMenu = $false }
            
            "2" {
                $LenInput = Read-Host "Enter amount of mailboxes to pull (0 for All)"
                if ($LenInput -match '^\d+$') { $ExportLength = [int]$LenInput }
            }
            
            "3" {
                $PathInput = Read-Host "Enter full file path (e.g. C:\temp\report.csv)"
                if (-not [string]::IsNullOrWhiteSpace($PathInput)) { $ExportPath = $PathInput }
            }
            
            "1" {
                Clear-Host
                Write-Host "Starting Mailbox Data Export Pipeline..." -ForegroundColor Cyan
                $ReportData = @()

                if ($Global:SandboxMode) {
                    Write-Host "Sandbox Environment Active: Generating structural dummy arrays..." -ForegroundColor Yellow
                    $ReportData += [PSCustomObject]@{
                        DisplayName               = "Tanith Sandbox"
                        UserPrincipalName         = "tanith@pfsa.org.za"
                        PrimarySizeBytes          = 47244640256
                        PrimarySizeGB             = 44.00
                        PrimaryQuotaGB            = 50.00
                        PrimaryPercentUsed        = 88.00
                        PrimaryWarningGB          = 49.00
                        ArchiveSizeBytes          = 12884901888
                        ArchiveSizeGB             = 12.00
                        ArchiveQuotaGB            = 100.00
                        ArchivePercentUsed        = 12.00
                        AutoExpandingArchiveReady = $true
                        RetentionPolicy           = "Sandbox Dynamic Policy"
                    }
                    Start-Sleep -Seconds 2
                } else {
                    $ResultSize = if ($ExportLength -eq 0) { "Unlimited" } else { $ExportLength }
                    Write-Host "Fetching cloud user object directories..." -ForegroundColor Gray
                    
                    $Mailboxes = Get-Mailbox -ResultSize $ResultSize -RecipientTypeDetails UserMailbox
                    $Total = $Mailboxes.Count
                    $Counter = 0

                    foreach ($mbx in $Mailboxes) {
                        $Counter++
                        Write-Progress -Activity "Gathering Mailbox Statistics" -Status "Processing $($mbx.DisplayName) ($Counter of $Total)" -PercentComplete (($Counter / $Total) * 100)

                        $Stats = Get-MailboxStatistics -Identity $mbx.UserPrincipalName -ErrorAction SilentlyContinue
                        $Arch  = Get-MailboxStatistics -Identity $mbx.UserPrincipalName -Archive -ErrorAction SilentlyContinue

                        # Primary Metric Data Calculation
                        $pSize   = Get-RawBytes $Stats.TotalItemSize
                        $pLimit  = Get-RawBytes $mbx.ProhibitSendQuota
                        $pWarn   = Get-RawBytes $mbx.IssueWarningQuota
                        
                        $pSizeGB = if ($pSize -gt 0) { [math]::Round($pSize / 1GB, 2) } else { 0 }
                        $pLimGB  = if ($pLimit -gt 0) { [math]::Round($pLimit / 1GB, 2) } else { 0 }
                        $pWarnGB = if ($pWarn -gt 0) { [math]::Round($pWarn / 1GB, 2) } else { 0 }
                        $pPerc   = if ($pLimit -gt 0) { [math]::Round(($pSize / $pLimit) * 100, 2) } else { 0 }

                        # Archive Metric Data Calculation
                        $aSize   = if ($Arch) { Get-RawBytes $Arch.TotalItemSize } else { 0 }
                        $aLimit  = Get-RawBytes $mbx.ArchiveQuota
                        
                        $aSizeGB = if ($aSize -gt 0) { [math]::Round($aSize / 1GB, 2) } else { 0 }
                        $aLimGB  = if ($aLimit -gt 0) { [math]::Round($aLimit / 1GB, 2) } else { 0 }
                        $aPerc   = if ($aLimit -gt 0) { [math]::Round(($aSize / $aLimit) * 100, 2) } else { 0 }

                        $ReportData += [PSCustomObject]@{
                            DisplayName               = $mbx.DisplayName
                            UserPrincipalName         = $mbx.UserPrincipalName
                            MailboxCreated            = $mbx.WhenMailboxCreated
                            PrimarySizeBytes          = $pSize
                            PrimarySizeGB             = $pSizeGB
                            PrimaryQuotaGB            = $pLimGB
                            PrimaryPercentUsed        = $pPerc
                            PrimaryWarningGB          = $pWarnGB
                            ArchiveSizeBytes          = $aSize
                            ArchiveSizeGB             = $aSizeGB
                            ArchiveQuotaGB            = $aLimGB
                            ArchivePercentUsed        = $aPerc
                            AutoExpandingArchiveReady = $mbx.AutoExpandingArchiveEnabled
                            RetentionPolicy           = $mbx.RetentionPolicy
                        }
                    }
                }

                # Export Runtime Data to Local File Systems
                try {
                    $ReportData | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                    Write-Host "`nCSV File Generation Completed Successfully!" -ForegroundColor Green
                    Write-Host "Output Vector Path: $ExportPath" -ForegroundColor Gray
                } catch {
                    Write-Host "`nSystem Critical Failure Writing CSV Asset: $($_.Exception.Message)" -ForegroundColor Red
                }
                Wait-Console
            }
        }
    }
}

# ---------------- MANAGEMENT MENU FUNCTIONS ----------------

function Invoke-ArchivalRulesMenu {
    param([string]$Identity)

    $ArchivalMenuRunning = $true
    while ($ArchivalMenuRunning) {
        Clear-Host
        
        if ($Global:SandboxMode) {
            $ArchiveStatus = $Global:SandboxArchiveEnabled
            $CurrentPolicy = $Global:SandboxPolicy
            $Tags = @([PSCustomObject]@{ Name = "Sandbox-Move-1Yr"; AgeLimitForRetention = "365.00:00:00" })
        } else {
            try {
                $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
                $ArchiveStatus = ($Mbx.ArchiveStatus -match "Active|Enabled")
                $CurrentPolicy = $Mbx.RetentionPolicy
                $Tags = Get-ArchiveTagsFromPolicy -PolicyName $CurrentPolicy
            } catch {
                Write-Host "Error accessing mailbox configurations: $($_.Exception.Message)" -ForegroundColor Red
                Wait-Console
                return
            }
        }

        Write-Host " [ MANAGE ARCHIVAL RULES: $Identity ] " -BackgroundColor Magenta -ForegroundColor White
        Write-Host "------------------------------------------------------------"
        Write-Host " 1. Auto Archiving Status: " -NoNewline
        Write-ToggleStatus -State $ArchiveStatus

        Write-Host "`n Current Active Rule Details:" -ForegroundColor Gray
        if ([string]::IsNullOrWhiteSpace($CurrentPolicy)) {
            Write-Host "   No Retention Policy baseline assigned." -ForegroundColor Yellow
        } else {
            Write-Host "   Policy Container: $CurrentPolicy" -ForegroundColor Cyan
            foreach ($Tag in $Tags) {
                $DaysStr = "Unlimited/Never"
                if ($null -ne $Tag.AgeLimitForRetention) {
                    $rawAge = $Tag.AgeLimitForRetention.ToString()
                    if ($rawAge -match '^(\d+)\.') { $DaysStr = "$($matches[1]) days" }
                    elseif ($Tag.AgeLimitForRetention.Days -gt 0) { $DaysStr = "$($Tag.AgeLimitForRetention.Days) days" }
                    else { $DaysStr = "$rawAge days" }
                }
                Write-Host "    -> Tag Mapping: $($Tag.Name) (Moves after $DaysStr)" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "------------------------------------------------------------"
        Write-Host " 2. View System Policies / Change Assignment"
        Write-Host " 3. Force Instantiation Loop (Run Managed Folder Assistant)" -ForegroundColor Yellow
        Write-Host " 0. Back"
        Write-Host "------------------------------------------------------------"

        $Choice = Read-Host "Selection"

        switch ($Choice) {
            "1" {
                if ($ArchiveStatus) {
                    Write-Host "`nRequesting Archive Provision Reversal..." -ForegroundColor Gray
                    if ($Global:SandboxMode) { $Global:SandboxArchiveEnabled = $false }
                    else {
                        try { Disable-Mailbox -Identity $Identity -Archive -Confirm:$false -ErrorAction Stop }
                        catch { Write-Host "Execution Halted: $($_.Exception.Message)" -ForegroundColor Red; Wait-Console }
                    }
                } else {
                    Write-Host "`nProvisioning Online Archive Module..." -ForegroundColor Gray
                    if ($Global:SandboxMode) { $Global:SandboxArchiveEnabled = $true }
                    else {
                        try { Enable-Mailbox -Identity $Identity -Archive -ErrorAction Stop }
                        catch { Write-Host "Execution Halted: $($_.Exception.Message)" -ForegroundColor Red; Wait-Console }
                    }
                }
                Start-Sleep -Seconds 1
            }
            "2" {
                Show-RulesPaginationEngine -Identity $Identity
            }
            "3" {
                Write-Host "`nSignaling Managed Folder Assistant Engine Synchronization..." -ForegroundColor Cyan
                if ($Global:SandboxMode) {
                    Write-Host "[SANDBOX] MFA cycle execution processing simulation verified." -ForegroundColor Green
                } else {
                    try {
                        Start-ManagedFolderAssistant -Identity $Identity -ErrorAction Stop
                        Write-Host "Success! Target requested for immediate priority pipeline processing." -ForegroundColor Green
                    } catch {
                        Write-Host "Execution error calling backend background automation: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                Wait-Console
            }
            "0" { $ArchivalMenuRunning = $false }
        }
    }
}

function Show-RulesPaginationEngine {
    param([string]$Identity)

    if ($Global:SandboxMode) {
        $Policies = 1..14 | ForEach-Object { [PSCustomObject]@{ Name = "Mock-Policy-$_" } }
    } else {
        Write-Host "`nQuerying platform endpoints for retention collections..." -ForegroundColor Gray
        $Policies = @(Get-RetentionPolicy)
    }

    $Page = 0
    $PageSize = 8
    $Paginating = $true

    while ($Paginating) {
        Clear-Host
        Write-Host " [ RETENTION POLICY ASSIGNMENT SELECTION ENGINE ] " -BackgroundColor Cyan -ForegroundColor Black
        Write-Host " Pick an active structural object reference or select 'N' for a new template." -ForegroundColor Gray
        Write-Host "------------------------------------------------------------"

        $Start = $Page * $PageSize
        $End = [math]::Min($Start + $PageSize - 1, $Policies.Count - 1)
        $CurrentItems = $Policies[$Start..$End]

        for ($i = 0; $i -lt $CurrentItems.Count; $i++) {
            Write-Host " $($i + 1). $($CurrentItems[$i].Name)"
        }

        Write-Host "------------------------------------------------------------"
        if ($End -lt ($Policies.Count - 1)) {
            Write-Host " 9. Next Page --->" -ForegroundColor Yellow
        }
        Write-Host " N. Construct a New Rule Set & Container Policy" -ForegroundColor Magenta
        Write-Host " 0. Back"
        Write-Host "------------------------------------------------------------"

        $Sel = Read-Host "Select (Page $($Page + 1))"

        if ($Sel -eq '0') { $Paginating = $false } 
        elseif ($Sel -eq '9' -and $End -lt ($Policies.Count - 1)) { $Page++ } 
        elseif ($Sel -imatch 'N') {
            Write-Host "`n--- TOTAL USERS ---" -ForegroundColor Cyan
            $RuleName = Read-Host "Enter Unique Identifiable Rule Container Name"
            $Days = Read-Host "Enter Age Evaluation Threshold Window (In Days)"
            
            if ($Global:SandboxMode) {
                Write-Host "`n[SANDBOX] Asset Matrix Generated: $RuleName ($Days Days)" -ForegroundColor Green
                $Global:SandboxPolicy = $RuleName
            } else {
                try {
                    Write-Host "Compiling metadata tag configurations..." -ForegroundColor Gray
                    $NewTag = New-RetentionPolicyTag -Name "$RuleName-Tag" -Type All -RetentionEnabled $true -AgeLimitForRetention $Days -RetentionAction MoveToArchive -ErrorAction Stop
                    Write-Host "Constructing global execution container reference..." -ForegroundColor Gray
                    New-RetentionPolicy -Name $RuleName -RetentionPolicyTagLinks $NewTag.Name -ErrorAction Stop
                    Write-Host "`nObject instantiation sequence successfully deployed!" -ForegroundColor Green
                } catch {
                    Write-Host "`nDeployment sequence execution failure: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            Wait-Console
            $Paginating = $false
        } 
        elseif ($Sel -match '^\d$') {
            $Idx = [int]$Sel - 1
            if ($Idx -lt $CurrentItems.Count) {
                $SelectedPolicy = $CurrentItems[$Idx].Name
                
                if ($Global:SandboxMode) {
                    $Global:SandboxPolicy = $SelectedPolicy
                    Write-Host "`n[SANDBOX] Bound target configuration asset: $SelectedPolicy" -ForegroundColor Green
                } else {
                    Write-Host "`nMapping target rule profile modifications to cloud directory object..." -ForegroundColor Gray
                    try {
                        Set-Mailbox -Identity $Identity -RetentionPolicy $SelectedPolicy -ErrorAction Stop
                        Write-Host "Cloud structural database update committed!" -ForegroundColor Green
                    } catch {
                        Write-Host "Configuration pipeline validation rejected: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                Wait-Console
                $Paginating = $false
            }
        }
    }
}

function Invoke-AutoExpansionMenu {
    param([string]$Identity)

    $AutoExpandMenuRunning = $true
    while ($AutoExpandMenuRunning) {
        Clear-Host

        if ($Global:SandboxMode) {
            $AutoExpandEnabled = $Global:SandboxAutoExpandEnabled
        } else {
            try {
                $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
                $AutoExpandEnabled = $Mbx.AutoExpandingArchiveEnabled
            } catch {
                Write-Host "Failed evaluating feature directory structure properties: $($_.Exception.Message)" -ForegroundColor Red
                Wait-Console
                return
            }
        }

        Write-Host " [ AUTO EXPANSION ARCHITECTURE CONTROL LAYER: $Identity ] " -BackgroundColor DarkCyan -ForegroundColor White
        Write-Host "------------------------------------------------------------"
        Write-Host " 1. Auto Expansion Status: " -NoNewline
        Write-ToggleStatus -State $AutoExpandEnabled
        Write-Host "------------------------------------------------------------"
        Write-Host " 0. Back"
        Write-Host "------------------------------------------------------------"

        $Choice = Read-Host "Selection"

        switch ($Choice) {
            "1" {
                if ($AutoExpandEnabled) {
                    if ($Global:SandboxMode) {
                        $Global:SandboxAutoExpandEnabled = $false
                        Write-Host "State inverted." -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    } else {
                        Write-Host "`nWarning: Microsoft multi-tier storage layers structurally prohibit turning off expansion mechanisms once provisioned." -ForegroundColor Yellow
                        $Confirm = Read-Host "Attempt force cancellation override protocol sequences? (Y/N)"
                        if ($Confirm -imatch 'Y') {
                            try {
                                Disable-Mailbox -Identity $Identity -AutoExpandingArchive -ErrorAction Stop
                                Write-Host "Command accepted by remote endpoint parser." -ForegroundColor Green
                            } catch {
                                Write-Host "Operation natively blocked by cloud target framework: $($_.Exception.Message)" -ForegroundColor Red
                            }
                            Wait-Console
                        }
                    }
                } else {
                    Write-Host "`nInitializing deployment storage expander layers..." -ForegroundColor Gray
                    if ($Global:SandboxMode) {
                        $Global:SandboxAutoExpandEnabled = $true
                        Write-Host "State inverted." -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    } else {
                        try {
                            Enable-Mailbox -Identity $Identity -AutoExpandingArchive -ErrorAction Stop
                            Write-Host "Storage expansion layers provisioned successfully!" -ForegroundColor Green
                        } catch {
                            Write-Host "Deployment initialization validation failure: $($_.Exception.Message)" -ForegroundColor Red
                        }
                        Wait-Console
                    }
                }
            }
            "0" { $AutoExpandMenuRunning = $false }
        }
    }
}

# ---------------- USER HUB CONTAINER LOOP ----------------

function Invoke-UserHub {
    param([string]$Identity)

    $UserHubRunning = $true
    while ($UserHubRunning) {
        Clear-Host
        Write-Host " [ MANAGING USER INTERACTIVE HUB: $Identity ] " -BackgroundColor Blue -ForegroundColor White
        Write-Host "------------------------------------------------------------"
        Write-Host " 1. Manage Archival Rules"
        Write-Host " 2. Manage Auto Expansion"
        Write-Host " 3. Monitor Mailbox Storage (Live Analytics & Age Mapping)"
        Write-Host " 0. Back to Main Menu"
        Write-Host "------------------------------------------------------------"

        $HubChoice = Read-Host "Selection"

        switch ($HubChoice) {
            "1" { Invoke-ArchivalRulesMenu -Identity $Identity }
            "2" { Invoke-AutoExpansionMenu -Identity $Identity }
            "0" { $UserHubRunning = $false }
            "3" {
                try {
                    Write-Host "`nExtracting storage profiling metadata indexes..." -ForegroundColor Gray

                    if ($Global:SandboxMode) {
                        $primaryQuota = 50GB; $archiveQuota = 100GB
                        $policyName = $Global:SandboxPolicy; $isArchiveEnabled = $Global:SandboxArchiveEnabled
                        $archiveTags = @([PSCustomObject]@{ Name = "Sandbox-Move-1Yr"; AgeLimitForRetention = "365.00:00:00" })
                        $startSizeMB = 45000
                        $mbxCreated = (Get-Date).AddDays(-412)
                    } else {
                        $MailboxData = Get-Mailbox -Identity $Identity -ErrorAction Stop
                        $primaryQuota = Get-RawBytes $MailboxData.ProhibitSendQuota
                        $archiveQuota = Get-RawBytes $MailboxData.ArchiveQuota
                        $policyName = $MailboxData.RetentionPolicy
                        $isArchiveEnabled = ($MailboxData.ArchiveStatus -match "Active|Enabled")
                        $archiveTags = Get-ArchiveTagsFromPolicy -PolicyName $policyName
                        $mbxCreated = $MailboxData.WhenMailboxCreated
                        $StartStats = Get-MailboxStatistics -Identity $Identity -ErrorAction Stop
                        $startSizeMB = [math]::Round((Get-RawBytes $StartStats.TotalItemSize) / 1MB, 2)
                    }

                    $mbxAgeDays = if ($mbxCreated) { [math]::Round(((Get-Date) - $mbxCreated).TotalDays, 0) } else { "Unknown" }
                    $StartTime = Get-Date
                    $MonitoringUser = $true

                    while ($MonitoringUser) {
                        try {
                            $Elapsed = (Get-Date) - $StartTime
                            $ElapsedClock = $Elapsed.ToString("hh\:mm\:ss")

                            if ($Global:SandboxMode) {
                                $currentSizeMB = 44990; $archSizeMB = 12000
                            } else {
                                $CurrentStats = Get-MailboxStatistics -Identity $Identity -ErrorAction Stop
                                $currentSizeMB = [math]::Round((Get-RawBytes $CurrentStats.TotalItemSize) / 1MB, 2)
                                $archSizeMB = 0
                                if ($isArchiveEnabled) {
                                    try {
                                        $CurrentArchive = Get-MailboxStatistics -Identity $Identity -Archive -ErrorAction Stop
                                        $archSizeMB = [math]::Round((Get-RawBytes $CurrentArchive.TotalItemSize) / 1MB, 2)
                                    } catch { $archSizeMB = 0 }
                                }
                            }

                            $primaryLimitMB = [math]::Round($primaryQuota / 1MB, 2)
                            $archiveLimitMB = [math]::Round($archiveQuota / 1MB, 2)
                            $primaryPercent = if ($primaryLimitMB -gt 0) { [math]::Round(($currentSizeMB / $primaryLimitMB) * 100, 1) } else { 0 }
                            $archivePercent = if ($archiveLimitMB -gt 0) { [math]::Round(($archSizeMB / $archiveLimitMB) * 100, 1) } else { 0 }
                            $totalMovedMB = [math]::Max(0, ($startSizeMB - $currentSizeMB))

                            Clear-Host
                            Write-Host " Monitoring Account Database Vector: $Identity " -BackgroundColor Blue -ForegroundColor White
                            Write-Host " Latest Update: $(Get-Date -Format T)" -ForegroundColor Gray
                            Write-Host " Hotkeys: [R] Immediate Refresh | [B] Terminate Analytics Loop" -ForegroundColor Gray
                            Write-Host "------------------------------------------------------------"
                            Write-Host " PROVISIONED TIMESTAMPS: $mbxCreated (Object Lifespan: $mbxAgeDays days)" -ForegroundColor Cyan
                            Write-Host "------------------------------------------------------------"
                            Write-Host " RETENTION RULE: $policyName" -ForegroundColor Magenta
                            foreach ($Tag in $archiveTags) { 
                                $DaysStr = "Unlimited/Never"
                                if ($null -ne $Tag.AgeLimitForRetention) {
                                    $rawAge = $Tag.AgeLimitForRetention.ToString()
                                    if ($rawAge -match '^(\d+)\.') { $DaysStr = "$($matches[1]) days" }
                                    else { $DaysStr = "$rawAge days" }
                                }
                                Write-Host " -> Rule Template Mapping: $($Tag.Name) -> Execution Action at $DaysStr" -ForegroundColor DarkGray 
                            }
                            Write-Host "------------------------------------------------------------"
                            Write-Host " PRIMARY MAILBOX" -ForegroundColor Cyan
                            Write-Host (" Usage Metrics: {0} MB / {1} MB ({2}%)" -f $currentSizeMB, $primaryLimitMB, $primaryPercent) -ForegroundColor Yellow
                            Write-Host "------------------------------------------------------------"
                            if ($isArchiveEnabled) {
                                Write-Host " ONLINE ARCHIVE" -ForegroundColor Cyan
                                Write-Host (" Usage Metrics: {0} MB / {1} MB ({2}%)" -f $archSizeMB, $archiveLimitMB, $archivePercent) -ForegroundColor Green
                            } else {
                                Write-Host " ONLINE ARCHIVE: Unregistered/Disabled" -ForegroundColor Red
                            }
                            Write-Host "------------------------------------------------------------"
                            Write-Host " TOTAL MOVED DURING MONITORING SESSION: $totalMovedMB MB" -ForegroundColor White -BackgroundColor DarkBlue
                            Write-Host " MONITORING COMMENCED AT: $($StartTime.ToString('HH:mm:ss'))" -ForegroundColor White -BackgroundColor DarkBlue
                            Write-Host " TOTAL LENGTH: $ElapsedClock" -ForegroundColor White -BackgroundColor DarkBlue
                            Write-Host "------------------------------------------------------------"

                            $ForceRefresh = $false
                            for ($sec = $RefreshIntervalSeconds; $sec -gt 0; $sec--) {
                                Write-Host "`r Refreshing in $sec seconds...     " -NoNewline -ForegroundColor Gray
                                try {
                                    if ([Console]::KeyAvailable) {
                                        $key = [Console]::ReadKey($true)
                                        switch ($key.Key) {
                                            "R" { $ForceRefresh = $true; break }
                                            "B" { $MonitoringUser = $false; break }
                                        }
                                    }
                                } catch {}
                                Start-Sleep -Milliseconds 250
                                for ($i = 0; $i -lt 3; $i++) {
                                    try {
                                        if ([Console]::KeyAvailable) {
                                            $key = [Console]::ReadKey($true)
                                            switch ($key.Key) {
                                                "R" { $ForceRefresh = $true; break }
                                                "B" { $MonitoringUser = $false; break }
                                            }
                                        }
                                    } catch {}
                                    Start-Sleep -Milliseconds 250
                                }
                                if ($ForceRefresh -or -not $MonitoringUser) { break }
                            }

                            if (-not $MonitoringUser) { break }
                            if ($ForceRefresh) { continue }

                        } catch {
                            Write-Host "`nInteractive loop execution layer exception: $($_.Exception.Message)" -ForegroundColor Red
                            Wait-Console
                            break
                        }
                    }
                } catch {
                    Write-Host "`nProfiling parsing termination exception: $($_.Exception.Message)" -ForegroundColor Red
                    Wait-Console
                }
            }
        }
    }
}

# ---------------- INITIAL CONNECTION SEQUENCE ----------------

Clear-Host
$Global:CurrentOrg = Connect-EXO

Write-Host "Current session contextual target: $Global:CurrentOrg" -ForegroundColor Magenta
Start-Sleep -Seconds 1

# ---------------- CORE APPLICATION LOOP ----------------

while ($ScriptRunning) {

    Show-MainMenuHeader -Tenant $Global:CurrentOrg -Sandbox $Global:SandboxMode

    $MainMenuChoice = Read-Host "Selection"
    $TargetUserEmail = $null

    switch ($MainMenuChoice) {
        "0" {
            $ScriptRunning = $false
            continue
        }
        "4" {
            Invoke-MailboxExportMenu
            continue
        }
        "3" {
            $CsvPath = Read-Host "`nEnter full path to execution CSV mapping file (e.g., C:\temp\users.csv)"
            if (Test-Path $CsvPath) {
                $CsvData = Import-Csv $CsvPath
                
                # Highly dynamic header configuration loop matching engine
                $Emails = $CsvData | ForEach-Object { 
                    if ($_.Email) { $_.Email } 
                    elseif ($_.UserPrincipalName) { $_.UserPrincipalName } 
                    else { $_.Identity } 
                } | Where-Object { $_ }
                
                if ($Emails) {
                    $TargetPolicy = Read-Host "Enter targeted MRM Policy configuration (Leave blank for 'Default MRM Policy')"
                    if ([string]::IsNullOrWhiteSpace($TargetPolicy)) { $TargetPolicy = "Default MRM Policy" }

                    Write-Host "`n=== INITIATING BATCH PROCESSING PROFILER ON $($Emails.Count) OBJECTS ===" -ForegroundColor Cyan
                    foreach ($Email in $Emails) {
                        Write-Host "Modifying Target Mapping: $Email" -ForegroundColor Yellow
                        if ($Global:SandboxMode) {
                            Write-Host "  -> [SANDBOX] Mock batch transformation configuration complete." -ForegroundColor Green
                        } else {
                            try {
                                $Mbx = Get-Mailbox -Identity $Email -ErrorAction Stop
                                
                                # 1. Verify/Provision Archive Vector
                                if ($null -eq $Mbx.ArchiveGuid -or $Mbx.ArchiveGuid -eq [Guid]::Empty) {
                                    Write-Host "  -> Launching Storage Layer Prototyping... " -NoNewline -ForegroundColor Gray
                                    System.Management.Automation.CommandNotFoundException
                                    Enable-Mailbox -Identity $Email -Archive -ErrorAction Stop
                                    Write-Host "Success." -ForegroundColor Green
                                } else { Write-Host "  -> Storage layer profiling checks passed." -ForegroundColor DarkGray }

                                # 2. Map Target Compliance Matrices
                                if ($Mbx.RetentionPolicy -eq $TargetPolicy) {
                                    Write-Host "  -> Structural alignment verified for '$TargetPolicy'." -ForegroundColor DarkGray
                                } else {
                                    Write-Host "  -> Remapping container structural profiles to '$TargetPolicy'... " -NoNewline -ForegroundColor Gray
                                    Set-Mailbox -Identity $Email -RetentionPolicy $TargetPolicy -ErrorAction Stop
                                    Write-Host "Success." -ForegroundColor Green
                                }

                                # 3. Trigger MFA Acceleration Routine
                                Write-Host "  -> Accelerating cloud sync scheduling indexing... " -NoNewline -ForegroundColor Gray
                                Start-ManagedFolderAssistant -Identity $Email -ErrorAction SilentlyContinue
                                Write-Host "Queued." -ForegroundColor Green
                            } catch {
                                Write-Host "  [AUTOMATION ABORTED] Target rejected sequence: $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                    }
                } else {
                    Write-Host "System error mapping source columns: File must contain headers 'Email', 'UserPrincipalName', or 'Identity'." -ForegroundColor Red
                }
            } else {
                Write-Host "Target tracking script pointer dead. File missing at: $CsvPath" -ForegroundColor Red
            }
            Wait-Console
            continue
        }
        "5" {
            if (-not $Global:SandboxMode) {
                try {
                    Write-Host "`nTearing down secure infrastructure tunnels..." -ForegroundColor Gray
                    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Host "Re-initializing tenant profile validation routes..." -ForegroundColor Cyan
                    Connect-ExchangeOnline -ShowBanner:$false
                    $OrgInfo = Get-OrganizationConfig
                    $Global:CurrentOrg = $(if ($OrgInfo.DisplayName) { $OrgInfo.DisplayName } else { $OrgInfo.Identity })
                } catch {
                    Write-Host "Infrastructure handshake communication drop: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "`n[SANDBOX] Swapped execution paths to alternative fallback simulation data clusters." -ForegroundColor Yellow
                $Global:CurrentOrg = "Alternative-Mock-Cluster"
            }
            Wait-Console
            continue
        }
        "2" {
            $TargetUserEmail = Read-Host "`nEnter target account address explicitly"
        }
        "1" {
            $SearchTerm = Read-Host "`nEnter search term string criteria (Name/Email)"
            try {
                if ($Global:SandboxMode) {
                    $Results = @([PSCustomObject]@{ DisplayName = "Tanith Sandbox"; UserPrincipalName = "tanith@pfsa.org.za" })
                } else {
                    Write-Host "Searching tenant directory matrices..." -ForegroundColor Gray
                    $Results = @(Get-User -Filter "DisplayName -like '*$SearchTerm*' -or UserPrincipalName -like '*$SearchTerm*'" -ResultSize 15 | Where-Object { $_.UserPrincipalName })
                }

                if ($Results.Count -eq 0) {
                    Write-Host "`nZero elements returned from query execution paths." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                    continue
                }

                Clear-Host
                Write-Host "--- SYSTEM SEARCH QUERY RESULTS MATCHES ---" -ForegroundColor Cyan
                for ($i = 0; $i -lt $Results.Count; $i++) {
                    Write-Host " $($i + 1). $($Results[$i].DisplayName) ($($Results[$i].UserPrincipalName))"
                }

                $Selection = Read-Host "`nSelect User (or 'C' to Cancel)"
                if ($Selection -match '^\d+$') {
                    $Index = [int]$Selection - 1
                    if ($Index -ge 0 -and $Index -lt $Results.Count) {
                        $TargetUserEmail = $Results[$Index].UserPrincipalName
                    }
                }
            } catch {
                Write-Host "`nSystem failure navigating cloud data tree lookups: $($_.Exception.Message)" -ForegroundColor Red
                Wait-Console
                continue
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($TargetUserEmail)) { continue }

    # Route identified execution scope directly into Interactive Core Hub
    Invoke-UserHub -Identity $TargetUserEmail
}

# ---------------- RUNTIME CLEAN EXIT ROUTINES ----------------

if (-not $Global:SandboxMode) {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
}

Write-Host "`nSecure context environment disposed. Execution terminal disconnected." -ForegroundColor Yellow