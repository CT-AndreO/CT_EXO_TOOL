function Invoke-ManageArchive {
    # Initialize state baselines for the simulated Sandbox workspace
    if ($null -eq $Global:SandboxArchiveEnabled) { $Global:SandboxArchiveEnabled = $true }
    if ($null -eq $Global:SandboxPolicy) { $Global:SandboxPolicy = "Default MRM Policy" }

    $Identity = $Global:TargetUser.UserPrincipalName
    $ArchivalMenuRunning = $true
    
    while ($ArchivalMenuRunning) {
        Clear-Host
        
        if ($Global:SandboxMode) {
            $ArchiveStatus = $Global:SandboxArchiveEnabled
            $CurrentPolicy = $Global:SandboxPolicy
            $Tags = @([PSCustomObject]@{ Name = "Sandbox-Move-1Yr"; AgeLimitForRetention = "365.00:00:00" })
        } else {
            try {
                $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
                $ArchiveStatus = ($Mbx.ArchiveStatus -match "Active|Enabled")
                $CurrentPolicy = $Mbx.RetentionPolicy
                $Tags = Get-ArchiveTagsFromPolicy -PolicyName $CurrentPolicy
            } catch {
                Write-Host "Error accessing mailbox configurations: $($_.Exception.Message)" -ForegroundColor Red
                Wait-Console
                return
            }
        }

        Write-Host " [ MANAGE ARCHIVAL RULES: $Identity ] " -BackgroundColor Magenta -ForegroundColor White
        Write-Host "------------------------------------------------------------"
        Write-Host " 1. Auto Archiving Status: " -NoNewline
        Write-ToggleStatus -State $ArchiveStatus

        Write-Host "`n Current Active Rule Details:" -ForegroundColor Gray
        if ([string]::IsNullOrWhiteSpace($CurrentPolicy)) {
            Write-Host "   No Retention Policy baseline assigned." -ForegroundColor Yellow
        } else {
            Write-Host "   Policy Container: $CurrentPolicy" -ForegroundColor Cyan
            foreach ($Tag in $Tags) {
                $DaysStr = "Unlimited/Never"
                if ($null -ne $Tag.AgeLimitForRetention) {
                    $rawAge = $Tag.AgeLimitForRetention.ToString()
                    if ($rawAge -match '^(\d+)\.') { $DaysStr = "$($matches[1]) days" }
                    elseif ($Tag.AgeLimitForRetention.Days -gt 0) { $DaysStr = "$($Tag.AgeLimitForRetention.Days) days" }
                    else { $DaysStr = "$rawAge days" }
                }
                Write-Host "    -> Tag Mapping: $($Tag.Name) (Moves after $DaysStr)" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "------------------------------------------------------------"
        Write-Host " 2. View System Policies / Change Assignment"
        Write-Host " 3. Force Instantiation Loop (Run Managed Folder Assistant)" -ForegroundColor Yellow
        Write-Host " 0. Back"
        Write-Host "------------------------------------------------------------"

        $Choice = Read-Host "Selection"

        switch ($Choice) {
            "1" {
                if ($ArchiveStatus) {
                    Write-Host "`nRequesting Archive Provision Reversal..." -ForegroundColor Gray
                    if ($Global:SandboxMode) { $Global:SandboxArchiveEnabled = $false }
                    else {
                        try { Disable-Mailbox -Identity $Identity -Archive -Confirm:$false -ErrorAction Stop }
                        catch { Write-Host "Execution Halted: $($_.Exception.Message)" -ForegroundColor Red; Wait-Console }
                    }
                } else {
                    Write-Host "`nProvisioning Online Archive Module..." -ForegroundColor Gray
                    if ($Global:SandboxMode) { $Global:SandboxArchiveEnabled = $true }
                    else {
                        try { Enable-Mailbox -Identity $Identity -Archive -ErrorAction Stop }
                        catch { Write-Host "Execution Halted: $($_.Exception.Message)" -ForegroundColor Red; Wait-Console }
                    }
                }
                Start-Sleep -Seconds 1
            }
            "2" {
                Show-RulesPaginationEngine -Identity $Identity
            }
            "3" {
                Write-Host "`nSignaling Managed Folder Assistant Engine Synchronization..." -ForegroundColor Cyan
                if ($Global:SandboxMode) {
                    Write-Host "[SANDBOX] MFA cycle execution processing simulation verified." -ForegroundColor Green
                } else {
                    try {
                        Start-ManagedFolderAssistant -Identity $Identity -ErrorAction Stop
                        Write-Host "Success! Target requested for immediate priority pipeline processing." -ForegroundColor Green
                    } catch {
                        Write-Host "Execution error calling backend background automation: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                Wait-Console
            }
            "0" { $ArchivalMenuRunning = $false }
        }
    }
}

# --- SUPPORTING ENGINE SUB-ROUTINES ---

function Get-ArchiveTagsFromPolicy {
    param([string]$PolicyName)
    if ([string]::IsNullOrWhiteSpace($PolicyName)) { return @() }
    try {
        $Policy = Get-RetentionPolicy -Identity $PolicyName -ErrorAction Stop
        # Gathers all RetentionPolicyTag objects linked inside the container definition
        $Tags = $Policy.RetentionPolicyTagLinks | ForEach-Object { 
            Get-RetentionPolicyTag -Identity $_ -ErrorAction SilentlyContinue 
        } | Where-Object { $_.RetentionAction -eq "MoveToArchive" }
        return $Tags
    } catch {
        return @()
    }
}

function Show-RulesPaginationEngine {
    param([string]$Identity)
    Clear-Host
    Write-Host "=== AVAILABLE RETENTION POLICIES ===" -ForegroundColor Cyan
    
    if ($Global:SandboxMode) {
        $Policies = @("Default MRM Policy", "Executive-90Day-Archive", "Finance-7Year-Retention")
    } else {
        Write-Host "Querying tenant system configuration lists..." -ForegroundColor Gray
        try { $Policies = (Get-RetentionPolicy).Name } catch { return }
    }

    for ($i = 0; $i -lt $Policies.Count; $i++) {
        Write-Host (" {0}. {1}" -f ($i + 1), $Policies[$i])
    }
    Write-Host " 0. Cancel"

    $Selection = Read-Host "`nSelect policy number to assign"
    if ($Selection -match '^\d+$' -and [int]$Selection -gt 0 -and [int]$Selection -le $Policies.Count) {
        $NewPolicy = $Policies[[int]$Selection - 1]
        Write-Host "`nApplying policy changes..." -ForegroundColor Gray
        
        if ($Global:SandboxMode) {
            $Global:SandboxPolicy = $NewPolicy
            Write-Host "Assignment simulated successfully." -ForegroundColor Green
        } else {
            try {
                Set-Mailbox -Identity $Identity -RetentionPolicy $NewPolicy -ErrorAction Stop
                Write-Host "Policy update successfully committed to cloud directory endpoints!" -ForegroundColor Green
            } catch {
                Write-Host "Failed applying modification: $_" -ForegroundColor Red
            }
        }
        Start-Sleep -Seconds 1.5
    }
}