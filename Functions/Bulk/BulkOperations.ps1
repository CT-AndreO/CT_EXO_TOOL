function Invoke-BulkMenu {
    # --- 1. PERSISTENT LIVE SESSION CACHE GENERATOR ---
    if ($null -eq $Global:CentralMailboxCache) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "          INITIALIZING CENTRAL LIVE TENANT SESSION CACHE             " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "Querying Exchange Online directory endpoints..." -ForegroundColor Gray

        # Helper local script block to parse deserialized size objects via string matching
        $ParseBytes = {
            param($Property)
            if ($null -eq $Property) { return 0 }
            $StrValue = $Property.ToString()
            if ($StrValue -eq "Unlimited") { return 100GB } # Baseline cap for unlimited values
            if ($StrValue -match '\((?<bytes>[\d,]+)\s+bytes\)') {
                return [int64]($Matches.bytes -replace ',','')
            }
            return 0
        }

        try {
            $RawMailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop
            $Global:CentralMailboxCache = @()
            $Count = 0
            $Total = $RawMailboxes.Count

            foreach ($mbx in $RawMailboxes) {
                $Count++
                Write-Progress -Activity "Compiling Tenant Mailbox Analytics" -Status "Processing: $($mbx.UserPrincipalName)" -PercentComplete (($Count / $Total) * 100)

                # Fetch Primary Mailbox Statistics
                $stat = Get-MailboxStatistics -Identity $mbx.UserPrincipalName -ErrorAction SilentlyContinue
                $PrimarySizeBytes = & $ParseBytes ($stat.TotalItemSize)
                $PrimarySizeGB = [math]::Round($PrimarySizeBytes / 1GB, 2)

                # Process Storage Quota Limits Safely
                $QuotaBytes = & $ParseBytes ($mbx.ProhibitSendReceiveQuota)
                if ($QuotaBytes -eq 0) { $QuotaBytes = 50GB } # Standard tenant baseline fallback
                $PrimaryQuotaGB = [math]::Round($QuotaBytes / 1GB, 2)
                $PrimaryPercentUsed = if ($PrimaryQuotaGB -gt 0) { [math]::Round(($PrimarySizeGB / $PrimaryQuotaGB) * 100, 1) } else { 0 }

                # Fetch Archive Mailbox Statistics
                $ArchiveSizeGB = 0.0
                $ArchiveQuotaGB = 100.0
                $ArchivePercentUsed = 0.0
                $ArchiveActive = ($mbx.ArchiveStatus -eq "Active" -or $mbx.ArchiveStatus -eq "Local")

                if ($ArchiveActive) {
                    $archiveStat = Get-MailboxStatistics -Identity $mbx.UserPrincipalName -Archive -ErrorAction SilentlyContinue
                    $ArchiveSizeBytes = & $ParseBytes ($archiveStat.TotalItemSize)
                    $ArchiveSizeGB = [math]::Round($ArchiveSizeBytes / 1GB, 2)

                    $ArchiveQuotaBytes = & $ParseBytes ($mbx.ArchiveQuota)
                    if ($ArchiveQuotaBytes -gt 0) {
                        $ArchiveQuotaGB = [math]::Round($ArchiveQuotaBytes / 1GB, 2)
                    }
                    $ArchivePercentUsed = if ($ArchiveQuotaGB -gt 0) { [math]::Round(($ArchiveSizeGB / $ArchiveQuotaGB) * 100, 1) } else { 0 }
                }

                $IsShared = ($mbx.RecipientTypeDetails -eq 'SharedMailbox')
                $IsLicensed = if ($IsShared) { $false } else { $true }

                # Hydrate cache map
                $Global:CentralMailboxCache += [PSCustomObject]@{
                    Idx                        = $Count
                    DisplayName                = $mbx.DisplayName
                    UserPrincipalName          = $mbx.UserPrincipalName
                    PrimarySizeGB              = $PrimarySizeGB
                    PrimaryQuotaGB             = $PrimaryQuotaGB
                    PrimaryPercentUsed         = $PrimaryPercentUsed
                    ArchiveEnabled             = $ArchiveActive
                    ArchiveSizeGB              = $ArchiveSizeGB
                    ArchiveQuotaGB             = $ArchiveQuotaGB
                    ArchivePercentUsed         = $ArchivePercentUsed
                    AutoExpandingArchiveReady  = $mbx.AutoExpandingArchiveEnabled
                    RetentionPolicy            = if ($null -eq $mbx.RetentionPolicy) { "No Policy Assigned" } else { $mbx.RetentionPolicy }
                    IsSharedMailbox            = $IsShared
                    IsLicensed                 = $IsLicensed
                    Selected                   = $false
                }
            }
        }
        catch {
            Write-Host "[CRITICAL ERROR] Failed to capture tenant data stream pipeline: $_" -ForegroundColor Red
            $Global:CentralMailboxCache = $null
            Read-Host "`nPress Enter to return..."
            return
        }
    }

    # --- 2. MAIN HUB INTERACTION LOOP ---
    $TotalUsers = ($Global:CentralMailboxCache | Where-Object { -not $_.IsSharedMailbox }).Count
    $TotalShared = ($Global:CentralMailboxCache | Where-Object { $_.IsSharedMailbox }).Count

    $BulkRunning = $true
    while ($BulkRunning) {
        Clear-Host
        Write-Host "=== BULK OPERATIONS & REPORTING ===" -ForegroundColor Cyan
        Write-Host "Directory Assets: $TotalUsers User Mailboxes | $TotalShared Shared Mailboxes (Cached Mode)" -ForegroundColor Gray
        Write-Host "--------------------------------------------------------"
        Write-Host "1. Run Bulk MRM Operations (via CSV Ingestion)"
        Write-Host "2. Generate Mailbox Export Report"
        Write-Host "3. Launch Live Matrix Dashboard & Automation Auditor" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------"
        Write-Host "R. Flush Session Cache & Re-scan Live Infrastructure" -ForegroundColor DarkGray
        Write-Host "0. Back to Main Menu"

        $Choice = Read-Host "`nSelection"
        $Choice = $Choice.ToUpper().Trim()

        switch ($Choice) {
            "1" { Invoke-BulkMRM }
            "2" { Invoke-ExportReport }
            "3" { Invoke-InteractiveMatrixAuditor }
            "R" {
                $Global:CentralMailboxCache = $null
                Write-Host "`nCache completely wiped. Re-triggering sequence lookup..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                return Invoke-BulkMenu
            }
            "0" { $BulkRunning = $false }
            Default {
                Write-Host "Invalid Selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Invoke-InteractiveMatrixAuditor {
    $PrimaryThreshold = 75
    $ArchiveThreshold = 75
    $FilterLicensedOnly = $false

    $BulkMenuRunning = $true
    while ($BulkMenuRunning) {
        Clear-Host
        
        $TotalItems = $Global:CentralMailboxCache.Count
        $SelectedCount = ($Global:CentralMailboxCache | Where-Object { $_.Selected }).Count

        # --- GRID HEADER INTERFACE ---
        Write-Host "=========================================================================================================" -ForegroundColor Cyan
        Write-Host "                            LIVE EXCHANGE ONLINE AUDIT & CONFIGURATION MATRIX                            " -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Cyan
        Write-Host " RULES REGISTERS: Primary Limit >= " -NoNewline; Write-Host "$PrimaryThreshold%" -ForegroundColor Yellow -NoNewline
        Write-Host " | Archive Limit >= " -NoNewline; Write-Host "$ArchiveThreshold%" -ForegroundColor Yellow -NoNewline
        Write-Host " | License Guardrail: " -NoNewline
        if ($FilterLicensedOnly) { Write-Host "ACTIVE (Skip Unlicensed)" -ForegroundColor Green } else { Write-Host "INACTIVE" -ForegroundColor Yellow }
        Write-Host " DIRECTORY STATUS: Total Objects Loaded: $TotalItems | Currently Armed Selections: $SelectedCount" -ForegroundColor Gray
        Write-Host "---------------------------------------------------------------------------------------------------------"
        
        $FormatStr = "{0,-4} {1,-6} {2,-22} {3,-8} {4,-5} {5,-22} {6,-24}"
        Write-Host ($FormatStr -f "ID", "STATE", "DISPLAY NAME", "TYPE", "LIC", "PRIMARY UTILIZATION", "ONLINE ARCHIVE UTIL") -ForegroundColor White
        Write-Host "---------------------------------------------------------------------------------------------------------"

        # --- CACHED INTERACTIVE DATA DISPLAY LAYER ---
        foreach ($mbx in $Global:CentralMailboxCache) {
            $TypeStr = if ($mbx.IsSharedMailbox) { "Shared" } else { "User" }
            $LicStr  = if ($mbx.IsLicensed) { "Yes" } else { "No" }
            $StateCheckbox = if ($mbx.Selected) { "[X]" } else { "[ ]" }
            
            $PrimaryUtilStr = "{0}/{1} GB ({2}%)" -f $mbx.PrimarySizeGB, $mbx.PrimaryQuotaGB, $mbx.PrimaryPercentUsed
            
            if ($mbx.ArchiveEnabled) {
                $ArchiveUtilStr = "{0}/{1} GB ({2}%)" -f $mbx.ArchiveSizeGB, $mbx.ArchiveQuotaGB, $mbx.ArchivePercentUsed
                if ($mbx.AutoExpandingArchiveReady) { $ArchiveUtilStr += " [Exp]" }
            } else {
                $ArchiveUtilStr = "Disabled"
            }

            $RowString = $FormatStr -f $mbx.Idx, $StateCheckbox, $mbx.DisplayName, $TypeStr, $LicStr, $PrimaryUtilStr, $ArchiveUtilStr

            # Evaluator Conditions Layer
            $QualifiesPrimary = (-not $mbx.ArchiveEnabled -and $mbx.PrimaryPercentUsed -ge $PrimaryThreshold)
            $QualifiesArchive = ($mbx.ArchiveEnabled -and -not $mbx.AutoExpandingArchiveReady -and $mbx.ArchivePercentUsed -ge $ArchiveThreshold)
            $PassesLicense    = (-not $FilterLicensedOnly -or $mbx.IsLicensed)

            # Color Priority Logic Layer
            if ($mbx.Selected) {
                Write-Host $RowString -ForegroundColor Green
            } elseif (($QualifiesPrimary -or $QualifiesArchive) -and $PassesLicense) {
                Write-Host $RowString -ForegroundColor Cyan
            } else {
                Write-Host $RowString -ForegroundColor Gray
            }
        }

        Write-Host "---------------------------------------------------------------------------------------------------------"
        Write-Host " INTERACTION METADATA COMMANDS:" -ForegroundColor Cyan
        Write-Host "  [#] Toggle selection index state             | [T] Change Threshold Values (Primary/Archive)" -ForegroundColor Gray
        Write-Host "  [R] Run Auto-Selection Evaluation Pass       | [E] Export Current Directory to Excel-Friendly CSV" -ForegroundColor Yellow
        Write-Host "  [A] Select All | [D] Clear All Selections     | [L] Toggle License Guardrail Filter" -ForegroundColor Gray
        Write-Host "---------------------------------------------------------------------------------------------------------"
        Write-Host " CLOUD PRODUCTION EXECUTION PIPELINES (TARGETS ARMED OBJECTS):" -ForegroundColor Magenta
        Write-Host "  [EXEC1] Mass Enable Core Online Archiving Structures"
        Write-Host "  [EXEC2] Mass Deploy Auto-Expanding Storage Engine Layers"
        Write-Host "  [EXEC3] Mass Provision BOTH Online Archive & Auto-Expansion Strategies"
        Write-Host "  [0]     Return to Bulk Operations Hub"
        Write-Host "---------------------------------------------------------------------------------------------------------"

        $Action = Read-Host "`nBulk Command Input Parser"
        $Action = $Action.ToUpper().Trim()

        if ($Action -match '^\d+$' -and $Action -ne "0") {
            $TargetID = [int]$Action
            $MatchedMbx = $Global:CentralMailboxCache | Where-Object { $_.Idx -eq $TargetID }
            if ($null -ne $MatchedMbx) { $MatchedMbx.Selected = -not $MatchedMbx.Selected }
            continue
        }

        switch ($Action) {
            "0" { $BulkMenuRunning = $false }
            
            "T" {
                Clear-Host
                Write-Host "=== THRESHOLD MANAGEMENT SUB-CONSTRAINTS ===" -ForegroundColor Cyan
                Write-Host "[1] Modify Primary Mailbox Threshold (Current: $PrimaryThreshold%)" -ForegroundColor Gray
                Write-Host "[2] Modify Online Archive Threshold (Current: $ArchiveThreshold%)" -ForegroundColor Gray
                Write-Host "[0] Back to Main Workspace Matrix" -ForegroundColor Yellow
                
                $TChoice = Read-Host "`nSelect parameter adjustment lane"
                $TChoice = $TChoice.Trim()
                
                if ($TChoice -eq "1") {
                    $NewT = Read-Host "Enter new Primary usage percentage threshold (1-99)"
                    if ($NewT -match '^\d+$' -and [int]$NewT -gt 0 -and [int]$NewT -lt 100) { $PrimaryThreshold = [int]$NewT }
                } elseif ($TChoice -eq "2") {
                    $NewT = Read-Host "Enter new Archive usage percentage threshold (1-99)"
                    if ($NewT -match '^\d+$' -and [int]$NewT -gt 0 -and [int]$NewT -lt 100) { $ArchiveThreshold = [int]$NewT }
                }
            }

            "L" { $FilterLicensedOnly = -not $FilterLicensedOnly }

            "R" {
                foreach ($mbx in $Global:CentralMailboxCache) {
                    $QualifiesPrimary = (-not $mbx.ArchiveEnabled -and $mbx.PrimaryPercentUsed -ge $PrimaryThreshold)
                    $QualifiesArchive = ($mbx.ArchiveEnabled -and -not $mbx.AutoExpandingArchiveReady -and $mbx.ArchivePercentUsed -ge $ArchiveThreshold)
                    $PassesLicense    = (-not $FilterLicensedOnly -or $mbx.IsLicensed)
                    
                    $mbx.Selected = ($QualifiesPrimary -or $QualifiesArchive) -and $PassesLicense
                }
                Write-Host "`nAutomation rules processed across session data maps!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }

            "A" { foreach ($mbx in $Global:CentralMailboxCache) { $mbx.Selected = $true } }
            "D" { foreach ($mbx in $Global:CentralMailboxCache) { $mbx.Selected = $false } }

            "E" {
                Clear-Host
                Write-Host "=== PIPELINE ENGINE: DATA EXTRACTION TO EXCEL-FRIENDLY CSV ===" -ForegroundColor Cyan
                Write-Host "Generating structural directory preview stream below:`n" -ForegroundColor Gray
                
                $ExportData = foreach ($m in $Global:CentralMailboxCache) {
                    [PSCustomObject]@{
                        "name"                     = $m.DisplayName
                        "email"                    = $m.UserPrincipalName
                        "primary size (in MB)"     = [math]::Round($m.PrimarySizeGB * 1024, 2)
                        "primary limit (MB)"       = [math]::Round($m.PrimaryQuotaGB * 1024, 2)
                        "primary percent"          = "$($m.PrimaryPercentUsed)%"
                        "archive (in MB)"          = [math]::Round($m.ArchiveSizeGB * 1024, 2)
                        "archive limit (MB)"       = [math]::Round($m.ArchiveQuotaGB * 1024, 2)
                        "archive percent"          = "$($m.ArchivePercentUsed)%"
                        "shared mailbox"           = if ($m.IsSharedMailbox) { "True" } else { "False" }
                        "current retention policy" = $m.RetentionPolicy
                        "if auto expansion is on"   = if ($m.AutoExpandingArchiveReady) { "True" } else { "False" }
                    }
                }

                $ExportData | Format-Table | Out-String | Write-Host -ForegroundColor Gray
                Write-Host "---------------------------------------------------------------------------------------------------------"
                
                Write-Host "Enter path selection options (or press [0] to abort and go back):" -ForegroundColor Yellow
                $TargetDir = Read-Host "Output Directory Path (e.g., C:\Temp or leave empty for local folder)"
                $TargetDir = $TargetDir.Trim()
                
                if ($TargetDir -eq "0") {
                    Write-Host "`nExport process discarded safely." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                    continue
                }
                
                if ([string]::IsNullOrWhiteSpace($TargetDir)) { $TargetDir = "." }
                if (-not (Test-Path -Path $TargetDir)) {
                    try { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
                    catch { Write-Host "[WARN] Folder creation faulted. Using root base execution scope." -ForegroundColor Yellow; $TargetDir = "." }
                }

                $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputFile = Join-Path $TargetDir "LiveMailboxAudit_$Timestamp.csv"

                try {
                    $ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
                    Write-Host "`n[SUCCESS] Document completely structured and outputted:" -ForegroundColor Green
                    Write-Host " -> $OutputFile" -ForegroundColor Cyan
                } catch {
                    Write-Host "`n[ERROR] System writing stream exception: $_" -ForegroundColor Red
                }
                Read-Host "`nPress Enter to return to tracking board..."
            }

            "EXEC1" {
                $Targets = $Global:CentralMailboxCache | Where-Object { $_.Selected }
                if ($Targets.Count -eq 0) { Write-Host "`n[FAIL] Selection pipeline completely empty." -ForegroundColor Red; Start-Sleep -Seconds 1; continue }
                Clear-Host
                Write-Host "=== PIPELINE EXEC1: MASS LIVE PROVISION ONLINE ARCHIVING ===" -ForegroundColor Magenta
                foreach ($t in $Targets) { Write-Host " -> Target Vector: $($t.DisplayName) ($($t.UserPrincipalName))" -ForegroundColor Cyan }
                
                $Confirm = Read-Host "`nCommit live infrastructure updates to Microsoft 365? (Y/YES/NO)"
                if ($Confirm.ToUpper().Trim() -match '^(Y|YES)$') {
                    foreach ($t in $Targets) {
                        try {
                            Write-Host "Executing cloud provisioning payload on: $($t.UserPrincipalName)..." -ForegroundColor Gray
                            Enable-Mailbox -Identity $t.UserPrincipalName -Archive -ErrorAction Stop
                            
                            $t.ArchiveEnabled = $true
                            $t.Selected = $false
                            Write-Host "[OK] Provisioned." -ForegroundColor Green
                        } catch {
                            Write-Host "[ERROR] Cloud execution failed for $($t.UserPrincipalName): $_" -ForegroundColor Red
                        }
                    }
                    Write-Host "`nOperational workflow complete." -ForegroundColor Green
                } else { Write-Host "`nExecution batch terminated safely." -ForegroundColor Yellow }
                Read-Host "`nPress Enter to return..."
            }

            "EXEC2" {
                $Targets = $Global:CentralMailboxCache | Where-Object { $_.Selected }
                if ($Targets.Count -eq 0) { Write-Host "`n[FAIL] Selection pipeline completely empty." -ForegroundColor Red; Start-Sleep -Seconds 1; continue }
                Clear-Host
                Write-Host "=== PIPELINE EXEC2: MASS LIVE PROVISION AUTO-EXPANSION HOOKS ===" -ForegroundColor Magenta
                foreach ($t in $Targets) { Write-Host " -> Target Vector: $($t.DisplayName) ($($t.UserPrincipalName))" -ForegroundColor Cyan }
                
                $Confirm = Read-Host "`nCommit live infrastructure updates to Microsoft 365? (Y/YES/NO)"
                if ($Confirm.ToUpper().Trim() -match '^(Y|YES)$') {
                    foreach ($t in $Targets) {
                        try {
                            Write-Host "Executing cloud provisioning payload on: $($t.UserPrincipalName)..." -ForegroundColor Gray
                            Set-Mailbox -Identity $t.UserPrincipalName -AutoExpandingArchive $true -ErrorAction Stop
                            
                            $t.AutoExpandingArchiveReady = $true
                            $t.Selected = $false
                            Write-Host "[OK] Provisioned." -ForegroundColor Green
                        } catch {
                            Write-Host "[ERROR] Cloud execution failed for $($t.UserPrincipalName): $_" -ForegroundColor Red
                        }
                    }
                    Write-Host "`nOperational workflow complete." -ForegroundColor Green
                } else { Write-Host "`nExecution batch terminated safely." -ForegroundColor Yellow }
                Read-Host "`nPress Enter to return..."
            }

            "EXEC3" {
                $Targets = $Global:CentralMailboxCache | Where-Object { $_.Selected }
                if ($Targets.Count -eq 0) { Write-Host "`n[FAIL] Selection pipeline completely empty." -ForegroundColor Red; Start-Sleep -Seconds 1; continue }
                Clear-Host
                Write-Host "=== PIPELINE EXEC3: MASS LIVE DUAL ARCHIVE & EXPANSION OPTIMIZATION ===" -ForegroundColor Yellow
                foreach ($t in $Targets) { Write-Host " -> Target Vector: $($t.DisplayName) ($($t.UserPrincipalName))" -ForegroundColor Cyan }
                
                $Confirm = Read-Host "`nCommit live infrastructure updates to Microsoft 365? (Y/YES/NO)"
                if ($Confirm.ToUpper().Trim() -match '^(Y|YES)$') {
                    foreach ($t in $Targets) {
                        try {
                            Write-Host "Executing dual cloud payload on: $($t.UserPrincipalName)..." -ForegroundColor Gray
                            if (-not $t.ArchiveEnabled) {
                                Enable-Mailbox -Identity $t.UserPrincipalName -Archive -ErrorAction Stop
                                $t.ArchiveEnabled = $true
                            }
                            Set-Mailbox -Identity $t.UserPrincipalName -AutoExpandingArchive $true -ErrorAction Stop
                            
                            $t.AutoExpandingArchiveReady = $true
                            $t.Selected = $false
                            Write-Host "[OK] Complete Optimization Applied." -ForegroundColor Green
                        } catch {
                            Write-Host "[ERROR] Cloud execution failed for $($t.UserPrincipalName): $_" -ForegroundColor Red
                        }
                    }
                    Write-Host "`nOperational workflow complete." -ForegroundColor Green
                } else { Write-Host "`nExecution batch terminated safely." -ForegroundColor Yellow }
                Read-Host "`nPress Enter to return..."
            }

            Default {
                Write-Host "Invalid menu command parameters." -ForegroundColor Red
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

function Invoke-BulkMRM {
    Clear-Host
    Write-Host "=== BULK MRM OPERATIONS ===" -ForegroundColor Cyan
    Write-Host "Feature placeholder. CSV ingestion logic goes here." -ForegroundColor Yellow
    Read-Host "`nPress Enter to return to Bulk Menu..." 
}