function Invoke-SwitchTenant {
    Clear-Host
    Write-Host "=== SWITCH TENANT / SIGN OUT ===" -ForegroundColor Cyan
    Write-Host "Tearing down current Exchange Online connection context..." -ForegroundColor Gray

    try {
        # Drops the current session without asking for terminal confirmations
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Session dropped successfully." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        # Immediately hand execution back to the authentication block for the next tenant
        Invoke-SignIn
    }
    catch {
        Write-Host "Error while disconnecting session: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}