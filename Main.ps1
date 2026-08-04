$Global:TargetUser = $null
$Global:TenantName = "Disconnected"
$ScriptRunning = $true

# --- 1. INITIALIZE MODULES ---
$FunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "Functions"
if (Test-Path $FunctionsPath) {
    Get-ChildItem -Path $FunctionsPath -Recurse -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}
else {
    Write-Host "Error: Functions folder missing at $FunctionsPath" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    Exit
}

# --- 2. STARTUP SEQUENCE & VERIFICATION ---
Invoke-SignIn

Write-Host "Verifying Exchange Online connection context..." -ForegroundColor Gray
$ActiveSession = Get-ConnectionInformation -ErrorAction SilentlyContinue

if (-not $ActiveSession) {
    Write-Host "`n[CRITICAL ERROR] No active Exchange Online session detected!" -ForegroundColor Red
    Read-Host "`nPress Enter to close the script..."
    Exit
}

# --- 3. MAIN ROUTER ---
while ($ScriptRunning) {
    Clear-Host
    Write-Host "=== EXO MANAGEMENT TOOL [$Global:TenantName] ===" -ForegroundColor Cyan
    Write-Host "1. Single User Management"
    Write-Host "2. Bulk Operations & Reporting"
    Write-Host "3. Switch Tenant / Sign Out"
    Write-Host "0. Exit"

    $Choice = Read-Host "`nSelection"

    switch ($Choice) {
        "1" { 
            $InSearchSession = $true
            while ($InSearchSession) {
                $Global:TargetUser = Invoke-Search
                if ($null -ne $Global:TargetUser) {
                    Invoke-UserMenu    
                    $Global:TargetUser = $null
                }
                else {
                    $InSearchSession = $false
                }
            }
        }
        "2" { Invoke-BulkMenu }
        "3" { Invoke-SwitchTenant }
        "0" { $ScriptRunning = $false }
        Default { 
            Write-Host "Invalid Selection." -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
}