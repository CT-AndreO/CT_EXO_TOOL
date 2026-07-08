function Invoke-BulkOperationsMock {
    # --- 1. GENERATE DATA POOL ---
    if ($null -eq $Global:MockMailboxes) {
        $Global:MockMailboxes = @(
            [PSCustomObject]@{ Idx = 1;  DisplayName = "Marthinus Marais";   UserPrincipalName = "mmarais@dkvg.co.za";     PrimarySizeBytes = 42949672960; PrimarySizeGB = 40.0; PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 80.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 0;           ArchiveSizeGB = 0.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 0.0;  AutoExpandingArchiveReady = $false; RetentionPolicy = "Default MRM"; IsSharedMailbox = $false; IsLicensed = $true;  ArchiveEnabled = $false; Selected = $false },
            [PSCustomObject]@{ Idx = 2;  DisplayName = "Sarah Jenkins";      UserPrincipalName = "sjenkins@dkvg.co.za";    PrimarySizeBytes = 41338511360; PrimarySizeGB = 38.5; PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 77.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 0;           ArchiveSizeGB = 0.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 0.0;  AutoExpandingArchiveReady = $false; RetentionPolicy = "Default MRM"; IsSharedMailbox = $false; IsLicensed = $true;  ArchiveEnabled = $false; Selected = $false },
            [PSCustomObject]@{ Idx = 3;  DisplayName = "Info Desk Shared";   UserPrincipalName = "info@dkvg.co.za";        PrimarySizeBytes = 39728447488; PrimarySizeGB = 37.0; PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 74.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 0;           ArchiveSizeGB = 0.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 0.0;  AutoExpandingArchiveReady = $false; RetentionPolicy = "No Policy";   IsSharedMailbox = $true;  IsLicensed = $false; ArchiveEnabled = $false; Selected = $false },
            [PSCustomObject]@{ Idx = 4;  DisplayName = "Finance Archive";    UserPrincipalName = "finance@dkvg.co.za";     PrimarySizeBytes = 48318382080; PrimarySizeGB = 45.0; PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 90.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 88046829568; ArchiveSizeGB = 82.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 82.0; AutoExpandingArchiveReady = $false; RetentionPolicy = "High Volume"; IsSharedMailbox = $true;  IsLicensed = $false; ArchiveEnabled = $true;  Selected = $false },
            [PSCustomObject]@{ Idx = 5;  DisplayName = "David Louw (Stale)"; UserPrincipalName = "dlouw@dkvg.co.za";      PrimarySizeBytes = 41875931136; PrimarySizeGB = 39.0; PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 78.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 0;           ArchiveSizeGB = 0.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 0.0;  AutoExpandingArchiveReady = $false; RetentionPolicy = "Default MRM"; IsSharedMailbox = $false; IsLicensed = $false; ArchiveEnabled = $false; Selected = $false },
            [PSCustomObject]@{ Idx = 6;  DisplayName = "Legal Hold Capture"; UserPrincipalName = "legalhold@dkvg.co.za";   PrimarySizeBytes = 49392123904; PrimarySizeGB = 46.0; PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 92.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 0;           ArchiveSizeGB = 0.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 0.0;  AutoExpandingArchiveReady = $false; RetentionPolicy = "Legal Baseline";IsSharedMailbox = $false; IsLicensed = $true;  ArchiveEnabled = $false; Selected = $false },
            [PSCustomObject]@{ Idx = 7;  DisplayName = "Reception Shared";   UserPrincipalName = "reception@dkvg.co.za";   PrimarySizeBytes = 5368709120;  PrimarySizeGB = 5.0;  PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 10.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 0;           ArchiveSizeGB = 0.0;  ArchiveQuotaGB = 100.0; ArchivePercentUsed = 0.0;  AutoExpandingArchiveReady = $false; RetentionPolicy = "No Policy";   IsSharedMailbox = $true;  IsLicensed = $false; ArchiveEnabled = $false; Selected = $false },
            [PSCustomObject]@{ Idx = 8;  DisplayName = "Ronald Smith";       UserPrincipalName = "Rsmith@dkvg.co.za";      PrimarySizeBytes = 8589934592;  PrimarySizeGB = 8.0;  PrimaryQuotaGB = 50.0; PrimaryPercentUsed = 16.0; PrimaryWarningGB = 45.0; ArchiveSizeBytes = 10737418240; ArchiveSizeGB = 10.0; ArchiveQuotaGB = 100.0; ArchivePercentUsed = 10.0; AutoExpandingArchiveReady = $true;  RetentionPolicy = "Default MRM"; IsSharedMailbox = $false; IsLicensed = $true;  ArchiveEnabled = $true;  Selected = $false }
        )
    }

    # --- 2. MULTI-VARIABLE VARIABLE OVERLAYS ---
    $PrimaryThreshold = 75
    $ArchiveThreshold = 75
    $FilterLicensedOnly = $true

    $BulkMenuRunning = $true
    while ($BulkMenuRunning) {
        Clear-Host
        
        $TotalItems = $Global:MockMailboxes.Count
        $SelectedCount = ($Global:MockMailboxes | Where-Object { $_.Selected }).Count

        # --- GRID HEADER INTERFACE ---
        Write-Host "=========================================================================================================" -ForegroundColor Cyan
        Write-Host "                               BULK MAILBOX AUDIT & CONFIGURATION MATRIX                                 " -ForegroundColor Cyan
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

        # --- UNIFIED DIRECTORY OUTPUT STREAM ---
        foreach ($mbx in $Global:MockMailboxes) {
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

        # --- ADMINISTRATIVE CONTROL PANEL ---
        Write-Host " INTERACTION METADATA COMMANDS:" -ForegroundColor Cyan
        Write-Host "  [#] Toggle index selection state (e.g., enter '1' to select/deselect)" -ForegroundColor Gray
        Write-Host "  [R] Run Auto-Selection Evaluation Pass       | [T] Change Threshold Values (Primary/Archive)" -ForegroundColor Gray
        Write-Host "  [L] Toggle License Guardrail Filter          | [E] Export Current Directory to Excel-Friendly CSV" -ForegroundColor Yellow
        Write-Host "  [A] Select All | [D] Clear All Selection Flags" -ForegroundColor Gray
        Write-Host "---------------------------------------------------------------------------------------------------------"
        Write-Host " EXECUTION PIPELINES:" -ForegroundColor Magenta
        Write-Host "  [EXEC1] Mass Enable Core Online Archiving Structures"
        Write-Host "  [EXEC2] Mass Deploy Auto-Expanding Storage Engine Layers"
        Write-Host "  [EXEC3] Mass Provision BOTH Online Archive & Auto-Expansion Strategies"
        Write-Host "  [0]     Return to Main Shell"
        Write-Host "---------------------------------------------------------------------------------------------------------"

        $Action = Read-Host "`nBulk Command Input Parser"
        $Action = $Action.ToUpper().Trim()

        if ($Action -match '^\d+$' -and $Action -ne "0") {
            $TargetID = [int]$Action
            $MatchedMbx = $Global:MockMailboxes | Where-Object { $_.Idx -eq $TargetID }
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
                foreach ($mbx in $Global:MockMailboxes) {
                    $QualifiesPrimary = (-not $mbx.ArchiveEnabled -and $mbx.PrimaryPercentUsed -ge $PrimaryThreshold)
                    $QualifiesArchive = ($mbx.ArchiveEnabled -and -not $mbx.AutoExpandingArchiveReady -and $mbx.ArchivePercentUsed -ge $ArchiveThreshold)
                    $PassesLicense    = (-not $FilterLicensedOnly -or $mbx.IsLicensed)
                    
                    $mbx.Selected = ($QualifiesPrimary -or $QualifiesArchive) -and $PassesLicense
                }
                Write-Host "`nAutomation loop parsed. Split threshold rule sets applied!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }

            "A" { foreach ($mbx in $Global:MockMailboxes) { $mbx.Selected = $true } }
            "D" { foreach ($mbx in $Global:MockMailboxes) { $mbx.Selected = $false } }

            # --- CSV EXTRACTION ENGINE WITH FULL DATA FIELD MAP SYNCHRONIZATION ---
            "E" {
                Clear-Host
                Write-Host "=== PIPELINE ENGINE: DATA EXTRACTION TO EXCEL-FRIENDLY CSV ===" -ForegroundColor Cyan
                Write-Host "Generating structural directory preview stream below:`n" -ForegroundColor Gray
                
                # Re-map database values into your exact corporate formatting schema rules
                $ExportData = foreach ($m in $Global:MockMailboxes) {
                    [PSCustomObject]@{
                        "name"                    = $m.DisplayName
                        "email"                   = $m.UserPrincipalName
                        "primary size (in MB)"   = [math]::Round($m.PrimarySizeGB * 1024, 2)
                        "primary limit (MB)"      = [math]::Round($m.PrimaryQuotaGB * 1024, 2)
                        "primary percent"         = "$($m.PrimaryPercentUsed)%"
                        "archive (in MB)"         = [math]::Round($m.ArchiveSizeGB * 1024, 2)
                        "archive limit (MB)"      = [math]::Round($m.ArchiveQuotaGB * 1024, 2)
                        "archive percent"         = "$($m.ArchivePercentUsed)%"
                        "shared mailbox"          = if ($m.IsSharedMailbox) { "True" } else { "False" }
                        "current retention policy" = $m.RetentionPolicy
                        "if auto expansion is on"  = if ($m.AutoExpandingArchiveReady) { "True" } else { "False" }
                    }
                }

                # FIXED: Terminal screen display now outputs EVERY single requested column row format seamlessly!
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
                    catch { Write-Host "[WARN] Folder creation faulted. Resetting down to local context base." -ForegroundColor Yellow; $TargetDir = "." }
                }

                $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputFile = Join-Path $TargetDir "TenantMailboxAudit_$Timestamp.csv"

                try {
                    $ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
                    Write-Host "`n[SUCCESS] Document completely structured and outputted:" -ForegroundColor Green
                    Write-Host " -> $OutputFile" -ForegroundColor Cyan
                } catch {
                    Write-Host "`n[ERROR] System writing stream exception: $_" -ForegroundColor Red
                }
                Read-Host "`nPress Enter to return to main tracking matrix board..."
            }

            "EXEC1" {
                $Targets = $Global:MockMailboxes | Where-Object { $_.Selected }
                if ($Targets.Count -eq 0) { Write-Host "`n[FAIL] Selection pipeline completely empty." -ForegroundColor Red; Start-Sleep -Seconds 1; continue }
                Clear-Host
                Write-Host "=== PIPELINE EXEC1: INITIALIZE BULK ONLINE ARCHIVING ===" -ForegroundColor Magenta
                foreach ($t in $Targets) { Write-Host " -> Staging Vector: $($t.DisplayName) ($($t.UserPrincipalName))" -ForegroundColor Cyan }
                
                $Confirm = Read-Host "`nCommit transformations to live tenant? (Y/YES/NO)"
                if ($Confirm.ToUpper().Trim() -match '^(Y|YES)$') {
                    foreach ($t in $Targets) { $t.ArchiveEnabled = $true; $t.Selected = $false }
                    Write-Host "`nOperational batch successfully finalized." -ForegroundColor Green
                } else { Write-Host "`nExecution vector sequence broken off safely." -ForegroundColor Yellow }
                Read-Host "`nPress Enter to return..."
            }

            "EXEC2" {
                $Targets = $Global:MockMailboxes | Where-Object { $_.Selected }
                if ($Targets.Count -eq 0) { Write-Host "`n[FAIL] Selection pipeline completely empty." -ForegroundColor Red; Start-Sleep -Seconds 1; continue }
                Clear-Host
                Write-Host "=== PIPELINE EXEC2: INITIALIZE AUTO-EXPANSION ARCHIVES ===" -ForegroundColor Magenta
                foreach ($t in $Targets) { Write-Host " -> Staging Vector: $($t.DisplayName) ($($t.UserPrincipalName))" -ForegroundColor Cyan }
                
                $Confirm = Read-Host "`nCommit transformations to live tenant? (Y/YES/NO)"
                if ($Confirm.ToUpper().Trim() -match '^(Y|YES)$') {
                    foreach ($t in $Targets) { $t.ArchiveEnabled = $true; $t.AutoExpandingArchiveReady = $true; $t.Selected = $false }
                    Write-Host "`nStorage expansion provisioning complete." -ForegroundColor Green
                } else { Write-Host "`nExecution vector sequence broken off safely." -ForegroundColor Yellow }
                Read-Host "`nPress Enter to return..."
            }

            "EXEC3" {
                $Targets = $Global:MockMailboxes | Where-Object { $_.Selected }
                if ($Targets.Count -eq 0) { Write-Host "`n[FAIL] Selection pipeline completely empty." -ForegroundColor Red; Start-Sleep -Seconds 1; continue }
                Clear-Host
                Write-Host "=== PIPELINE EXEC3: DUAL COMBINED ARCHIVE & AUTO-EXPANSION PROVISIONING ===" -ForegroundColor Yellow
                foreach ($t in $Targets) { Write-Host " -> Staging Vector: $($t.DisplayName) ($($t.UserPrincipalName))" -ForegroundColor Cyan }
                
                $Confirm = Read-Host "`nCommit dual optimization configurations to live tenant? (Y/YES/NO)"
                if ($Confirm.ToUpper().Trim() -match '^(Y|YES)$') {
                    foreach ($t in $Targets) { $t.ArchiveEnabled = $true; $t.AutoExpandingArchiveReady = $true; $t.Selected = $false }
                    Write-Host "`nAll targeted systems have been fully provisioned." -ForegroundColor Green
                } else { Write-Host "`nExecution vector sequence broken off safely." -ForegroundColor Yellow }
                Read-Host "`nPress Enter to return..."
            }

            Default {
                Write-Host "Invalid parameter syntax mapping arguments." -ForegroundColor Red
                Start-Sleep -Milliseconds 600
            }
        }
    }
}