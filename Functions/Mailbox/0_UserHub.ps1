function Invoke-UserMenu {
    if ($null -eq $Global:TargetUser) {
        Write-Host "Error: No target user selected." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }

    # 1. Format creation date
    $CreatedDate = if ($Global:TargetUser.WhenCreated) { 
        $Global:TargetUser.WhenCreated.ToString("yyyy-MM-dd HH:mm:ss") 
    } else { 
        "Unknown" 
    }

    # 2. Format Mailbox Type
    $MailboxType = switch ($Global:TargetUser.RecipientTypeDetails.ToString()) {
        "UserMailbox"      { "Regular User Mailbox" }
        "SharedMailbox"    { "Shared Mailbox" }
        "RoomMailbox"      { "Room Mailbox" }
        "EquipmentMailbox" { "Equipment Mailbox" }
        Default            { $Global:TargetUser.RecipientTypeDetails.ToString() }
    }

    $UserRunning = $true
    while ($UserRunning) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                     MAILBOX MANAGEMENT HUB                          " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " User:             $($Global:TargetUser.DisplayName)" -ForegroundColor White
        Write-Host " UPN / Email:      $($Global:TargetUser.UserPrincipalName)" -ForegroundColor Gray
        Write-Host " Mailbox Type:     $MailboxType" -ForegroundColor Gray
        Write-Host " Created Date:     $CreatedDate" -ForegroundColor Gray
        Write-Host "---------------------------------------------------------------------"
        Write-Host " 1. Archiving & Retention Policies (Archive Status, MRM, MFA)"
        Write-Host " 2. Auto-Expanding Archive Management"
        Write-Host " 3. Mailbox Storage & Analytics (Live Monitor)"
        Write-Host " 4. Calendar Sharing & Permissions Delegation"
        Write-Host " 5. View Folder Statistics & Item Counts"
        Write-Host " 0. Return to User Search"
        Write-Host "---------------------------------------------------------------------"

        $Choice = (Read-Host "Selection").Trim()

        switch ($Choice) {
            "1" { Invoke-ManageArchive }
            "2" { Invoke-ManageExpansion }
            "3" { Invoke-StorageMonitor }
            "4" { Invoke-CalendarSharing }
            "5" { Invoke-FolderStatistics }
            "0" { $UserRunning = $false }
            Default { 
                Write-Host "Invalid selection. Please enter 0 to 5." -ForegroundColor Red
                Start-Sleep -Seconds 1 
            }
        }
    }
}
