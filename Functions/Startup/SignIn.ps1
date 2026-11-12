function Invoke-SignIn {
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                 EXCHANGE ONLINE AUTHENTICATION                     " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    try {
        Write-Host "Importing ExchangeOnlineManagement module..." -ForegroundColor Gray
        Import-Module ExchangeOnlineManagement -ErrorAction Stop

        Write-Host "Opening Microsoft sign-in prompt..." -ForegroundColor Gray
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        
        Write-Host "Detecting organization context..." -ForegroundColor Gray
        $OrgConfig = Get-OrganizationConfig -ErrorAction SilentlyContinue
        
        if ($OrgConfig -and $OrgConfig.DisplayName) {
            $Global:TenantName = $OrgConfig.DisplayName
        }
        else {
            $Conn = Get-ConnectionInformation -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($Conn -and $Conn.UserPrincipalName) {
                $Global:TenantName = ($Conn.UserPrincipalName -split '@')[-1]
            }
            elseif ($Conn -and $Conn.TenantId) {
                $Global:TenantName = $Conn.TenantId
            }
            else {
                $Global:TenantName = "Connected Tenant"
            }
        }
        
        Write-Host "`nSuccessfully authenticated to: $Global:TenantName" -ForegroundColor Green
        Start-Sleep -Seconds 1
        return $true
    }
    catch {
        Write-Host "`n[AUTHENTICATION FAILED] Could not connect to Exchange Online." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "---------------------------------------------------------------------" -ForegroundColor DarkRed
        $Global:TenantName = "Disconnected"
        Wait-Console "Press Enter to continue..."
        return $false
    }
}
