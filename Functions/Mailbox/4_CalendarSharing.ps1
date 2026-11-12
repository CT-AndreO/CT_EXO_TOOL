function Invoke-CalendarSharing {
    if ($null -eq $Global:TargetUser) {
        Write-Host "Error: No target user selected." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }

    $TargetUPN = $Global:TargetUser.UserPrincipalName
    $CalendarPath = Get-CalendarFolderPath -UserPrincipalName $TargetUPN
    
    $SharingRunning = $true
    while ($SharingRunning) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                    CALENDAR PERMISSIONS & DELEGATION                " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Active User:      $($Global:TargetUser.DisplayName) ($TargetUPN)" -ForegroundColor White
        Write-Host " Calendar Folder:  $CalendarPath" -ForegroundColor Gray
        Write-Host "---------------------------------------------------------------------"
        Write-Host " 1. View Calendar Permissions (Who can access THIS user's calendar)"
        Write-Host " 2. Grant Access to THIS User's Calendar (Add / Update a delegate)"
        Write-Host " 3. Revoke Access from THIS User's Calendar (Remove a delegate)"
        Write-Host " 4. Check Inbound Delegations (Calendars shared WITH this user)"
        Write-Host " 5. Bulk Delegate OTHER Mailbox Calendars TO this user"
        Write-Host " 0. Return to User Hub"
        Write-Host "---------------------------------------------------------------------"

        $Choice = (Read-Host "Selection").Trim()

        switch ($Choice) {
            "1" { Show-CalendarPermissions -CalendarPath $CalendarPath }
            "2" { Add-CalendarDelegate -CalendarPath $CalendarPath -TargetUPN $TargetUPN }
            "3" { Remove-CalendarDelegate -CalendarPath $CalendarPath -TargetUPN $TargetUPN }
            "4" { Show-InboundDelegations -TargetUPN $TargetUPN }
            "5" { Add-BulkCalendarPermissions -TargetUPN $TargetUPN }
            "0" { $SharingRunning = $false }
            Default {
                Write-Host "Invalid selection. Please choose 0 to 5." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-CalendarPermissions {
    param([string]$CalendarPath)
    
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "             PERMISSIONS ASSIGNED TO THIS CALENDAR                   " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Folder: $CalendarPath" -ForegroundColor Gray
    Write-Host " Querying Exchange Online permissions..." -ForegroundColor DarkGray

    try {
        $Permissions = @(Get-MailboxFolderPermission -Identity $CalendarPath -ErrorAction Stop)
        
        Write-Host "`n---------------------------------------------------------------------"
        $FormatStr = "{0,-35} {1,-20} {2,-15}"
        Write-Host ($FormatStr -f "User / Identity", "Access Rights", "Sharing Flags") -ForegroundColor White
        Write-Host "---------------------------------------------------------------------"
        
        foreach ($perm in $Permissions) {
            $Rights = $perm.AccessRights -join ", "
            $Color = if ($perm.User.DisplayName -eq "Default" -or $perm.User.DisplayName -eq "Anonymous") { "DarkGray" } else { "Green" }
            Write-Host ($FormatStr -f $perm.User, $Rights, $perm.SharingPermissionFlags) -ForegroundColor $Color
        }
        Write-Host "---------------------------------------------------------------------"
    }
    catch {
        Write-Host "[ERROR] Failed to fetch folder permissions: $($_.Exception.Message)" -ForegroundColor Red
    }

    Wait-Console
}

function Add-CalendarDelegate {
    param(
        [string]$CalendarPath,
        [string]$TargetUPN
    )

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "              GRANT ACCESS TO THIS USER'S CALENDAR                   " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Target Calendar: $CalendarPath" -ForegroundColor Gray
    
    $DelegateUPN = (Read-Host "`nEnter the UPN or Email of the user receiving access (or 0 to cancel)").Trim()
    if ($DelegateUPN -eq "0" -or [string]::IsNullOrWhiteSpace($DelegateUPN)) { return }

    Write-Host "`nSelect Permission Role for $($DelegateUPN):" -ForegroundColor Yellow
    Write-Host " 1. AvailabilityOnly  (Free/Busy time only)"
    Write-Host " 2. LimitedDetails    (Free/Busy time, subject, and location)"
    Write-Host " 3. Reviewer          (Read all calendar details)"
    Write-Host " 4. Author            (Read and create calendar items)"
    Write-Host " 5. Editor            (Read, create, modify, and delete all items)"
    Write-Host " 6. Owner             (Full rights including permission management)"
    Write-Host " 0. Cancel"
    
    $RoleChoice = (Read-Host "Role [0-6]").Trim()
    $Role = switch ($RoleChoice) {
        "1" { "AvailabilityOnly" }
        "2" { "LimitedDetails" }
        "3" { "Reviewer" }
        "4" { "Author" }
        "5" { "Editor" }
        "6" { "Owner" }
        Default { $null }
    }

    if (-not $Role) {
        Write-Host "Operation cancelled or invalid role selected." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    Write-Host "`nAssigning '$Role' permission to $DelegateUPN on $CalendarPath..." -ForegroundColor Gray
    try {
        $null = Add-MailboxFolderPermission -Identity $CalendarPath -User $DelegateUPN -AccessRights $Role -ErrorAction Stop
        Write-Host "Access successfully granted!" -ForegroundColor Green
    }
    catch {
        # If user permission already exists, update via Set-MailboxFolderPermission
        try {
            $null = Set-MailboxFolderPermission -Identity $CalendarPath -User $DelegateUPN -AccessRights $Role -ErrorAction Stop
            Write-Host "Existing permission updated successfully to '$Role'!" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to assign permission: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Wait-Console
}

function Remove-CalendarDelegate {
    param(
        [string]$CalendarPath,
        [string]$TargetUPN
    )

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "            REVOKE ACCESS FROM THIS USER'S CALENDAR                  " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Folder: $CalendarPath" -ForegroundColor Gray

    try {
        $RawPerms = @(Get-MailboxFolderPermission -Identity $CalendarPath -ErrorAction Stop)
        # Filter out Default and Anonymous
        $CustomPerms = @($RawPerms | Where-Object { $_.User.DisplayName -ne "Default" -and $_.User.DisplayName -ne "Anonymous" })

        if ($CustomPerms.Count -eq 0) {
            Write-Host "`nNo custom delegates currently have access to this calendar." -ForegroundColor Yellow
            Wait-Console
            return
        }

        Write-Host "`nCurrent delegates assigned to this calendar:`n" -ForegroundColor White
        for ($i = 0; $i -lt $CustomPerms.Count; $i++) {
            $Rights = $CustomPerms[$i].AccessRights -join ", "
            Write-Host (" {0,2}. {1,-35} [{2}]" -f ($i + 1), $CustomPerms[$i].User, $Rights)
        }
        Write-Host "  0. Cancel"
        Write-Host "---------------------------------------------------------------------"

        $Selection = (Read-Host "Select delegate number to revoke").Trim()
        if ($Selection -match '^\d+$' -and [int]$Selection -gt 0 -and [int]$Selection -le $CustomPerms.Count) {
            $TargetDelegate = $CustomPerms[[int]$Selection - 1]
            $DelegateIdentity = $TargetDelegate.User.UserPrincipalName
            if ([string]::IsNullOrWhiteSpace($DelegateIdentity)) {
                $DelegateIdentity = $TargetDelegate.User.DisplayName
            }

            $Confirm = Read-Host "`nAre you sure you want to revoke access for '$DelegateIdentity'? (Y/N)"
            if ($Confirm.Trim() -imatch '^Y') {
                Write-Host "Removing calendar permission..." -ForegroundColor Gray
                try {
                    Remove-MailboxFolderPermission -Identity $CalendarPath -User $DelegateIdentity -Confirm:$false -ErrorAction Stop
                    Write-Host "Permission successfully revoked!" -ForegroundColor Green
                }
                catch {
                    Write-Host "Failed to remove permission: $($_.Exception.Message)" -ForegroundColor Red
                }
                Wait-Console
            }
        }
    }
    catch {
        Write-Host "[ERROR] Could not retrieve permissions: $($_.Exception.Message)" -ForegroundColor Red
        Wait-Console
    }
}

function Show-InboundDelegations {
    param([string]$TargetUPN)
    
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                  INBOUND CALENDAR DELEGATION DISCOVERY              " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Search for external calendars shared with: $TargetUPN" -ForegroundColor Gray
    Write-Host "---------------------------------------------------------------------"
    Write-Host " 1. Check a specific mailbox calendar"
    Write-Host " 2. Scan entire tenant (Warning: Resource intensive on large tenants)"
    Write-Host " 0. Cancel"
    Write-Host "---------------------------------------------------------------------"

    $DiscoveryChoice = (Read-Host "Selection").Trim()

    switch ($DiscoveryChoice) {
        "1" {
            $SpecificUPN = (Read-Host "`nEnter mailbox UPN or email to inspect").Trim()
            if ([string]::IsNullOrWhiteSpace($SpecificUPN)) { return }

            Write-Host "Checking calendar permissions on $SpecificUPN..." -ForegroundColor Gray
            try {
                $TargetCalPath = Get-CalendarFolderPath -UserPrincipalName $SpecificUPN
                $Perms = Get-MailboxFolderPermission -Identity $TargetCalPath -User $TargetUPN -ErrorAction SilentlyContinue
                if ($Perms) {
                    Write-Host "`n[FOUND] $TargetUPN has access to $SpecificUPN's calendar!" -ForegroundColor Green
                    Write-Host " Rights: $($Perms.AccessRights -join ', ')" -ForegroundColor Yellow
                } else {
                    Write-Host "`n$TargetUPN has no permissions on $SpecificUPN's calendar." -ForegroundColor Gray
                }
            } catch {
                Write-Host "Could not query mailbox: $($_.Exception.Message)" -ForegroundColor Red
            }
            Wait-Console
        }
        "2" {
            Write-Host "`nScanning all tenant mailboxes can trigger Exchange Online throttling." -ForegroundColor Yellow
            $Confirm = Read-Host "Proceed with full-tenant scan for $TargetUPN? (Y/N)"
            if ($Confirm.Trim() -notmatch '^Y') { return }

            try {
                $Mailboxes = @(Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop)
                $Total = $Mailboxes.Count
                $FoundCount = 0
                $Count = 0

                Write-Host "Scanning $Total tenant mailboxes..." -ForegroundColor Gray

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
                    Write-Host "`nNo inbound calendar permissions discovered for $TargetUPN." -ForegroundColor Gray
                } else {
                    Write-Host "`nFound $FoundCount shared calendars." -ForegroundColor Green
                }
            }
            catch {
                Write-Host "[ERROR] Tenant query failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            Wait-Console
        }
    }
}

function Add-BulkCalendarPermissions {
    param([string]$TargetUPN)

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "            BULK DELEGATE EXTERNAL CALENDARS TO THIS USER            " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Loading directory mailboxes..." -ForegroundColor Gray

    try {
        $AllMailboxes = @(Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox -ErrorAction Stop | 
            Where-Object { $_.UserPrincipalName -ne $TargetUPN })

        if ($AllMailboxes.Count -eq 0) {
            Write-Host "No other eligible mailboxes found in the tenant." -ForegroundColor Yellow
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

            Write-Host "=====================================================================" -ForegroundColor Cyan
            Write-Host " SELECT MAILBOXES TO GRANT ACCESS ON (Total: $TotalCount | Selected: $ArmedCount)" -ForegroundColor Cyan
            Write-Host "=====================================================================" -ForegroundColor Cyan
            
            $FormatStr = "{0,-4} {1,-7} {2,-30} {3,-35}"
            Write-Host ($FormatStr -f "#", "State", "Display Name", "User Principal Name") -ForegroundColor White
            Write-Host "---------------------------------------------------------------------"

            foreach ($item in $SelectionList) {
                $StateStr = if ($item.Selected) { "[X]" } else { "[ ]" }
                $Color = if ($item.Selected) { "Green" } else { "Gray" }
                Write-Host ($FormatStr -f $item.Index, $StateStr, $item.DisplayName, $item.UPN) -ForegroundColor $Color
            }

            Write-Host "---------------------------------------------------------------------"
            Write-Host " Commands:" -ForegroundColor Yellow
            Write-Host "  [#] Toggle index (e.g. 1 or 1,3,5) | [A] Select All | [D] Clear All"
            Write-Host "  [C] Confirm Selection & Proceed     | [0] Cancel & Return"
            Write-Host "---------------------------------------------------------------------"

            $InputChoice = (Read-Host "Command").Trim()

            switch -Regex ($InputChoice) {
                "^0$" { return }
                "(?i)^A$" {
                    $SelectionList | ForEach-Object { $_.Selected = $true }
                }
                "(?i)^D$" {
                    $SelectionList | ForEach-Object { $_.Selected = $false }
                }
                "(?i)^C$" {
                    $SelectedTargets = @($SelectionList | Where-Object { $_.Selected })
                    if ($SelectedTargets.Count -eq 0) {
                        Write-Host "No mailboxes selected. Please select items first." -ForegroundColor Red
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
                    Write-Host "Invalid command." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }

        # Role Selection Prompt
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "               SELECT PERMISSION ROLE TO ASSIGN                      " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Assigning access for: $TargetUPN`n" -ForegroundColor White
        Write-Host " 1. AvailabilityOnly  (Free/Busy time only)"
        Write-Host " 2. LimitedDetails    (Free/Busy time, subject, and location)"
        Write-Host " 3. Reviewer          (Read full calendar details)"
        Write-Host " 4. Author            (Read and create items)"
        Write-Host " 5. Editor            (Read, create, edit, and delete all items)"
        Write-Host " 6. Owner             (Full rights including permission management)"
        Write-Host " 0. Cancel"
        Write-Host "---------------------------------------------------------------------"
        
        $RoleChoice = (Read-Host "Select Role [0-6]").Trim()
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
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            return
        }

        $SelectedMailboxes = @($SelectionList | Where-Object { $_.Selected } | Select-Object -ExpandProperty Object)
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                 EXECUTING CALENDAR DELEGATION                       " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "Assigning '$Role' access on $($SelectedMailboxes.Count) calendars to $TargetUPN...`n" -ForegroundColor Yellow

        foreach ($recipient in $SelectedMailboxes) {
            $TargetCalendarPath = Get-CalendarFolderPath -UserPrincipalName $recipient.UserPrincipalName
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
                    Write-Host " [FAILED: $($_.Exception.Message)]" -ForegroundColor Red
                }
            }
        }
        Write-Host "`nDelegation processing complete." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Operation failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    Wait-Console
}
