function Invoke-UserMenu {
    # Guard clause: Ensure we actually have a user before rendering the menu
    if ($null -eq $Global:TargetUser) {
        Write-Host "Error: No target user selected." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }

    # 1. Parse and format the creation timestamp
    if ($null -ne $Global:TargetUser.WhenCreated) {
        $CreatedDate = $Global:TargetUser.WhenCreated.ToString("yyyy/MM/dd HH:mm:ss")
    }
    else {
        $CreatedDate = "Unknown"
    }

    # 2. Parse and format the Mailbox Type (RecipientTypeDetails)
    if ($null -ne $Global:TargetUser.RecipientTypeDetails) {
        # Translate raw Exchange values into clean human-readable text
        switch ($Global:TargetUser.RecipientTypeDetails.ToString()) {
            "UserMailbox" { $MailboxType = "Regular User" }
            "SharedMailbox" { $MailboxType = "Shared Mailbox" }
            "RoomMailbox" { $MailboxType = "Room / Resource" }
            "EquipmentMailbox" { $MailboxType = "Equipment / Resource" }
            Default { $MailboxType = $Global:TargetUser.RecipientTypeDetails.ToString() }
        }
    }
    else {
        $MailboxType = "Unknown"
    }

    $UserRunning = $true
    while ($UserRunning) {
        Clear-Host
        Write-Host "=== MANAGING USER: $($Global:TargetUser.DisplayName) ===" -ForegroundColor Cyan
        Write-Host "User Principal Name:   $($Global:TargetUser.UserPrincipalName)" -ForegroundColor Gray
        Write-Host "Mailbox Creation Date: $CreatedDate (GMT+2)" -ForegroundColor Gray
        Write-Host "Mailbox Type:          $MailboxType" -ForegroundColor Gray
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