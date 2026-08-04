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
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host " CALENDAR DELEGATION MANAGEMENT | ACTIVE USER: $($Global:TargetUser.DisplayName) ($TargetUPN)" -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host "  [1] View Outbound Permissions (Who can access this user's calendar)"
        Write-Host "  [2] View Inbound Permissions (Calendars shared with this user)"
        Write-Host "  [3] Delegate External Calendars TO This User (Grant Access)"
        Write-Host "  [4] Revoke Shared Calendar Access FROM This User (Remove Access)"
        Write-Host "  [0] Back to Main Menu"
        Write-Host "=========================================================================================================" -ForegroundColor Gray

        $Choice = Read-Host "`nSelection Command"

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
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host " OUTBOUND PERMISSIONS | CALENDAR: $CalendarIdentity" -ForegroundColor Cyan
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host "Querying Exchange Online..." -ForegroundColor Gray

    try {
        $Permissions = Get-MailboxFolderPermission -Identity $CalendarIdentity -ErrorAction Stop
        
        Clear-Host
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host " OUTBOUND PERMISSIONS | CALENDAR: $CalendarIdentity" -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        
        $FormatStr = "{0,-40} {1,-25} {2,-20}"
        Write-Host ($FormatStr -f "USER / IDENTITY", "ACCESS RIGHTS", "SHARING FLAGS") -ForegroundColor White
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        
        foreach ($perm in $Permissions) {
            $Rights = $perm.AccessRights -join ", "
            Write-Host ($FormatStr -f $perm.User, $Rights, $perm.SharingPermissionFlags) -ForegroundColor Yellow
        }
        Write-Host "=========================================================================================================" -ForegroundColor Gray
    }
    catch {
        Write-Host "[ERROR] Failed to fetch folder permissions: $_" -ForegroundColor Red
    }

    Wait-Console
}

