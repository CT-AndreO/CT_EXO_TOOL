function Invoke-Search {
    while ($true) {
        Clear-Host
        Write-Host "=== USER SEARCH ===" -ForegroundColor Cyan
        $Query = Read-Host "Enter Name, UPN, or Email (or '0' to return)"

        if ($Query -eq "0" -or [string]::IsNullOrWhiteSpace($Query)) {
            return $null
        }

        Write-Host "Searching directory..." -ForegroundColor Gray
        
        # Pulling mailboxes directly so we have the Exchange data structure ready to pass
        $FilterString = "DisplayName -like '*$Query*' -or UserPrincipalName -like '*$Query*' -or PrimarySmtpAddress -like '*$Query*'"
        $Results = Get-Mailbox -ResultSize Unlimited -Filter $FilterString -ErrorAction SilentlyContinue

        if (-not $Results) {
            Write-Host "No matching mailboxes found." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
            continue
        }

        # Scenario A: Perfect Single Match
        if ($Results.Count -eq 1) {
            return $Results
        }

        # Scenario B: Multiple Matches Found
        Write-Host "`nMultiple users found matching your query:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Results.Count; $i++) {
            Write-Host ("{0}. {1} ({2})" -f ($i + 1), $Results[$i].DisplayName, $Results[$i].UserPrincipalName)
        }
        Write-Host "0. Cancel and search again"

        $Selection = Read-Host "`nSelect user number"
        if ($Selection -eq "0" -or [string]::IsNullOrWhiteSpace($Selection)) {
            continue
        }

        if ([int]::TryParse($Selection, [ref]$Index) -and $Index -le $Results.Count -and $Index -gt 0) {
            return $Results[$Index - 1]
        }
        else {
            Write-Host "Invalid entry." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}