# =====================================================================
# EXO Tool - Microsoft Exchange Online Administration Utility
# =====================================================================

$Global:TargetUser = $null
$Global:TenantName = "Disconnected"
$Global:CentralMailboxCache = $null
$ScriptRunning = $true

# --- 1. INITIALIZE MODULES & FUNCTIONS ---
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

# --- 2. STARTUP SEQUENCE & DEPENDENCY CHECK ---
Test-Dependencies

# --- 3. INITIAL AUTHENTICATION ---
$SignedIn = Invoke-SignIn

if (-not $SignedIn) {
    Write-Host "`nNo active Exchange Online session detected." -ForegroundColor Yellow
    $RetryChoice = Read-Host "Would you like to try signing in again? (Y/N)"
    if ($RetryChoice.Trim() -imatch '^Y') {
        $SignedIn = Invoke-SignIn
    }
    
    if (-not $SignedIn) {
        Write-Host "`nClosing EXO Tool." -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
        Exit
    }
}

# --- 4. MAIN ROUTER LOOP ---
while ($ScriptRunning) {
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                       EXO MANAGEMENT TOOL                           " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Active Organization: " -NoNewline
    if ($Global:TenantName -eq "Disconnected") {
        Write-Host "DISCONNECTED" -ForegroundColor Red
    } else {
        Write-Host "$Global:TenantName" -ForegroundColor Green
    }
    Write-Host "---------------------------------------------------------------------"
    Write-Host " 1. Single Mailbox Management (Search & Manage User)"
    Write-Host " 2. Bulk Operations & Reporting Matrix"
    Write-Host " 3. Exchange Online Event Audit Log (Search-UnifiedAuditLog)"
    Write-Host " 4. Switch Tenant / Sign Out"
    Write-Host " 0. Exit"
    Write-Host "---------------------------------------------------------------------"

    $Choice = (Read-Host "Selection").Trim()

    switch ($Choice) {
        "1" { 
            if ($Global:TenantName -eq "Disconnected") {
                Write-Host "`nYou are currently disconnected. Signing in..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                if (-not (Invoke-SignIn)) { continue }
            }

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
        "2" { 
            if ($Global:TenantName -eq "Disconnected") {
                Write-Host "`nYou are currently disconnected. Signing in..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                if (-not (Invoke-SignIn)) { continue }
            }
            Invoke-BulkMenu 
        }
        "3" { 
            if ($Global:TenantName -eq "Disconnected") {
                Write-Host "`nYou are currently disconnected. Signing in..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                if (-not (Invoke-SignIn)) { continue }
            }
            Invoke-AuditLogMenu 
        }
        "4" { 
            Invoke-SwitchTenant 
        }
        "0" { 
            $ScriptRunning = $false 
            Write-Host "`nDisconnecting Exchange Online sessions..." -ForegroundColor Gray
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "Goodbye!`n" -ForegroundColor Green
        }
        Default { 
            Write-Host "Invalid Selection. Please choose 0 to 3." -ForegroundColor Red
            Start-Sleep -Seconds 1 
        }
    }
}
