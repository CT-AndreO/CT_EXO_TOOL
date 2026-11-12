function Invoke-ManageExpansion {
    $Identity = $Global:TargetUser.UserPrincipalName
    $AutoExpandMenuRunning = $true
    
    while ($AutoExpandMenuRunning) {
        Clear-Host

        try {
            $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
            $AutoExpandEnabled = [bool]$Mbx.AutoExpandingArchiveEnabled
            $ArchiveEnabled = ($Mbx.ArchiveStatus -match "Active|Enabled")
        }
        catch {
            Write-Host "Failed to retrieve mailbox properties: $($_.Exception.Message)" -ForegroundColor Red
            Wait-Console
            return
        }

        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "               AUTO-EXPANDING ARCHIVE MANAGEMENT                     " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Mailbox: $Identity" -ForegroundColor White
        Write-Host "---------------------------------------------------------------------"
        Write-Host " Online Archive Status:        " -NoNewline
        Write-ToggleStatus -State $ArchiveEnabled
        Write-Host " Auto-Expanding Archive Status:" -NoNewline
        Write-ToggleStatus -State $AutoExpandEnabled
        Write-Host "---------------------------------------------------------------------"

        if (-not $ArchiveEnabled) {
            Write-Host "[NOTICE] The online archive must be enabled before auto-expansion can be used." -ForegroundColor Yellow
            Write-Host "Please enable Online Archiving first in the 'Archiving & Retention' menu.`n" -ForegroundColor Gray
        }

        if ($AutoExpandEnabled) {
            Write-Host "[INFO] Auto-Expanding Archive is ACTIVE for this mailbox." -ForegroundColor Green
            Write-Host "Microsoft 365 will automatically provision auxiliary archive storage" -ForegroundColor Gray
            Write-Host "as usage approaches capacity limits (up to 1.5 TB total)." -ForegroundColor Gray
            Write-Host "`nNote: Microsoft Exchange Online architecture does not support disabling" -ForegroundColor DarkGray
            Write-Host "auto-expanding archives once provisioned." -ForegroundColor DarkGray
            Write-Host "---------------------------------------------------------------------"
            Write-Host " 0. Back to User Hub"
        }
        else {
            Write-Host " 1. Enable Auto-Expanding Archive"
            Write-Host " 0. Back to User Hub"
        }
        Write-Host "---------------------------------------------------------------------"

        $Choice = (Read-Host "Selection").Trim()

        switch ($Choice) {
            "1" {
                if ($AutoExpandEnabled) {
                    Write-Host "`nAuto-expanding archive is already enabled for this mailbox." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                    continue
                }

                if (-not $ArchiveEnabled) {
                    Write-Host "`nCannot enable auto-expansion: Online Archive is not active." -ForegroundColor Red
                    Wait-Console
                    continue
                }

                Write-Host "`nIMPORTANT: Once enabled, Microsoft 365 does NOT permit disabling" -ForegroundColor Yellow
                Write-Host "auto-expanding archives on a mailbox." -ForegroundColor Yellow
                $Confirm = Read-Host "Are you sure you want to enable Auto-Expanding Archive for $Identity? (Y/N)"
                
                if ($Confirm.Trim() -imatch '^Y') {
                    Write-Host "Enabling Auto-Expanding Archive on Exchange Online..." -ForegroundColor Gray
                    try {
                        Enable-Mailbox -Identity $Identity -AutoExpandingArchive -ErrorAction Stop
                        Write-Host "Auto-Expanding Archive enabled successfully!" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Failed to enable auto-expansion: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    Wait-Console
                }
            }
            "0" { 
                $AutoExpandMenuRunning = $false 
            }
            Default {
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
