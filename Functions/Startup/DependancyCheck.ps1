# Functions\Startup DependancyCheck.ps1

Write-Host "Checking framework dependencies..." -ForegroundColor Gray

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host "             CRITICAL ERROR: MODERN POWERSHELL REQUIRED             " -ForegroundColor Red
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host " This architecture relies on multi-threaded parallel processing pipelines " -ForegroundColor White
    Write-Host " that are only supported in PowerShell 7 Core or higher.`n" -ForegroundColor White
    Write-Host " Current Environment detected: Windows PowerShell v$($PSVersionTable.PSVersion.ToString())" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------------"
    Write-Host " HOW TO FIX THIS:" -ForegroundColor Cyan
    Write-Host " 1. Close this window."
    Write-Host " 2. Open an elevated terminal and run: pwsh"
    Write-Host "    (If not installed, download from: https://aka.ms/powershell-release)"
    Write-Host " 3. Re-run your controller initialization script."
    Write-Host "=====================================================================" -ForegroundColor Red
    
    Read-Host "`nPress Enter to abort script execution..."
    Exit
}