function Invoke-StorageMonitor {
    $Identity = $Global:TargetUser.UserPrincipalName
    $StartTime = Get-Date
    $RefreshIntervalSeconds = 5
    $MonitoringUser = $true

    # --- INITIAL ARCHITECTURE METADATA ACQUISITION ---
    Write-Host "Fetching historical directory provisioning metrics..." -ForegroundColor Gray
    try {
        $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
        $mbxCreated = if ($Mbx.WhenCreated) { $Mbx.WhenCreated.ToString("yyyy/MM/dd") } else { "Unknown" }
        $mbxAgeDays = if ($Mbx.WhenCreated) { [math]::Round(((Get-Date) - $Mbx.WhenCreated).TotalDays) } else { 0 }
        $policyName = if ($Mbx.RetentionPolicy) { $Mbx.RetentionPolicy } else { "No Policy Assigned" }
        
        $primaryQuota = Get-RawBytes $Mbx.ProhibitSendQuota
        $archiveQuota = Get-RawBytes $Mbx.ArchiveQuota
        $isArchiveEnabled = ($Mbx.ArchiveStatus -match "Active|Enabled")

        $CurrentStats = Get-MailboxStatistics -Identity $Identity -ErrorAction Stop
        $startSizeMB = [math]::Round((Get-RawBytes $CurrentStats.TotalItemSize) / 1MB, 2)
        
        # Fetch tags dynamically from assigned Exchange policy container
        $archiveTags = if ($Mbx.RetentionPolicy) { Get-ArchiveTagsFromPolicy -PolicyName $Mbx.RetentionPolicy } else { @() }
    } catch {
        Write-Host "Error acquiring pipeline instrumentation: $_" -ForegroundColor Red
        Wait-Console
        return
    }

    # --- RUNTIME LIVE STREAM LOOP ---
    while ($MonitoringUser) {
        try {
            $Elapsed = (Get-Date) - $StartTime
            $ElapsedClock = $Elapsed.ToString("hh\:mm\:ss")

            $CurrentStats = Get-MailboxStatistics -Identity $Identity -ErrorAction Stop
            $currentSizeMB = [math]::Round((Get-RawBytes $CurrentStats.TotalItemSize) / 1MB, 2)
            $archSizeMB = 0
            if ($isArchiveEnabled) {
                try {
                    $CurrentArchive = Get-MailboxStatistics -Identity $Identity -Archive -ErrorAction Stop
                    $archSizeMB = [math]::Round((Get-RawBytes $CurrentArchive.TotalItemSize) / 1MB, 2)
                } catch { $archSizeMB = 0 }
            }

            $primaryLimitMB = [math]::Round($primaryQuota / 1MB, 2)
            $archiveLimitMB = [math]::Round($archiveQuota / 1MB, 2)
            $primaryPercent = if ($primaryLimitMB -gt 0) { [math]::Round(($currentSizeMB / $primaryLimitMB) * 100, 1) } else { 0 }
            $archivePercent = if ($archiveLimitMB -gt 0) { [math]::Round(($archSizeMB / $archiveLimitMB) * 100, 1) } else { 0 }
            $totalMovedMB = [math]::Max(0, ($startSizeMB - $currentSizeMB))

            Clear-Host
            Write-Host " Monitoring Account Mailbox Storage: $Identity " -BackgroundColor Blue -ForegroundColor White
            Write-Host " Latest Update: $(Get-Date -Format T)" -ForegroundColor Gray
            Write-Host " Hotkeys: [R] Immediate Refresh | [B] Exit Mail Analytics" -ForegroundColor Gray
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
}