$Global:SandboxMode = $true
$Global:TargetUser = $null
$ScriptRunning = $true

# --- 1. INITIALIZE MODULES ---
# This loop recursively finds every .ps1 file in the Functions folder and loads 
# them into memory once. No more manual dot-sourcing for every new file you create.
$FunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "Functions"
Get-ChildItem -Path $FunctionsPath -Recurse -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# --- 2. STARTUP SEQUENCE ---
# Calling the functions loaded from the Startup folder
# Invoke-DependencyCheck # Uncomment if you decide to use it
Invoke-SignIn

# --- 3. MAIN ROUTER ---
while ($ScriptRunning) {
    Clear-Host
    Write-Host "=== EXO MANAGEMENT TOOL ===" -ForegroundColor Cyan
    Write-Host "1. Single User Management"
    Write-Host "2. Bulk Operations & Reporting"
    Write-Host "3. Switch Tenant / Sign Out"
    Write-Host "0. Exit"

    $Choice = Read-Host "`nSelection"

    switch ($Choice) {
        "1" { 
            $InSearchSession = $true
            while ($InSearchSession) {
                
                # 1. Trigger the Search (Function defined in Search.ps1)
                $Global:TargetUser = Invoke-Search

                # 2. Check if a user was actually picked
                if ($null -ne $Global:TargetUser) {
                    
                    # Jump into the User Hub (Function defined in Menu.ps1)
                    Invoke-UserMenu    
                    
                    # Clear user after the sub-menu exits to reset for the next search
                    $Global:TargetUser = $null
                } 
                else {
                    # If Invoke-Search returns null (user hit 'cancel'), break to Main Menu
                    $InSearchSession = $false
                }
            }
        }
        "2" { 
            # Function defined in BulkOperation.ps1
            Invoke-BulkMenu
        }
        "3" {
            # Function defined in Switch.ps1
            Invoke-SwitchTenant
        }
        "0" { 
            $ScriptRunning = $false 
        }
        Default { 
            Write-Host "Invalid Selection." -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
}