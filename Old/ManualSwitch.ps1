# --- CONFIGURATION ---
$UserList = @(
    "amanda@fhbc.co.za",
    "hendrik@fhbc.co.za",
    "joanne@fhbc.co.za",
    "louise@fhbc.co.za",
    "yolande@fhbc.co.za",
    "reinet@fhbc.co.za",
    "chalene@fhbc.co.za",
    "lorraine@fhbc.co.za",
    "morne@fhbc.co.za"

)
    
# --- INITIAL CONNECTION ---
Clear-Host
Write-Host "Verifying Exchange Online Session..." -ForegroundColor Gray
try {
    $null = Get-OrganizationConfig -ErrorAction Stop
    Write-Host "Connected successfully." -ForegroundColor Green
} catch {
    Write-Host "Not connected. Initiating connection..." -ForegroundColor Cyan
    Connect-ExchangeOnline
}

Write-Host "`n=== ENABLING AUTO-EXPANDING ARCHIVE ===" -ForegroundColor Cyan
Write-Host "Processing $($UserList.Count) mailboxes...`n" -ForegroundColor Gray

# --- PROCESSING LOOP ---
foreach ($Email in $UserList) {
    Write-Host "Processing: $Email ... " -NoNewline -ForegroundColor Yellow
    try {
        # Check current status first to save API execution overhead or avoid unnecessary errors
        $Mbx = Get-Mailbox -Identity $Email -ErrorAction Stop
        
        if ($Mbx.AutoExpandingArchiveEnabled) {
            Write-Host "Already Enabled." -ForegroundColor Green
        } else {
            Enable-Mailbox -Identity $Email -AutoExpandingArchive -ErrorAction Stop
            Write-Host "Success!" -ForegroundColor Green
        }
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

Write-Host "`nTask Complete. Note that Microsoft background processes can take several days to provision the extra storage." -ForegroundColor Gray