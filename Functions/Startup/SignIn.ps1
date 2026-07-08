function Invoke-SignIn {
    Clear-Host
    Write-Host "=== EXCHANGE ONLINE AUTHENTICATION ===" -ForegroundColor Cyan
    Write-Host "Launching Microsoft sign-in prompt..." -ForegroundColor Gray

    try {
        # Connect natively. If an active session already exists, ExchangeOnlineManagement 
        # is smart enough to leverage existing access tokens or offer account switching.
        Connect-ExchangeOnline -ErrorAction Stop
        Write-Host "Successfully authenticated." -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Host "Authentication failed: $_" -ForegroundColor Red
        Read-Host "`nPress Enter to close the script..."
        Exit
    }
}