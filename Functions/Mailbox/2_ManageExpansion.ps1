function Invoke-ManageExpansion {
    $Identity = $Global:TargetUser.UserPrincipalName
    $AutoExpandMenuRunning = $true
    
    while ($AutoExpandMenuRunning) {
        Clear-Host

        try {
            $Mbx = Get-Mailbox -Identity $Identity -ErrorAction Stop
            $AutoExpandEnabled = $Mbx.AutoExpandingArchiveEnabled
        }
        catch {
            Write-Host "Failed evaluating feature directory structure properties: $($_.Exception.Message)" -ForegroundColor Red
            Wait-Console
            return
        }

        Write-Host " [ AUTO EXPANSION ARCHITECTURE CONTROL LAYER: $Identity ] " -BackgroundColor DarkCyan -ForegroundColor White
        Write-Host "------------------------------------------------------------"
        Write-Host " 1. Auto Expansion Status: " -NoNewline
        Write-ToggleStatus -State $AutoExpandEnabled
        Write-Host "------------------------------------------------------------"
        Write-Host " 0. Back"
        Write-Host "------------------------------------------------------------"

        $Choice = Read-Host "Selection"

        switch ($Choice) {
            "1" {
                if ($AutoExpandEnabled) {
                    Write-Host "`nWarning: Microsoft multi-tier storage layers structurally prohibit turning off expansion mechanisms once provisioned." -ForegroundColor Yellow
                    $Confirm = Read-Host "Attempt force cancellation override protocol sequences? (Y/N)"
                    if ($Confirm -imatch 'Y') {
                        try {
                            Disable-Mailbox -Identity $Identity -AutoExpandingArchive -ErrorAction Stop
                            Write-Host "Command accepted by remote endpoint parser." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Operation natively blocked by cloud target framework: $($_.Exception.Message)" -ForegroundColor Red
                        }
                        Wait-Console
                    }
                }
                else {
                    Write-Host "`nInitializing deployment storage expander layers..." -ForegroundColor Gray
                    try {
                        Enable-Mailbox -Identity $Identity -AutoExpandingArchive -ErrorAction Stop
                        Write-Host "Storage expansion layers provisioned successfully!" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Deployment initialization validation failure: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    Wait-Console
                }
            }
            "0" { $AutoExpandMenuRunning = $false }
        }
    }
}