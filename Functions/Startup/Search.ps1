function Invoke-Search {
    while ($true) {
        Clear-Host
        Write-Host "=== USER SEARCH ===" -ForegroundColor Cyan
        $Query = Read-Host "Enter Name, UPN, or Email (or '0' to return)"

        if ($Query -eq "0" -or [string]::IsNullOrWhiteSpace($Query)) {
            return $null
        }

        Write-Host "Searching directory..." -ForegroundColor Gray
        
        try {
            if ($Query.Length -lt 3) {
                # Fallback for short queries (1-2 chars). Trailing wildcards are highly indexed and legal.
                $FilterString = "DisplayName -like '$Query*' -or Alias -like '$Query*' -or UserPrincipalName -like '$Query*'"
                [array]$Results = Get-Mailbox -ResultSize Unlimited -Filter $FilterString -ErrorAction Stop
            } else {
                # Standard high-speed ambiguous name resolution for 3+ characters
                [array]$Results = Get-Mailbox -ResultSize Unlimited -Anr $Query -ErrorAction Stop
            }
        }
        catch {
            Write-Host "`n[SEARCH ERROR] Directory lookup failed." -ForegroundColor Red
            Write-Host "Details: $_" -ForegroundColor Red
            Read-Host "`nPress Enter to try again..."
            continue
        }

        if ($Results.Count -eq 0) {
            Write-Host "No matching mailboxes found." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
            continue
        }

        # Scenario A: Perfect Single Match
        if ($Results.Count -eq 1) {
            return $Results[0]
        }

        # Scenario B: Multiple Matches Found
        Write-Host "`nMultiple users found matching '$Query':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Results.Count; $i++) {
            Write-Host ("{0}. {1} ({2})" -f ($i + 1), $Results[$i].DisplayName, $Results[$i].UserPrincipalName)
        }
        Write-Host "0. Cancel and search again"

        $Selection = Read-Host "`nSelect user number"
        if ($Selection -eq "0" -or [string]::IsNullOrWhiteSpace($Selection)) {
            continue
        }

        if ($Selection -match '^\d+$') {
            $Index = [int]$Selection
            if ($Index -le $Results.Count -and $Index -gt 0) {
                return $Results[$Index - 1]
            }
        }
        
        Write-Host "Invalid entry." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}