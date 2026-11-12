function Test-Dependencies {
    Write-Host "Verifying system prerequisites..." -ForegroundColor Gray

    # 1. Check PowerShell Edition/Version
    $PSMajor = $PSVersionTable.PSVersion.Major
    if ($PSMajor -lt 5) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Red
        Write-Host "         ERROR: POWERSHELL 5.1 OR HIGHER REQUIRED                    " -ForegroundColor Red
        Write-Host "=====================================================================" -ForegroundColor Red
        Write-Host " Current Environment detected: Windows PowerShell v$($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        Write-Host " Please run this script in Windows PowerShell 5.1 or PowerShell 7+." -ForegroundColor White
        Write-Host "=====================================================================" -ForegroundColor Red
        Read-Host "`nPress Enter to exit..."
        Exit
    }

    # 2. Check for ExchangeOnlineManagement module
    $ModuleInstalled = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Select-Object -First 1
    if (-not $ModuleInstalled) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Yellow
        Write-Host "         MISSING MODULE: ExchangeOnlineManagement                    " -ForegroundColor Yellow
        Write-Host "=====================================================================" -ForegroundColor Yellow
        Write-Host " The required 'ExchangeOnlineManagement' module was not found." -ForegroundColor White
        Write-Host " Would you like to install it now for CurrentUser? (Y/N)" -ForegroundColor Cyan
        $InstallChoice = Read-Host " Install Module"
        
        if ($InstallChoice.Trim() -imatch '^Y') {
            try {
                Write-Host "`nInstalling ExchangeOnlineManagement module from PSGallery..." -ForegroundColor Gray
                Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-Host "Installation completed successfully!`n" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            catch {
                Write-Host "`n[ERROR] Failed to install module: $_" -ForegroundColor Red
                Write-Host "Please install it manually by running: Install-Module ExchangeOnlineManagement" -ForegroundColor Yellow
                Read-Host "`nPress Enter to exit..."
                Exit
            }
        }
        else {
            Write-Host "`nThe tool cannot run without ExchangeOnlineManagement." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            Exit
        }
    }
}
