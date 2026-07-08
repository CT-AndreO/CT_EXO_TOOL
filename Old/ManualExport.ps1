# --- CONFIGURATION ---
$Global:SandboxMode = $false  # Set to $false for real MSP client work
$ScriptRunning      = $true

# --- HELPER FUNCTIONS ---
function Get-RawBytes ($stat) {
    if ($null -eq $stat) { return 0 }
    $StringStat = $stat.ToString()
    if ($StringStat -match '\((?<bytes>[\d,]+) bytes\)') {
        return [int64]($matches['bytes'] -replace ',', '')
    }
    $numericOnly = $StringStat -replace '[^\d]', ''
    if ($numericOnly -match '^\d+$') { return [int64]$numericOnly }
    return 0
}

# --- INITIAL CONNECTION / SIGN IN ---
Clear-Host
if (-not $Global:SandboxMode) {
    Write-Host "Verifying Exchange Online Session..." -ForegroundColor Gray
    try {
        $OrgInfo = Get-OrganizationConfig -ErrorAction Stop
        $Global:CurrentOrg = if ($OrgInfo.DisplayName) { $OrgInfo.DisplayName } else { $OrgInfo.Identity }
    } catch {
        Write-Host "Connecting..." -ForegroundColor Cyan
        Connect-ExchangeOnline
        $OrgInfo = Get-OrganizationConfig
        $Global:CurrentOrg = if ($OrgInfo.DisplayName) { $OrgInfo.DisplayName } else { $OrgInfo.Identity }
    }
} else {
    $Global:CurrentOrg = "SANDBOX-ENVIRONMENT"
}

