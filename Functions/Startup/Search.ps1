function Invoke-Search {
    if ($Global:TenantName -eq "Disconnected") {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Red
        Write-Host "                         NO ACTIVE CONNECTION                        " -ForegroundColor Red
        Write-Host "=====================================================================" -ForegroundColor Red
        Write-Host "You must authenticate to Exchange Online before searching for mailboxes." -ForegroundColor Yellow
        Wait-Console "Press Enter to return..."
        return $null
    }

    while ($true) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                           USER MAILBOX LOOKUP                       " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "Search by Display Name, UserPrincipalName (Email), or Alias." -ForegroundColor Gray
        Write-Host "Enter '0' at any time to return to the main menu.`n" -ForegroundColor DarkGray

        $Query = (Read-Host "Search Term").Trim()

        if ($Query -eq "0" -or [string]::IsNullOrWhiteSpace($Query)) {
            return $null
        }

        Write-Host "Searching Exchange Online directory..." -ForegroundColor Gray
        
        try {
            if ($Query.Length -lt 3) {
                # Fallback for short prefix queries (1-2 chars)
                $FilterString = "DisplayName -like '$Query*' -or Alias -like '$Query*' -or UserPrincipalName -like '$Query*'"
                [array]$Results = Get-Mailbox -ResultSize 50 -Filter $FilterString -ErrorAction Stop
            } else {
                # High-speed Ambiguous Name Resolution for 3+ characters
                [array]$Results = Get-Mailbox -ResultSize 50 -Anr $Query -ErrorAction Stop
            }
        }
        catch {
            Write-Host "`n[SEARCH ERROR] Directory lookup failed." -ForegroundColor Red
            Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
            Wait-Console "Press Enter to try again..."
            continue
        }

        if ($Results.Count -eq 0) {
            Write-Host "`nNo mailboxes found matching '$Query'." -ForegroundColor Yellow
            Start-Sleep -Seconds 1.5
            continue
        }

        # Scenario A: Exactly one match found
        if ($Results.Count -eq 1) {
            return $Results[0]
        }

        # Scenario B: Multiple matches found
        Write-Host "`nFound $($Results.Count) matching mailboxes for '$Query':" -ForegroundColor Cyan
        Write-Host "---------------------------------------------------------------------"
        $FormatStr = "{0,-4} {1,-32} {2,-35}"
        Write-Host ($FormatStr -f "#", "Display Name", "UserPrincipalName") -ForegroundColor White
        Write-Host "---------------------------------------------------------------------"
        for ($i = 0; $i -lt $Results.Count; $i++) {
            Write-Host ($FormatStr -f ($i + 1), $Results[$i].DisplayName, $Results[$i].UserPrincipalName)
        }
        Write-Host "---------------------------------------------------------------------"
        Write-Host " 0. Cancel and search again"

        $Selection = (Read-Host "`nSelect mailbox number [1-$($Results.Count)]").Trim()
        if ($Selection -eq "0" -or [string]::IsNullOrWhiteSpace($Selection)) {
            continue
        }

        if ($Selection -match '^\d+$') {
            $Index = [int]$Selection
            if ($Index -ge 1 -and $Index -le $Results.Count) {
                return $Results[$Index - 1]
            }
        }
        
        Write-Host "Invalid selection number." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}
