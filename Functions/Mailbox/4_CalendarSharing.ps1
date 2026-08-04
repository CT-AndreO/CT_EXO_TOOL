function Invoke-CalendarSharing {
    if ($null -eq $Global:TargetUser) {
        Write-Host "Error: No target user selected." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }

    $TargetUPN = $Global:TargetUser.UserPrincipalName
    $CalendarIdentity = "$($TargetUPN):\Calendar"
    
    $SharingRunning = $true
    while ($SharingRunning) {
        Clear-Host
        Write-Host "=== CALENDAR SHARING MANAGEMENT: $($Global:TargetUser.DisplayName) ===" -ForegroundColor Cyan
        Write-Host "Target User: $TargetUPN" -ForegroundColor Gray
        Write-Host "=================================================="
        Write-Host "1. View Outbound Permissions (Who can access this calendar)"
        Write-Host "2. View Inbound Permissions (Calendars shared with this user)"
        Write-Host "3. Grant Access to Other Users (Add / Update Permissions)"
        Write-Host "4. Revoke Access from Users (Remove Permissions)"
        Write-Host "0. Back to User Menu"

        $Choice = Read-Host "`nSelection"

        switch ($Choice) {
            "1" { Show-OutboundPermissions -CalendarIdentity $CalendarIdentity }
            "2" { Show-InboundPermissions -TargetUPN $TargetUPN }
            "3" { Add-BulkCalendarPermissions -CalendarIdentity $CalendarIdentity }
            "4" { Remove-CalendarPermissions -CalendarIdentity $CalendarIdentity }
            "0" { $SharingRunning = $false }
            Default {
                Write-Host "Invalid Selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-OutboundPermissions {
    param([string]$CalendarIdentity)
    
    Clear-Host
    Write-Host "=== OUTBOUND CALENDAR PERMISSIONS ===" -ForegroundColor Cyan
    Write-Host "Calendar: $CalendarIdentity" -ForegroundColor Gray
    Write-Host "Querying Exchange Online..." -ForegroundColor Gray

    try {
        $Permissions = Get-MailboxFolderPermission -Identity $CalendarIdentity -ErrorAction Stop
        Write-Host "`nCurrent Delegated Access Entries:" -ForegroundColor Green
        
        $FormatStr = "{0,-35} {1,-20} {2,-15}"
        Write-Host ($FormatStr -f "USER / IDENTITY", "ACCESS RIGHTS", "SHARING PERMISSION FLAGS") -ForegroundColor White
        Write-Host "-----------------------------------------------------------------------"
        
        foreach ($perm in $Permissions) {
            $Rights = $perm.AccessRights -join ", "
            Write-Host ($FormatStr -f $perm.User, $Rights, $perm.SharingPermissionFlags) -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[ERROR] Failed to fetch folder permissions: $_" -ForegroundColor Red
    }

    Wait-Console
}

function Show-InboundPermissions {
    param([string]$TargetUPN)
    
    Clear-Host
    Write-Host "=== INBOUND CALENDAR PERMISSIONS ===" -ForegroundColor Cyan
    Write-Host "Scanning tenant mailboxes where $TargetUPN has access..." -ForegroundColor Gray

    try {
        $Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop
        $FoundCount = 0
        $Count = 0
        $Total = $Mailboxes.Count

        Write-Host "`nSearching across $Total mailboxes in tenant...`n" -ForegroundColor Gray

        foreach ($mbx in $Mailboxes) {
            $Count++
            Write-Progress -Activity "Scanning Tenant Calendars" -Status "Checking ($Count/$Total): $($mbx.UserPrincipalName)" -PercentComplete (($Count / $Total) * 100)

            if ($mbx.UserPrincipalName -eq $TargetUPN) { continue }

            try {
                $Path = "$($mbx.UserPrincipalName):\Calendar"
                $Perms = Get-MailboxFolderPermission -Identity $Path -User $TargetUPN -ErrorAction SilentlyContinue
                
                if ($null -ne $Perms) {
                    $FoundCount++
                    Write-Host "[FOUND] Mailbox: $($mbx.DisplayName) ($($mbx.UserPrincipalName))" -ForegroundColor Green
                    Write-Host "        Rights:  $($Perms.AccessRights -join ', ')" -ForegroundColor Yellow
                }
            }
            catch { }
        }
        
        Write-Progress -Activity "Scanning Tenant Calendars" -Completed

        if ($FoundCount -eq 0) {
            Write-Host "No inbound calendar permissions discovered for $TargetUPN." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "[ERROR] Directory query failed: $_" -ForegroundColor Red
    }

    Wait-Console
}

function Add-BulkCalendarPermissions {
    param([string]$CalendarIdentity)

    Clear-Host
    Write-Host "=== GRANT CALENDAR ACCESS (BULK SELECTION) ===" -ForegroundColor Cyan
    Write-Host "Loading directory objects..." -ForegroundColor Gray

    try {
        $AllMailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop | 
            Where-Object { $_.UserPrincipalName -ne $Global:TargetUser.UserPrincipalName }

        if ($AllMailboxes.Count -eq 0) {
            Write-Host "No eligible recipient mailboxes found." -ForegroundColor Red
            Wait-Console
            return
        }

        # Render searchable list
        $FormatStr = "{0,-5} {1,-30} {2,-40}"
        Write-Host ($FormatStr -f "ID", "DISPLAY NAME", "USER PRINCIPAL NAME") -ForegroundColor White
        Write-Host "----------------------------------------------------------------------------------"

        $Index = 1
        $MailboxMap = @{}
        foreach ($mbx in $AllMailboxes) {
            Write-Host ($FormatStr -f "[$Index]", $mbx.DisplayName, $mbx.UserPrincipalName) -ForegroundColor Gray
            $MailboxMap[$Index] = $mbx
            $Index++
        }

        Write-Host "`nInstructions: Enter numbers separated by commas (e.g. 1,3,5) or type 'ALL'." -ForegroundColor Cyan
        $InputSelection = Read-Host "Select Target Mailboxes"
        
        $SelectedMailboxes = @()
        if ($InputSelection.ToUpper().Trim() -eq "ALL") {
            $SelectedMailboxes = $AllMailboxes
        }
        else {
            $Indices = $InputSelection -split ',' | ForEach-Object { $_.Trim() }
            foreach ($idx in $Indices) {
                if ($idx -match '^\d+$' -and $MailboxMap.ContainsKey([int]$idx)) {
                    $SelectedMailboxes += $MailboxMap[[int]$idx]
                }
            }
        }

        if ($SelectedMailboxes.Count -eq 0) {
            Write-Host "No valid mailboxes selected." -ForegroundColor Red
            Start-Sleep -Seconds 1
            return
        }

        # Select Permission Role
        Write-Host "`nSelect Permission Level to Grant:" -ForegroundColor Cyan
        Write-Host "1. AvailabilityOnly  (Free/Busy time only)"
        Write-Host "2. LimitedDetails    (Free/Busy time, subject, and location)"
        Write-Host "3. Reviewer          (Read-only full details)"
        Write-Host "4. Author            (Read/Create items)"
        Write-Host "5. Editor            (Read/Create/Edit/Delete all items)"
        Write-Host "6. Owner             (Full rights including permission management)"
        
        $RoleChoice = Read-Host "`nRole Selection [1-6]"
        $Role = switch ($RoleChoice) {
            "1" { "AvailabilityOnly" }
            "2" { "LimitedDetails" }
            "3" { "Reviewer" }
            "4" { "Author" }
            "5" { "Editor" }
            "6" { "Owner" }
            Default { $null }
        }

        if ($null -eq $Role) {
            Write-Host "Invalid role selection." -ForegroundColor Red
            Start-Sleep -Seconds 1
            return
        }

        Write-Host "`nApplying $Role access to $($SelectedMailboxes.Count) mailboxes..." -ForegroundColor Yellow

        foreach ($recipient in $SelectedMailboxes) {
            try {
                Write-Host "Processing $($recipient.UserPrincipalName)..." -NoNewline
                Add-MailboxFolderPermission -Identity $CalendarIdentity -User $recipient.UserPrincipalName -AccessRights $Role -ErrorAction Stop
                Write-Host " [GRANTED]" -ForegroundColor Green
            }
            catch {
                # Fallback to Set if permission entry already exists
                try {
                    Set-MailboxFolderPermission -Identity $CalendarIdentity -User $recipient.UserPrincipalName -AccessRights $Role -ErrorAction Stop
                    Write-Host " [UPDATED]" -ForegroundColor Yellow
                }
                catch {
                    Write-Host " [FAILED: $_]" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "[ERROR] Failed directory query: $_" -ForegroundColor Red
    }

    Wait-Console
}

function Remove-CalendarPermissions {
    param([string]$CalendarIdentity)

    Clear-Host
    Write-Host "=== REVOKE CALENDAR ACCESS ===" -ForegroundColor Cyan
    Write-Host "Querying existing access entries..." -ForegroundColor Gray

    try {
        $Permissions = Get-MailboxFolderPermission -Identity $CalendarIdentity -ErrorAction Stop |
            Where-Object { $_.User.UserType.ToString() -ne "Default" -and $_.User.UserType.ToString() -ne "Anonymous" }

        if ($Permissions.Count -eq 0) {
            Write-Host "No delegated explicit user permissions found on this calendar." -ForegroundColor Yellow
            Wait-Console
            return
        }

        $FormatStr = "{0,-5} {1,-35} {2,-20}"
        Write-Host ($FormatStr -f "ID", "USER / IDENTITY", "CURRENT RIGHTS") -ForegroundColor White
        Write-Host "------------------------------------------------------------------"

        $Index = 1
        $PermMap = @{}
        foreach ($perm in $Permissions) {
            $Rights = $perm.AccessRights -join ", "
            Write-Host ($FormatStr -f "[$Index]", $perm.User, $Rights) -ForegroundColor Gray
            $PermMap[$Index] = $perm
            $Index++
        }

        $InputSelection = Read-Host "`nEnter selection index to revoke (e.g. 1,2)"
        $Indices = $InputSelection -split ',' | ForEach-Object { $_.Trim() }

        foreach ($idx in $Indices) {
            if ($idx -match '^\d+$' -and $PermMap.ContainsKey([int]$idx)) {
                $TargetPerm = $PermMap[[int]$idx]
                try {
                    Write-Host "Removing access for $($TargetPerm.User)..." -NoNewline
                    Remove-MailboxFolderPermission -Identity $CalendarIdentity -User $TargetPerm.User.ToString() -Confirm:$false -ErrorAction Stop
                    Write-Host " [REMOVED]" -ForegroundColor Green
                }
                catch {
                    Write-Host " [FAILED: $_]" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "[ERROR] Failed to fetch folder permissions: $_" -ForegroundColor Red
    }

    Wait-Console
}