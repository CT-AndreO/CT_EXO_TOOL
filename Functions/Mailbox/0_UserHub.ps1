function Invoke-UserMenu {
    # Guard clause: Ensure we actually have a user before rendering the menu
    if ($null -eq $Global:TargetUser) {
        Write-Host "Error: No target user selected." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }

    $UserRunning = $true
    while ($UserRunning) {
        Clear-Host
        # Displaying the specific context of who we are editing right in the header
        Write-Host "=== MANAGING USER: $($Global:TargetUser.DisplayName) ===" -ForegroundColor Cyan
        Write-Host "UPN: $($Global:TargetUser.UserPrincipalName)" -ForegroundColor Gray
        Write-Host "--------------------------------------------------"
        Write-Host "1. Manage Archival Rules"
        Write-Host "2. Manage Auto Expansion"
        Write-Host "3. Monitor Mailbox Storage (Live Analytics)"
        Write-Host "0. Back to User Search"

        $Choice = Read-Host "`nSelection"

        switch ($Choice) {
            "1" { Invoke-ManageArchive }
            "2" { Invoke-ManageExpansion }
            "3" { Invoke-StorageMonitor }
            "0" { $UserRunning = $false }
            Default { 
                Write-Host "Invalid Selection." -ForegroundColor Red
                Start-Sleep -Seconds 1 
            }
        }
    }
}