function Show-InboundPermissions {
    param([string]$TargetUPN)
    
    Clear-Host
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host " INBOUND PERMISSIONS DISCOVERY | TARGET: $TargetUPN" -ForegroundColor Cyan
    Write-Host "=========================================================================================================" -ForegroundColor Gray

    try {
        $Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop
        $FoundCount = 0
        $Count = 0
        $Total = $Mailboxes.Count

        Write-Host "Scanning $Total tenant mailboxes for delegated access..." -ForegroundColor Gray

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
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host " DELEGATE CALENDARS TO USER | BULK SELECTION" -ForegroundColor Cyan
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host "Loading directory objects..." -ForegroundColor Gray

    try {
        $TargetUPN = $Global:TargetUser.UserPrincipalName
        $AllMailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop | 
            Where-Object { $_.UserPrincipalName -ne $TargetUPN }

        if ($AllMailboxes.Count -eq 0) {
            Write-Host "No eligible target mailboxes found." -ForegroundColor Red
            Wait-Console
            return
        }

        $SelectionList = [System.Collections.Generic.List[PSCustomObject]]::new()
        $Index = 1
        foreach ($mbx in $AllMailboxes) {
            $SelectionList.Add([PSCustomObject]@{
                Index       = $Index
                Selected    = $false
                DisplayName = $mbx.DisplayName
                UPN         = $mbx.UserPrincipalName
                Type        = $mbx.RecipientTypeDetails
                Object      = $mbx
            })
            $Index++
        }

        $Selecting = $true
        while ($Selecting) {
            Clear-Host
            $ArmedCount = ($SelectionList | Where-Object { $_.Selected }).Count
            $TotalCount = $SelectionList.Count

            Write-Host " DIRECTORY STATUS: Total Objects: $TotalCount | Calendars Selected For Access: $ArmedCount" -ForegroundColor Cyan
            Write-Host "=========================================================================================================" -ForegroundColor Gray
            
            $FormatStr = "{0,-4} {1,-7} {2,-30} {3,-40} {4,-15}"
            Write-Host ($FormatStr -f "ID", "STATE", "DISPLAY NAME", "USER PRINCIPAL NAME", "TYPE") -ForegroundColor White
            Write-Host "=========================================================================================================" -ForegroundColor Gray

            foreach ($item in $SelectionList) {
                $StateStr = if ($item.Selected) { "[X]" } else { "[ ]" }
                $Color = if ($item.Selected) { "Green" } else { "Gray" }
                Write-Host ($FormatStr -f $item.Index, $StateStr, $item.DisplayName, $item.UPN, $item.Type) -ForegroundColor $Color
            }

            Write-Host "=========================================================================================================" -ForegroundColor Gray
            Write-Host " INTERACTION COMMANDS:" -ForegroundColor Yellow
            Write-Host "  [#] Toggle index state (e.g. 1 or 1,3,5) | [A] Select All | [D] Clear All Choices"
            Write-Host "  [C] Confirm Selection & Proceed           | [0] Return to Menu"
            Write-Host "=========================================================================================================" -ForegroundColor Gray

            $InputChoice = (Read-Host "`nSelection Command").Trim()

            switch -Regex ($InputChoice) {
                "^0$" { return }
                "(?i)^A$" {
                    $SelectionList | ForEach-Object { $_.Selected = $true }
                }
                "(?i)^D$" {
                    $SelectionList | ForEach-Object { $_.Selected = $false }
                }
                "(?i)^C$" {
                    $SelectedTargets = $SelectionList | Where-Object { $_.Selected }
                    if ($SelectedTargets.Count -eq 0) {
                        Write-Host "No mailboxes selected. Choose items before confirming." -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    } else {
                        $Selecting = $false
                    }
                }
                "^[0-9, ]+$" {
                    $Indices = $InputChoice -split ',' | ForEach-Object { $_.Trim() }
                    foreach ($idx in $Indices) {
                        $matched = $SelectionList | Where-Object { $_.Index -eq [int]$idx }
                        if ($matched) {
                            $matched.Selected = -not $matched.Selected
                        }
                    }
                }
                Default {
                    Write-Host "Invalid Command." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }

        # Role Selection Prompt
        Clear-Host
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host " PERMISSION ROLE ASSIGNMENT FOR $TargetUPN" -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host "  [1] AvailabilityOnly  (Free/Busy time only)"
        Write-Host "  [2] LimitedDetails    (Free/Busy time, subject, and location)"
        Write-Host "  [3] Reviewer          (Read only full details)"
        Write-Host "  [4] Author            (Read/Create items)"
        Write-Host "  [5] Editor            (Read/Create/Edit/Delete all items)"
        Write-Host "  [6] Owner             (Full rights including permission management)"
        Write-Host "  [0] Return to Menu"
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        
        $RoleChoice = Read-Host "`nSelect Role [0-6]"
        $Role = switch ($RoleChoice) {
            "1" { "AvailabilityOnly" }
            "2" { "LimitedDetails" }
            "3" { "Reviewer" }
            "4" { "Author" }
            "5" { "Editor" }
            "6" { "Owner" }
            "0" { return }
            Default { $null }
        }

        if ($null -eq $Role) {
            Write-Host "Invalid selection. Action cancelled." -ForegroundColor Red
            Start-Sleep -Seconds 1
            return
        }

        $SelectedMailboxes = $SelectionList | Where-Object { $_.Selected } | Select-Object -ExpandProperty Object
        Clear-Host
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host " EXECUTING PERMISSION DELEGATION" -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host "Assigning $Role access on $($SelectedMailboxes.Count) calendars to $TargetUPN...`n" -ForegroundColor Yellow

        foreach ($recipient in $SelectedMailboxes) {
            $TargetCalendarPath = "$($recipient.UserPrincipalName):\Calendar"
            Write-Host "Processing access for $($recipient.UserPrincipalName)..." -NoNewline
            
            try {
                $null = Add-MailboxFolderPermission -Identity $TargetCalendarPath -User $TargetUPN -AccessRights $Role -ErrorAction Stop
                Write-Host " [GRANTED]" -ForegroundColor Green
            }
            catch {
                try {
                    $null = Set-MailboxFolderPermission -Identity $TargetCalendarPath -User $TargetUPN -AccessRights $Role -ErrorAction Stop
                    Write-Host " [UPDATED]" -ForegroundColor Yellow
                }
                catch {
                    Write-Host " [FAILED: $_]" -ForegroundColor Red
                }
            }
        }
        Write-Host "`n=========================================================================================================" -ForegroundColor Gray
    }
    catch {
        Write-Host "[ERROR] Directory query failed: $_" -ForegroundColor Red
    }

    Wait-Console
}

function Remove-CalendarPermissions {
    param([string]$CalendarIdentity)

    Clear-Host
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host " REVOKE CALENDAR ACCESS FROM USER" -ForegroundColor Cyan
    Write-Host "=========================================================================================================" -ForegroundColor Gray
    Write-Host "Scanning tenant mailboxes for permissions assigned to $($Global:TargetUser.UserPrincipalName)..." -ForegroundColor Gray

    try {
        $TargetUPN = $Global:TargetUser.UserPrincipalName
        $Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop
        $DelegatedList = [System.Collections.Generic.List[PSCustomObject]]::new()
        $Index = 1

        foreach ($mbx in $Mailboxes) {
            if ($mbx.UserPrincipalName -eq $TargetUPN) { continue }
            try {
                $Path = "$($mbx.UserPrincipalName):\Calendar"
                $Perms = Get-MailboxFolderPermission -Identity $Path -User $TargetUPN -ErrorAction SilentlyContinue
                if ($null -ne $Perms) {
                    $DelegatedList.Add([PSCustomObject]@{
                        Index    = $Index
                        Selected = $false
                        User     = $mbx.UserPrincipalName
                        Name     = $mbx.DisplayName
                        Rights   = ($Perms.AccessRights -join ", ")
                        Path     = $Path
                    })
                    $Index++
                }
            }
            catch { }
        }

        if ($DelegatedList.Count -eq 0) {
            Write-Host "No external calendar permissions found for $TargetUPN." -ForegroundColor Yellow
            Wait-Console
            return
        }

        $Selecting = $true
        while ($Selecting) {
            Clear-Host
            $ArmedCount = ($DelegatedList | Where-Object { $_.Selected }).Count
            $TotalCount = $DelegatedList.Count

            Write-Host " SHARED CALENDARS STATUS: Total Accessible: $TotalCount | Marked for Revocation: $ArmedCount" -ForegroundColor Cyan
            Write-Host "=========================================================================================================" -ForegroundColor Gray
            
            $FormatStr = "{0,-4} {1,-7} {2,-30} {3,-40} {4,-20}"
            Write-Host ($FormatStr -f "ID", "STATE", "DISPLAY NAME", "CALENDAR OWNER UPN", "CURRENT RIGHTS") -ForegroundColor White
            Write-Host "=========================================================================================================" -ForegroundColor Gray

            foreach ($item in $DelegatedList) {
                $StateStr = if ($item.Selected) { "[X]" } else { "[ ]" }
                $Color = if ($item.Selected) { "Red" } else { "Gray" }
                Write-Host ($FormatStr -f $item.Index, $StateStr, $item.Name, $item.User, $item.Rights) -ForegroundColor $Color
            }

            Write-Host "=========================================================================================================" -ForegroundColor Gray
            Write-Host " INTERACTION COMMANDS:" -ForegroundColor Yellow
            Write-Host "  [#] Toggle index state (e.g. 1 or 1,3,5) | [A] Select All | [D] Clear All Choices"
            Write-Host "  [C] Confirm Revocation & Process           | [0] Return to Menu"
            Write-Host "=========================================================================================================" -ForegroundColor Gray

            $InputChoice = (Read-Host "`nSelection Command").Trim()

            switch -Regex ($InputChoice) {
                "^0$" { return }
                "(?i)^A$" {
                    $DelegatedList | ForEach-Object { $_.Selected = $true }
                }
                "(?i)^D$" {
                    $DelegatedList | ForEach-Object { $_.Selected = $false }
                }
                "(?i)^C$" {
                    $SelectedTargets = $DelegatedList | Where-Object { $_.Selected }
                    if ($SelectedTargets.Count -eq 0) {
                        Write-Host "No items marked for revocation." -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    } else {
                        $Selecting = $false
                    }
                }
                "^[0-9, ]+$" {
                    $Indices = $InputChoice -split ',' | ForEach-Object { $_.Trim() }
                    foreach ($idx in $Indices) {
                        $matched = $DelegatedList | Where-Object { $_.Index -eq [int]$idx }
                        if ($matched) {
                            $matched.Selected = -not $matched.Selected
                        }
                    }
                }
                Default {
                    Write-Host "Invalid Command." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }

        Clear-Host
        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host " EXECUTING PERMISSION REVOCATION" -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Gray

        foreach ($target in ($DelegatedList | Where-Object { $_.Selected })) {
            Write-Host "Removing access to $($target.User)'s calendar..." -NoNewline
            try {
                $null = Remove-MailboxFolderPermission -Identity $target.Path -User $TargetUPN -Confirm:$false -ErrorAction Stop
                Write-Host " [REMOVED]" -ForegroundColor Green
            }
            catch {
                Write-Host " [FAILED: $_]" -ForegroundColor Red
            }
        }
        Write-Host "`n=========================================================================================================" -ForegroundColor Gray
    }
    catch {
        Write-Host "[ERROR] Failed to fetch folder permissions: $_" -ForegroundColor Red
    }

    Wait-Console
}