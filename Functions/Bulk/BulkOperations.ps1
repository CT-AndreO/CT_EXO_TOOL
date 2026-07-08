function Invoke-BulkMenu {
    Clear-Host
    Write-Host "Retrieving tenant mailbox metrics..." -ForegroundColor Gray

    # Fetch total user mailboxes. We filter specifically for 'UserMailbox' 
    # so shared mailboxes or room mailboxes don't throw off your user count.
    try {
        $Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -ErrorAction Stop
        $TotalUsers = if ($null -eq $Mailboxes) { 0 } else { $Mailboxes.Count }
    }
    catch {
        $TotalUsers = "Unknown (Error fetching data)"
    }

    $BulkRunning = $true
    while ($BulkRunning) {
        Clear-Host
        Write-Host "=== BULK OPERATIONS & REPORTING ===" -ForegroundColor Cyan
        Write-Host "Total User Mailboxes: $TotalUsers" -ForegroundColor Gray
        Write-Host "-------------------------------------"
        Write-Host "1. Run Bulk MRM Operations (via CSV)"
        Write-Host "2. Generate Mailbox Export Report"
        Write-Host "0. Back to Main Menu"

        $Choice = Read-Host "`nSelection"

        switch ($Choice) {
            "1" {
                Invoke-BulkMRM
            }
            "2" {
                Invoke-ExportReport 
            }
            "0" {
                $BulkRunning = $false
            }
            Default {
                Write-Host "Invalid Selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Invoke-BulkMRM {
    Clear-Host
    Write-Host "=== BULK MRM OPERATIONS ===" -ForegroundColor Cyan
    Write-Host "Feature placeholder. CSV ingestion logic goes here." -ForegroundColor Yellow
    Read-Host "`nPress Enter to return to Bulk Menu..." 
}