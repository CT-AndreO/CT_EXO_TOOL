function Invoke-StorageMonitor {
    $Identity = $Global:TargetUser.UserPrincipalName
    $StartTime = Get-Date
    $RefreshIntervalSeconds = 10
    $MonitoringUser = $true

    Clear-Host
    Write-Host "Connecting to mailbox telemetry..." -ForegroundColor Gray
    try {
        $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
        $mbxCreated = if ($Mbx.WhenCreated) { $Mbx.WhenCreated.ToString("yyyy-MM-dd") } else { "Unknown" }
        $mbxAgeDays = if ($Mbx.WhenCreated) { [math]::Round(((Get-Date) - $Mbx.WhenCreated).TotalDays) } else { 0 }
        $policyName = if ($Mbx.RetentionPolicy) { $Mbx.RetentionPolicy } else { "None Assigned" }
        
        $primaryQuotaRaw = Get-RawBytes $Mbx.ProhibitSendQuota
        $archiveQuotaRaw = Get-RawBytes $Mbx.ArchiveQuota
        $isArchiveEnabled = ($Mbx.ArchiveStatus -match "Active|Enabled")

        $InitialStats = Get-MailboxStatistics -Identity $Identity -ErrorAction Stop
        $startPrimarySizeMB = [math]::Round((Get-RawBytes $InitialStats.TotalItemSize) / 1MB, 2)
        
        $startArchiveSizeMB = 0
        if ($isArchiveEnabled) {
            try {
                $initArchiveStats = Get-MailboxStatistics -Identity $Identity -Archive -ErrorAction Stop
                $startArchiveSizeMB = [math]::Round((Get-RawBytes $initArchiveStats.TotalItemSize) / 1MB, 2)
            } catch { $startArchiveSizeMB = 0 }
        }

        $archiveTags = if ($Mbx.RetentionPolicy) { Get-ArchiveTagsFromPolicy -PolicyName $Mbx.RetentionPolicy } else { @() }
    } catch {
        Write-Host "Error acquiring mailbox data: $($_.Exception.Message)" -ForegroundColor Red
        Wait-Console
        return
    }

    # Live monitoring loop
    while ($MonitoringUser) {
        try {
            $Elapsed = (Get-Date) - $StartTime
            $ElapsedClock = $Elapsed.ToString("hh\:mm\:ss")

            $CurrentStats = Get-MailboxStatistics -Identity $Identity -ErrorAction Stop
            $currentPrimaryBytes = Get-RawBytes $CurrentStats.TotalItemSize
            $currentPrimaryMB = [math]::Round($currentPrimaryBytes / 1MB, 2)
            $primaryItems = $CurrentStats.ItemCount

            $currentArchiveMB = 0
            $archiveItems = 0
            if ($isArchiveEnabled) {
                try {
                    $CurrentArchive = Get-MailboxStatistics -Identity $Identity -Archive -ErrorAction Stop
                    $currentArchiveBytes = Get-RawBytes $CurrentArchive.TotalItemSize
                    $currentArchiveMB = [math]::Round($currentArchiveBytes / 1MB, 2)
                    $archiveItems = $CurrentArchive.ItemCount
                } catch { 
                    $currentArchiveMB = 0 
                }
            }

            # Quota and percentage calculations
            if ([double]::IsPositiveInfinity($primaryQuotaRaw)) {
                $primaryLimitDisplay = "Unlimited"
                $primaryPercentDisplay = "N/A"
            } elseif ($primaryQuotaRaw -gt 0) {
                $primaryLimitMB = [math]::Round($primaryQuotaRaw / 1MB, 2)
                $primaryLimitDisplay = "$primaryLimitMB MB"
                $primaryPercent = [math]::Round(($currentPrimaryMB / $primaryLimitMB) * 100, 1)
                $primaryPercentDisplay = "$primaryPercent%"
            } else {
                $primaryLimitDisplay = "Default / Unset"
                $primaryPercentDisplay = "N/A"
            }

            if ([double]::IsPositiveInfinity($archiveQuotaRaw)) {
                $archiveLimitDisplay = "Unlimited"
                $archivePercentDisplay = "N/A"
            } elseif ($archiveQuotaRaw -gt 0) {
                $archiveLimitMB = [math]::Round($archiveQuotaRaw / 1MB, 2)
                $archiveLimitDisplay = "$archiveLimitMB MB"
                $archivePercent = [math]::Round(($currentArchiveMB / $archiveLimitMB) * 100, 1)
                $archivePercentDisplay = "$archivePercent%"
            } else {
                $archiveLimitDisplay = "100 GB (Default)"
                $archivePercentDisplay = "N/A"
            }

            $primaryDeltaMB = [math]::Round($currentPrimaryMB - $startPrimarySizeMB, 2)
            $archiveDeltaMB = [math]::Round($currentArchiveMB - $startArchiveSizeMB, 2)

            Clear-Host
            Write-Host "=====================================================================" -ForegroundColor Cyan
            Write-Host "                 MAILBOX STORAGE & ANALYTICS MONITOR                 " -ForegroundColor Cyan
            Write-Host "=====================================================================" -ForegroundColor Cyan
            Write-Host " Mailbox:          $Identity" -ForegroundColor White
            Write-Host " Created Date:     $mbxCreated ($mbxAgeDays days ago)" -ForegroundColor Gray
            Write-Host " Active Policy:    $policyName" -ForegroundColor Gray
            Write-Host " Hotkeys:          [R] Refresh Now  |  [B] or [0] Return to Menu" -ForegroundColor Yellow
            Write-Host "---------------------------------------------------------------------"
            
            # Primary Mailbox Card
            Write-Host " PRIMARY MAILBOX STORAGE" -ForegroundColor Cyan
            Write-Host ("  Size Used:       {0} MB ({1} items)" -f $currentPrimaryMB, $primaryItems) -ForegroundColor Yellow
            Write-Host ("  Quota Limit:     {0} (Utilization: {1})" -f $primaryLimitDisplay, $primaryPercentDisplay) -ForegroundColor Gray
            Write-Host ("  Session Delta:   {0:+0.00;-0.00;0.00} MB" -f $primaryDeltaMB) -ForegroundColor DarkGray
            Write-Host "---------------------------------------------------------------------"

            # Archive Mailbox Card
            if ($isArchiveEnabled) {
                Write-Host " ONLINE ARCHIVE STORAGE [ACTIVE]" -ForegroundColor Green
                Write-Host ("  Size Used:       {0} MB ({1} items)" -f $currentArchiveMB, $archiveItems) -ForegroundColor Yellow
                Write-Host ("  Quota Limit:     {0} (Utilization: {1})" -f $archiveLimitDisplay, $archivePercentDisplay) -ForegroundColor Gray
                Write-Host ("  Session Delta:   {0:+0.00;-0.00;0.00} MB" -f $archiveDeltaMB) -ForegroundColor DarkGray
            } else {
                Write-Host " ONLINE ARCHIVE STORAGE: [DISABLED]" -ForegroundColor Red
            }
            Write-Host "---------------------------------------------------------------------"

            # Retention Tags
            if ($archiveTags.Count -gt 0) {
                Write-Host " Move-to-Archive Retention Tags:" -ForegroundColor DarkCyan
                foreach ($Tag in $archiveTags) {
                    $DaysStr = "Unlimited"
                    if ($null -ne $Tag.AgeLimitForRetention) {
                        $rawAge = $Tag.AgeLimitForRetention.ToString()
                        if ($rawAge -match '^(\d+)\.') { $DaysStr = "$($matches[1]) days" }
                        else { $DaysStr = "$rawAge days" }
                    }
                    Write-Host "  * $($Tag.Name) -> Moves items older than $DaysStr" -ForegroundColor DarkGray
                }
                Write-Host "---------------------------------------------------------------------"
            }

            Write-Host (" Session Duration: {0}  |  Last Updated: {1}" -f $ElapsedClock, (Get-Date -Format "HH:mm:ss")) -ForegroundColor DarkGray
            Write-Host "=====================================================================" -ForegroundColor Cyan

            # Non-blocking sleep loop with key listening
            $ForceRefresh = $false
            $Slices = $RefreshIntervalSeconds * 5
            for ($s = 0; $s -lt $Slices; $s++) {
                $RemainingSeconds = [math]::Ceiling(($Slices - $s) / 5)
                Write-Host "`r Next auto-refresh in $RemainingSeconds seconds... (Press R to refresh, B to exit)  " -NoNewline -ForegroundColor DarkGray

                try {
                    if ([Console]::KeyAvailable) {
                        $Key = [Console]::ReadKey($true)
                        switch ($Key.Key) {
                            "R" { $ForceRefresh = $true; break }
                            "B" { $MonitoringUser = $false; break }
                            "D0" { $MonitoringUser = $false; break }
                            "NumPad0" { $MonitoringUser = $false; break }
                            "Q" { $MonitoringUser = $false; break }
                            "Escape" { $MonitoringUser = $false; break }
                        }
                    }
                } catch {
                    # KeyAvailable can throw if input is redirected
                }

                if ($ForceRefresh -or -not $MonitoringUser) { break }
                Start-Sleep -Milliseconds 200
            }

            if (-not $MonitoringUser) { break }
            if ($ForceRefresh) { continue }

        } catch {
            Write-Host "`nError reading storage analytics: $($_.Exception.Message)" -ForegroundColor Red
            Wait-Console
            break
        }
    }
}