# --- MAIN APP LOOP ---
while ($ScriptRunning) {
    Clear-Host
    $ModeColor = if ($Global:SandboxMode) { "Yellow" } else { "Cyan" }
    Write-Host "=== EXO MAILBOX [$Global:CurrentOrg] ===" -ForegroundColor $ModeColor
    Write-Host "1. Select User to Manage"
    Write-Host "2. Switch Tenant / Sign Out"
    Write-Host "4. Export Mailboxes"
    Write-Host "0. Exit Script"

    $Choice = Read-Host "`nSelection"

    switch ($Choice) {
        "0" { $ScriptRunning = $false }
        
        "2" {
            if (-not $Global:SandboxMode) { Disconnect-ExchangeOnline -Confirm:$false }
            $Global:CurrentOrg = "Disconnected"
            Write-Host "Disconnected. Restart to login again." -ForegroundColor Yellow
            pause
        }

        "4" {
            $InExportMenu = $true
            $ExportLength = 0
            $ExportPath   = "$env:USERPROFILE\Desktop\MailboxReport.csv"

            while ($InExportMenu) {
                Clear-Host
                Write-Host "--- EXPORT MAILBOXES ---" -ForegroundColor Cyan
                Write-Host "1. Export"
                Write-Host "2. Choose Length (Current: $(if($ExportLength -eq 0){"All"}else{$ExportLength}))"
                Write-Host "3. File Path (Current: $ExportPath)"
                Write-Host "0. Back"

                $ExpChoice = Read-Host "`nSelection"

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
                        Write-Host "Starting Mailbox Export..." -ForegroundColor Cyan
                        $ReportData = @()

                        if ($Global:SandboxMode) {
                            Write-Host "Sandbox Mode: Generating dummy data..." -ForegroundColor Yellow
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
                            }
                            Start-Sleep -Seconds 2
                        } else {
                            $ResultSize = if ($ExportLength -eq 0) { "Unlimited" } else { $ExportLength }
                            Write-Host "Fetching user list..." -ForegroundColor Gray
                            
                            # Only target UserMailboxes to avoid pulling discovery/shared unless intended
                            $Mailboxes = Get-Mailbox -ResultSize $ResultSize -RecipientTypeDetails UserMailbox
                            
                            $Total = $Mailboxes.Count
                            $Counter = 0

                            foreach ($mbx in $Mailboxes) {
                                $Counter++
                                Write-Progress -Activity "Gathering Mailbox Statistics" -Status "Processing $($mbx.DisplayName) ($Counter of $Total)" -PercentComplete (($Counter / $Total) * 100)

                                $Stats = Get-MailboxStatistics -Identity $mbx.UserPrincipalName -ErrorAction SilentlyContinue
                                $Arch  = Get-MailboxStatistics -Identity $mbx.UserPrincipalName -Archive -ErrorAction SilentlyContinue

                                # Primary Data
                                $pSize   = Get-RawBytes $Stats.TotalItemSize
                                $pLimit  = Get-RawBytes $mbx.ProhibitSendQuota
                                $pWarn   = Get-RawBytes $mbx.IssueWarningQuota
                                
                                $pSizeGB = if ($pSize -gt 0) { [math]::Round($pSize / 1GB, 2) } else { 0 }
                                $pLimGB  = if ($pLimit -gt 0) { [math]::Round($pLimit / 1GB, 2) } else { 0 }
                                $pWarnGB = if ($pWarn -gt 0) { [math]::Round($pWarn / 1GB, 2) } else { 0 }
                                $pPerc   = if ($pLimit -gt 0) { [math]::Round(($pSize / $pLimit) * 100, 2) } else { 0 }

                                # Archive Data
                                $aSize   = if ($Arch) { Get-RawBytes $Arch.TotalItemSize } else { 0 }
                                $aLimit  = Get-RawBytes $mbx.ArchiveQuota
                                
                                $aSizeGB = if ($aSize -gt 0) { [math]::Round($aSize / 1GB, 2) } else { 0 }
                                $aLimGB  = if ($aLimit -gt 0) { [math]::Round($aLimit / 1GB, 2) } else { 0 }
                                $aPerc   = if ($aLimit -gt 0) { [math]::Round(($aSize / $aLimit) * 100, 2) } else { 0 }

                                $ReportData += [PSCustomObject]@{
                                    DisplayName               = $mbx.DisplayName
                                    UserPrincipalName         = $mbx.UserPrincipalName
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

                        # Export the compiled array to CSV
                        try {
                            $ReportData | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                            Write-Host "`nExport completed successfully!" -ForegroundColor Green
                            Write-Host "Saved to: $ExportPath" -ForegroundColor Gray
                        } catch {
                            Write-Host "`nFailed to write CSV: $($_.Exception.Message)" -ForegroundColor Red
                        }
                        
                        Write-Host "`nPress Enter to return to export menu..." -ForegroundColor Cyan
                        pause
                    }
                }
            }
        }

        "1" {
            $InSearchSession = $true
            while ($InSearchSession) {
                Clear-Host
                Write-Host "--- USER SEARCH ---" -ForegroundColor Cyan
                $SearchTerm = Read-Host "Enter Name or Email (or 'B' for Back)"
                
                if ($SearchTerm -eq 'b' -or [string]::IsNullOrWhiteSpace($SearchTerm)) {
                    $InSearchSession = $false
                    break
                }

                # --- SEARCH LOGIC ---
                if ($Global:SandboxMode) {
                    $Results = @([PSCustomObject]@{DisplayName="Tanith Sandbox"; UserPrincipalName="tanith@pfsa.org.za"})
                } else {
                    Write-Host "Searching Exchange..." -ForegroundColor Gray
                    $Results = @(Get-User -Filter "DisplayName -like '*$SearchTerm*' -or UserPrincipalName -like '*$SearchTerm*'" -ResultSize 15)
                }

                if ($Results.Count -eq 0) {
                    Write-Host "No users found." -ForegroundColor Red; Start-Sleep -Seconds 1
                    continue
                }

                # --- SELECTION ---
                for ($i=0; $i -lt $Results.Count; $i++) { Write-Host "$($i + 1). $($Results[$i].DisplayName) ($($Results[$i].UserPrincipalName))" }
                $Selection = Read-Host "`nSelect Number (or 'C' to Cancel)"
                
                if ($Selection -match '^\d+$' -and [int]$Selection -le $Results.Count) {
                    $TargetUser = $Results[[int]$Selection - 1]
                    $Monitoring = $true
                    
                    # --- MONITORING LOOP ---
                    while ($Monitoring) {
                        # Fetch Data
                        if ($Global:SandboxMode) {
                            $pSize = 45000 * 1MB; $aSize = 12000 * 1MB
                            $pLimit = 50000 * 1MB; $aLimit = 100000 * 1MB
                            $policy = "Sandbox Default"
                        } else {
                            $mbx = Get-Mailbox -Identity $TargetUser.UserPrincipalName
                            $stats = Get-MailboxStatistics -Identity $TargetUser.UserPrincipalName
                            $arch = Get-MailboxStatistics -Identity $TargetUser.UserPrincipalName -Archive -ErrorAction SilentlyContinue
                            $pSize = Get-RawBytes $stats.TotalItemSize
                            $pLimit = Get-RawBytes $mbx.ProhibitSendQuota
                            $aSize = if ($arch) { Get-RawBytes $arch.TotalItemSize } else { 0 }
                            $aLimit = Get-RawBytes $mbx.ArchiveQuota
                            $policy = $mbx.RetentionPolicy
                        }

                        # Display UI
                        Clear-Host
                        Write-Host " [ MONITORING: $($TargetUser.DisplayName) ] " -BackgroundColor Blue
                        Write-Host " Last Update: $(Get-Date -Format T)" -ForegroundColor Green
                        Write-Host " Policy: $policy" -ForegroundColor Magenta
                        Write-Host "------------------------------------------------------------"
                        
                        $pPerc = if ($pLimit -gt 0) { [math]::Round(($pSize / $pLimit) * 100, 1) } else { 0 }
                        Write-Host " PRIMARY: $([math]::Round($pSize/1MB, 2)) MB / $([math]::Round($pLimit/1MB, 2)) MB ($pPerc%)" -ForegroundColor Yellow
                        
                        $aPerc = if ($aLimit -gt 0) { [math]::Round(($aSize / $aLimit) * 100, 1) } else { 0 }
                        Write-Host " ARCHIVE: $([math]::Round($aSize/1MB, 2)) MB / $([math]::Round($aLimit/1MB, 2)) MB ($aPerc%)" -ForegroundColor Green
                        Write-Host "------------------------------------------------------------"

                        # Countdown / Refresh Loop
                        for ($sec = 30; $sec -gt 0; $sec--) {
                            Write-Host "`r Refreshing in $sec seconds... (Press 'B' for Menu)   " -NoNewline -ForegroundColor Gray
                            if ($Host.UI.RawUI.KeyAvailable) {
                                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                                if ($key.Character -eq 'b' -or $key.Character -eq 'B') { $Monitoring = $false; break }
                            }
                            Start-Sleep -Seconds 1
                        }
                    }
                }
            }
        }
        Default { Write-Host "Invalid Choice."; Start-Sleep -Seconds 1 }
    }
}