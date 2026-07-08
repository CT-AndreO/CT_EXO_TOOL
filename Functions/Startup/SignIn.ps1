function Invoke-SignIn {
    Clear-Host
    Write-Host "=== EXCHANGE ONLINE AUTHENTICATION ===" -ForegroundColor Cyan
    
    try {
        Write-Host "Loading ExchangeOnlineManagement module..." -ForegroundColor Gray
        Import-Module ExchangeOnlineManagement -ErrorAction Stop

        Write-Host "Launching Microsoft sign-in prompt..." -ForegroundColor Gray
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        
        # Capture the true tenant string for your menus
        Write-Host "Retrieving organizational context..." -ForegroundColor Gray
        $Global:TenantName = (Get-OrganizationConfig).DisplayName
        
        Write-Host "Successfully authenticated to: $Global:TenantName" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Host "`n[AUTHENTICATION ERROR] Failed to connect to Exchange Online." -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        Write-Host "--------------------------------------------------" -ForegroundColor DarkRed
        $Global:TenantName = "Disconnected"
    }
}