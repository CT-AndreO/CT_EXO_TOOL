function Invoke-FolderStatistics {
    $Identity = $Global:TargetUser.UserPrincipalName
    $FolderStatsMenuRunning = $true
    
    while ($FolderStatsMenuRunning) {
        Clear-Host

        try {
            $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
            $ArchiveEnabled = ($Mbx.ArchiveStatus -match "Active|Enabled")
            $RawFolderStats = @(Get-MailboxFolderStatistics -Identity $Identity -ErrorAction Stop)
            $TotalItems = ($RawFolderStats | Measure-Object -Property ItemsInFolder -Sum).Sum
            $TotalFolders = $RawFolderStats.Count
        }
        catch {
            Write-Host "Failed to retrieve mailbox folder properties: $($_.Exception.Message)" -ForegroundColor Red
            Wait-Console
            return
        }

        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                  MAILBOX FOLDER ITEM STATISTICS                     " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Mailbox: $Identity" -ForegroundColor White
        Write-Host "---------------------------------------------------------------------"
        Write-Host " Total Mailbox Folders:        $TotalFolders" -ForegroundColor Gray
        Write-Host " Total Items in All Folders:   $TotalItems" -ForegroundColor Yellow
        Write-Host " Online Archive Status:        " -NoNewline
        Write-ToggleStatus -State $ArchiveEnabled
        Write-Host "---------------------------------------------------------------------"
        Write-Host " 1. View Top Folders with Items (Non-Empty Folders)"
        Write-Host " 2. View All Mailbox Folders (Complete Directory Hierarchy)"
        if ($ArchiveEnabled) {
            Write-Host " 3. View Online Archive Folder Statistics"
        }
        Write-Host " 4. Export Folder Statistics to CSV"
        Write-Host " 0. Back to User Hub"
        Write-Host "---------------------------------------------------------------------"

        $Choice = (Read-Host "Selection").Trim()

        switch ($Choice) {
            "1" {
                $NonEmpty = @($RawFolderStats | Where-Object { $_.ItemsInFolder -gt 0 } | Sort-Object ItemsInFolder -Descending)
                Show-FolderStatsTable -FolderList $NonEmpty -Title "NON-EMPTY FOLDERS ($($NonEmpty.Count) folders)"
            }
            "2" {
                $AllSorted = @($RawFolderStats | Sort-Object FolderPath)
                Show-FolderStatsTable -FolderList $AllSorted -Title "ALL FOLDERS ($($AllSorted.Count) folders)"
            }
            "3" {
                if (-not $ArchiveEnabled) {
                    Write-Host "`nOnline Archive is not active for this mailbox." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                    continue
                }

                Write-Host "`nRetrieving online archive folder statistics..." -ForegroundColor Gray
                try {
                    $ArchiveFolderStats = @(Get-MailboxFolderStatistics -Identity $Identity -Archive -ErrorAction Stop | Sort-Object ItemsInFolder -Descending)
                    Show-FolderStatsTable -FolderList $ArchiveFolderStats -Title "ONLINE ARCHIVE FOLDERS ($($ArchiveFolderStats.Count) folders)"
                }
                catch {
                    Write-Host "Failed to retrieve archive folder statistics: $($_.Exception.Message)" -ForegroundColor Red
                    Wait-Console
                }
            }
            "4" {
                Export-FolderStatsToCsv -FolderStats $RawFolderStats -Identity $Identity
            }
            "0" { 
                $FolderStatsMenuRunning = $false 
            }
            Default {
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-FolderStatsTable {
    param(
        [array]$FolderList,
        [string]$Title
    )

    Clear-Host
    Write-Host "=========================================================================================================" -ForegroundColor Cyan
    Write-Host " FOLDER BREAKDOWN: $Title" -ForegroundColor Cyan
    Write-Host "=========================================================================================================" -ForegroundColor Cyan

    if ($null -eq $FolderList -or $FolderList.Count -eq 0) {
        Write-Host "No folders matching criteria." -ForegroundColor Yellow
        Wait-Console
        return
    }

    $FormatStr = "{0,-50} {1,14} {2,18}"
    Write-Host ($FormatStr -f "FOLDER PATH", "ITEM COUNT", "FOLDER SIZE") -ForegroundColor White
    Write-Host "---------------------------------------------------------------------------------------------------------" -ForegroundColor Gray

    foreach ($f in $FolderList) {
        $Path = $f.FolderPath
        if ($Path.Length -gt 48) { $Path = "..." + $Path.Substring($Path.Length - 45) }
        $Items = $f.ItemsInFolder
        $Size = if ($f.FolderSize) { $f.FolderSize.ToString() } else { "0 B" }
        $Color = if ($Items -gt 0) { "Green" } else { "DarkGray" }
        Write-Host ($FormatStr -f $Path, $Items, $Size) -ForegroundColor $Color
    }

    Write-Host "=========================================================================================================" -ForegroundColor Cyan
    Wait-Console
}

function Export-FolderStatsToCsv {
    param(
        [array]$FolderStats,
        [string]$Identity
    )

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "               EXPORT FOLDER STATISTICS TO CSV                       " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Mailbox: $Identity" -ForegroundColor White
    Write-Host " Total Folders to export: $($FolderStats.Count)" -ForegroundColor Gray
    
    $TargetDir = (Read-Host "`nEnter export directory (leave empty for current directory, or '0' to cancel)").Trim()
    if ($TargetDir -eq "0") { return }
    if ([string]::IsNullOrWhiteSpace($TargetDir)) { $TargetDir = "." }

    if (-not (Test-Path -Path $TargetDir)) {
        try { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
        catch { $TargetDir = "." }
    }

    $CleanIdentity = ($Identity -replace '[@.:\\]', '_')
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $FilePath = Join-Path $TargetDir "EXO_FolderStats_${CleanIdentity}_$Timestamp.csv"

    Write-Host "Writing folder statistics to CSV..." -ForegroundColor Gray
    try {
        $ExportRows = foreach ($f in $FolderStats) {
            [PSCustomObject]@{
                "Mailbox"                    = $Identity
                "FolderPath"                 = $f.FolderPath
                "ItemsInFolder"              = $f.ItemsInFolder
                "DeletedItemsInFolder"       = $f.DeletedItemsInFolder
                "FolderSize"                 = if ($f.FolderSize) { $f.FolderSize.ToString() } else { "0 B" }
                "FolderAndSubfolderSize"     = if ($f.FolderAndSubfolderSize) { $f.FolderAndSubfolderSize.ToString() } else { "0 B" }
                "ItemsInFolderAndSubfolders" = $f.ItemsInFolderAndSubfolders
            }
        }

        $ExportRows | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        Write-Host "`n[SUCCESS] Folder statistics exported successfully:" -ForegroundColor Green
        Write-Host " -> $FilePath" -ForegroundColor Cyan
    }
    catch {
        Write-Host "`n[ERROR] Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-Console
}
