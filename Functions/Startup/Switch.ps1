function Invoke-SwitchTenant {
    Clear-Host
    Write-Host "=== SWITCH TENANT / SIGN OUT ===" -ForegroundColor Cyan
    Write-Host "Tearing down current Exchange Online connection context..." -ForegroundColor Gray

    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Session dropped successfully." -ForegroundColor Green
        
        # Reset the layout values back to baseline
        $Global:TenantName = "Disconnected"
        Start-Sleep -Seconds 1
        
        # Run sign-in again for the next client space
        Invoke-SignIn
    }
    catch {
        Write-Host "Error while disconnecting session: $_" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}