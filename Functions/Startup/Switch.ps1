function Clear-SessionState {
    # Purge all tenant-specific data from memory to prevent cross-tenant leakage
    $Global:CentralMailboxCache = $null
    $Global:TargetUser = $null
    $Global:ActiveView = "Storage"
    $Global:StorageAction = "Enable"
    $Global:DelegateAction = "Grant"
    $Global:SelectedDelegation = "None"
}

function Invoke-SwitchTenant {
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                    SWITCH TENANT / SIGN OUT                         " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Current Organization: $Global:TenantName" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------------"
    Write-Host " 1. Switch to a different tenant (Disconnect & Sign In)"
    Write-Host " 2. Disconnect current session only"
    Write-Host " 0. Cancel and return"
    Write-Host "---------------------------------------------------------------------"

    $Choice = Read-Host "Selection"
    switch ($Choice.Trim()) {
        "1" {
            Write-Host "`nDisconnecting current Exchange Online session..." -ForegroundColor Gray
            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                Clear-SessionState
                $Global:TenantName = "Disconnected"
                Write-Host "Disconnected successfully." -ForegroundColor Green
                Start-Sleep -Seconds 1
                
                # Prompt sign-in for the next tenant
                Invoke-SignIn
            }
            catch {
                Write-Host "Error while disconnecting session: $($_.Exception.Message)" -ForegroundColor Red
                Wait-Console
            }
        }
        "2" {
            Write-Host "`nDisconnecting current Exchange Online session..." -ForegroundColor Gray
            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                Clear-SessionState
                $Global:TenantName = "Disconnected"
                Write-Host "Session disconnected. Tenant data cleared." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            catch {
                Write-Host "Error while disconnecting session: $($_.Exception.Message)" -ForegroundColor Red
                Wait-Console
            }
        }
        "0" { return }
        Default {
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
