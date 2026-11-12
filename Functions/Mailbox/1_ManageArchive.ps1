function Invoke-ManageArchive {
    $Identity = $Global:TargetUser.UserPrincipalName
    $ArchivalMenuRunning = $true
    
    while ($ArchivalMenuRunning) {
        Clear-Host
        
        try {
            $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
            $ArchiveStatus = ($Mbx.ArchiveStatus -match "Active|Enabled")
            $CurrentPolicy = $Mbx.RetentionPolicy
            $Tags = Get-ArchiveTagsFromPolicy -PolicyName $CurrentPolicy
        }
        catch {
            Write-Host "Error accessing mailbox configuration: $($_.Exception.Message)" -ForegroundColor Red
            Wait-Console
            return
        }

        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                MANAGE ARCHIVING & RETENTION RULES                   " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Mailbox: $Identity" -ForegroundColor White
        Write-Host "---------------------------------------------------------------------"
        Write-Host " Online Archive Status: " -NoNewline
        Write-ToggleStatus -State $ArchiveStatus
        Write-Host ""

        Write-Host " Current Retention Policy:" -ForegroundColor Gray
        if ([string]::IsNullOrWhiteSpace($CurrentPolicy)) {
            Write-Host "   [None Assigned] (Default tenant retention rules apply)" -ForegroundColor Yellow
        }
        else {
            Write-Host "   Policy: $CurrentPolicy" -ForegroundColor Cyan
            if ($Tags.Count -gt 0) {
                Write-Host "   Move-to-Archive Tags in this policy:" -ForegroundColor Gray
                foreach ($Tag in $Tags) {
                    $DaysStr = "Unlimited / Never"
                    if ($null -ne $Tag.AgeLimitForRetention) {
                        $rawAge = $Tag.AgeLimitForRetention.ToString()
                        if ($rawAge -match '^(\d+)\.') { 
                            $DaysStr = "$($matches[1]) days" 
                        }
                        elseif ($Tag.AgeLimitForRetention.Days -gt 0) { 
                            $DaysStr = "$($Tag.AgeLimitForRetention.Days) days" 
                        }
                        else { 
                            $DaysStr = "$rawAge days" 
                        }
                    }
                    Write-Host "    * $($Tag.Name) (Moves items after $DaysStr)" -ForegroundColor DarkCyan
                }
            } else {
                Write-Host "   (No active 'Move to Archive' tags found in this policy)" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "---------------------------------------------------------------------"
        if ($ArchiveStatus) {
            Write-Host " 1. Disable Online Archive" -ForegroundColor Yellow
        } else {
            Write-Host " 1. Enable Online Archive" -ForegroundColor Green
        }
        Write-Host " 2. Change Retention Policy Assignment"
        Write-Host " 3. Run Managed Folder Assistant (Trigger archiving job now)"
        Write-Host " 0. Back to User Hub"
        Write-Host "---------------------------------------------------------------------"

        $Choice = (Read-Host "Selection").Trim()

        switch ($Choice) {
            "1" {
                if ($ArchiveStatus) {
                    Write-Host "`nWARNING: Disabling an online archive disconnects the archive mailbox." -ForegroundColor Yellow
                    $Confirm = Read-Host "Are you sure you want to disable the archive for $Identity? (Y/N)"
                    if ($Confirm.Trim() -imatch '^Y') {
                        try {
                            Write-Host "Disabling online archive..." -ForegroundColor Gray
                            Disable-Mailbox -Identity $Identity -Archive -Confirm:$false -ErrorAction Stop
                            Write-Host "Archive disabled successfully." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Failed to disable archive: $($_.Exception.Message)" -ForegroundColor Red
                            Wait-Console
                        }
                    }
                }
                else {
                    $Confirm = Read-Host "`nEnable online archive for $Identity? (Y/N)"
                    if ($Confirm.Trim() -imatch '^Y') {
                        try {
                            Write-Host "Provisioning online archive..." -ForegroundColor Gray
                            Enable-Mailbox -Identity $Identity -Archive -ErrorAction Stop
                            Write-Host "Archive enabled successfully!" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Failed to enable archive: $($_.Exception.Message)" -ForegroundColor Red
                            Wait-Console
                        }
                    }
                }
                Start-Sleep -Seconds 1
            }
            "2" {
                Show-RulesPaginationEngine -Identity $Identity
            }
            "3" {
                Write-Host "`nRequesting Managed Folder Assistant process for $Identity..." -ForegroundColor Cyan
                try {
                    Start-ManagedFolderAssistant -Identity $Identity -ErrorAction Stop
                    Write-Host "Success! The Managed Folder Assistant has been triggered for this mailbox." -ForegroundColor Green
                    Write-Host "(Exchange will process retention and archive rules in the background)." -ForegroundColor Gray
                }
                catch {
                    Write-Host "Failed to trigger Managed Folder Assistant: $($_.Exception.Message)" -ForegroundColor Red
                }
                Wait-Console
            }
            "0" { 
                $ArchivalMenuRunning = $false 
            }
            Default {
                Write-Host "Invalid selection. Please choose 0 to 3." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Get-ArchiveTagsFromPolicy {
    param([string]$PolicyName)
    if ([string]::IsNullOrWhiteSpace($PolicyName)) { return @() }
    try {
        $Policy = Get-RetentionPolicy -Identity $PolicyName -ErrorAction Stop
        $Tags = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($link in $Policy.RetentionPolicyTagLinks) {
            $tagObj = Get-RetentionPolicyTag -Identity $link -ErrorAction SilentlyContinue
            if ($tagObj -and $tagObj.RetentionAction -eq "MoveToArchive") {
                $Tags.Add($tagObj)
            }
        }
        return $Tags
    }
    catch {
        return @()
    }
}

function Show-RulesPaginationEngine {
    param([string]$Identity)
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                    AVAILABLE RETENTION POLICIES                     " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    Write-Host "Querying tenant retention policies..." -ForegroundColor Gray
    try { 
        [array]$Policies = @(Get-RetentionPolicy -ErrorAction Stop | Select-Object -ExpandProperty Name)
    } 
    catch { 
        Write-Host "Failed to load retention policies: $($_.Exception.Message)" -ForegroundColor Red
        Wait-Console
        return 
    }

    if ($Policies.Count -eq 0) {
        Write-Host "No retention policies found in this tenant." -ForegroundColor Yellow
        Wait-Console
        return
    }

    Write-Host "`nSelect a retention policy to assign to $($Identity):`n" -ForegroundColor White
    for ($i = 0; $i -lt $Policies.Count; $i++) {
        Write-Host (" {0,2}. {1}" -f ($i + 1), $Policies[$i])
    }
    Write-Host "  0. Cancel"
    Write-Host "---------------------------------------------------------------------"

    $Selection = (Read-Host "Select policy number [0-$($Policies.Count)]").Trim()
    if ($Selection -match '^\d+$' -and [int]$Selection -gt 0 -and [int]$Selection -le $Policies.Count) {
        $NewPolicy = $Policies[[int]$Selection - 1]
        
        $Confirm = Read-Host "`nAssign policy '$NewPolicy' to $Identity? (Y/N)"
        if ($Confirm.Trim() -imatch '^Y') {
            Write-Host "Applying retention policy '$NewPolicy'..." -ForegroundColor Gray
            try {
                Set-Mailbox -Identity $Identity -RetentionPolicy $NewPolicy -ErrorAction Stop
                Write-Host "Retention policy successfully applied!" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to apply policy: $($_.Exception.Message)" -ForegroundColor Red
            }
            Wait-Console
        }
    }
}
