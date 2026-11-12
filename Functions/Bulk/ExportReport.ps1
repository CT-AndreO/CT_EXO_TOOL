function Export-MailboxAuditReport {
    param(
        [array]$MailboxData = $Global:CentralMailboxCache
    )

    if ($null -eq $MailboxData -or $MailboxData.Count -eq 0) {
        Write-Host "`n[ERROR] No mailbox data loaded to export." -ForegroundColor Red
        Wait-Console
        return
    }

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                  EXPORT MAILBOX AUDIT REPORT TO CSV                 " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Preparing export for $($MailboxData.Count) loaded mailboxes...`n" -ForegroundColor Gray

    $ExportData = foreach ($m in $MailboxData) {
        [PSCustomObject]@{
            "DisplayName"             = $m.DisplayName
            "UserPrincipalName"       = $m.UserPrincipalName
            "PrimarySizeMB"           = [math]::Round($m.PrimarySizeGB * 1024, 2)
            "PrimaryQuotaMB"          = if ($m.PrimaryQuotaGB -eq "Unlimited") { "Unlimited" } else { [math]::Round($m.PrimaryQuotaGB * 1024, 2) }
            "PrimaryPercentUsed"      = "$($m.PrimaryPercentUsed)%"
            "ArchiveEnabled"          = if ($m.ArchiveEnabled) { "True" } else { "False" }
            "ArchiveSizeMB"           = [math]::Round($m.ArchiveSizeGB * 1024, 2)
            "ArchiveQuotaMB"          = if ($m.ArchiveQuotaGB -eq "Unlimited") { "Unlimited" } else { [math]::Round($m.ArchiveQuotaGB * 1024, 2) }
            "ArchivePercentUsed"      = "$($m.ArchivePercentUsed)%"
            "AutoExpandingArchive"    = if ($m.AutoExpandingArchiveReady) { "True" } else { "False" }
            "RetentionPolicy"         = $m.RetentionPolicy
            "IsSharedMailbox"         = if ($m.IsSharedMailbox) { "True" } else { "False" }
            "IsLicensed"              = if ($m.IsLicensed) { "True" } else { "False" }
        }
    }

    Write-Host "Enter target output directory path (leave blank for current folder, or '0' to cancel):" -ForegroundColor Yellow
    $TargetDir = (Read-Host "Export Directory").Trim()
    
    if ($TargetDir -eq "0") {
        Write-Host "`nExport cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($TargetDir)) { 
        $TargetDir = "." 
    }
    
    if (-not (Test-Path -Path $TargetDir)) {
        try { 
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null 
        }
        catch { 
            Write-Host "[WARN] Could not create folder. Defaulting to current folder." -ForegroundColor Yellow
            $TargetDir = "." 
        }
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputFile = Join-Path $TargetDir "EXO_MailboxAudit_$Timestamp.csv"

    try {
        $ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Host "`n[SUCCESS] Mailbox audit report saved successfully:" -ForegroundColor Green
        Write-Host " -> $OutputFile" -ForegroundColor Cyan
    }
    catch {
        Write-Host "`n[ERROR] Failed to write CSV file: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-Console
}
