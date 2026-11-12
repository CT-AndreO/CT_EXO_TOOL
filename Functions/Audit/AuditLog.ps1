function Invoke-AuditLogMenu {
    if ($Global:TenantName -eq "Disconnected") {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Red
        Write-Host "                         NO ACTIVE CONNECTION                        " -ForegroundColor Red
        Write-Host "=====================================================================" -ForegroundColor Red
        Write-Host "You must authenticate to Exchange Online before searching audit logs." -ForegroundColor Yellow
        Wait-Console "Press Enter to return..."
        return
    }

    $AuditMenuRunning = $true
    while ($AuditMenuRunning) {
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "              EXCHANGE ONLINE UNIFIED AUDIT LOG AUDITOR              " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Tenant: $Global:TenantName" -ForegroundColor White
        Write-Host "---------------------------------------------------------------------"
        Write-Host " 1. Audit Events from Today"
        Write-Host " 2. Audit Events from Last 24 Hours"
        Write-Host " 3. Audit Events from Last 7 Days"
        Write-Host " 4. Audit Events on a Specific Date (Single Day)"
        Write-Host " 5. Audit Events within a Custom Date Range"
        Write-Host " 0. Return to Main Menu"
        Write-Host "---------------------------------------------------------------------"

        $Choice = (Read-Host "Selection").Trim()

        $Now = Get-Date
        $StartDate = $null
        $EndDate = $null

        switch ($Choice) {
            "1" {
                $StartDate = $Now.Date
                $EndDate = $Now
            }
            "2" {
                $StartDate = $Now.AddHours(-24)
                $EndDate = $Now
            }
            "3" {
                $StartDate = $Now.AddDays(-7)
                $EndDate = $Now
            }
            "4" {
                $DateInput = Read-ValidDate -Prompt "Enter audit date (YYYY-MM-DD)"
                if ($null -eq $DateInput) { continue }
                $StartDate = $DateInput.Date
                $EndDate = $DateInput.Date.AddDays(1).AddSeconds(-1)
                if ($EndDate -gt $Now) { $EndDate = $Now }
            }
            "5" {
                $StartInput = Read-ValidDate -Prompt "Enter Start Date (YYYY-MM-DD)"
                if ($null -eq $StartInput) { continue }
                $EndInput = Read-ValidDate -Prompt "Enter End Date (YYYY-MM-DD)"
                if ($null -eq $EndInput) { continue }

                $StartDate = $StartInput.Date
                $EndDate = $EndInput.Date.AddDays(1).AddSeconds(-1)

                if ($StartDate -gt $EndDate) {
                    Write-Host "`n[ERROR] Start Date cannot be later than End Date." -ForegroundColor Red
                    Start-Sleep -Seconds 1.5
                    continue
                }
                if ($EndDate -gt $Now) {
                    $EndDate = $Now
                }
            }
            "0" {
                $AuditMenuRunning = $false
                continue
            }
            Default {
                Write-Host "Invalid selection. Please choose 0 to 5." -ForegroundColor Red
                Start-Sleep -Seconds 1
                continue
            }
        }

        # Optional filters
        Clear-Host
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "                     AUDIT LOG FILTER OPTIONS                        " -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host " Time Window: $($StartDate.ToString('yyyy-MM-dd HH:mm:ss')) to $($EndDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
        Write-Host "---------------------------------------------------------------------"
        Write-Host "Optional Filters (Press Enter to skip):" -ForegroundColor Gray
        $UserFilter = (Read-Host " Filter by User / UPN (e.g. admin@domain.com)").Trim()
        $OpFilter   = (Read-Host " Filter by Operation (e.g. MailItemsAccessed, SendAs, Set-Mailbox)").Trim()
        $RecordType = (Read-Host " Filter by RecordType (e.g. ExchangeItem, ExchangeAdmin, or leave blank for all)").Trim()

        Execute-AuditLogQuery -StartDate $StartDate -EndDate $EndDate -UserFilter $UserFilter -OpFilter $OpFilter -RecordType $RecordType
    }
}

function Read-ValidDate {
    param([string]$Prompt)

    while ($true) {
        Write-Host "`n$Prompt (or '0' to cancel):" -ForegroundColor Gray
        $RawInput = (Read-Host "Date").Trim()

        if ($RawInput -eq "0" -or [string]::IsNullOrWhiteSpace($RawInput)) {
            return $null
        }

        $ParsedDate = [DateTime]::MinValue
        $Formats = @("yyyy-MM-dd", "yyyy/MM/dd", "dd-MM-yyyy", "dd/MM/yyyy")
        $Valid = [DateTime]::TryParseExact($RawInput, $Formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$ParsedDate)
        
        if (-not $Valid) {
            $Valid = [DateTime]::TryParse($RawInput, [ref]$ParsedDate)
        }

        if ($Valid) {
            if ($ParsedDate -gt (Get-Date)) {
                Write-Host "[ERROR] Date cannot be in the future." -ForegroundColor Red
                continue
            }
            return $ParsedDate
        }

        Write-Host "[ERROR] Invalid date format. Please use YYYY-MM-DD (e.g. 2026-11-12)." -ForegroundColor Red
    }
}

function Execute-AuditLogQuery {
    param(
        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [string]$UserFilter,
        [string]$OpFilter,
        [string]$RecordType
    )

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                   QUERYING UNIFIED AUDIT LOG                        " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Start Time:   $($StartDate.ToString('yyyy-MM-dd HH:mm:ss')) (Local)" -ForegroundColor Gray
    Write-Host " End Time:     $($EndDate.ToString('yyyy-MM-dd HH:mm:ss')) (Local)" -ForegroundColor Gray
    if (-not [string]::IsNullOrWhiteSpace($UserFilter)) { Write-Host " User Filter:  $UserFilter" -ForegroundColor Gray }
    if (-not [string]::IsNullOrWhiteSpace($OpFilter))   { Write-Host " Operation:    $OpFilter" -ForegroundColor Gray }
    if (-not [string]::IsNullOrWhiteSpace($RecordType)) { Write-Host " RecordType:   $RecordType" -ForegroundColor Gray }
    Write-Host "---------------------------------------------------------------------"
    Write-Host "Submitting search request to Microsoft Purview / Exchange Online..." -ForegroundColor DarkGray

    $QueryParams = @{
        StartDate  = $StartDate
        EndDate    = $EndDate
        ResultSize = 5000
        ErrorAction = "Stop"
    }

    if (-not [string]::IsNullOrWhiteSpace($UserFilter)) { $QueryParams["UserIds"] = $UserFilter }
    if (-not [string]::IsNullOrWhiteSpace($OpFilter))   { $QueryParams["Operations"] = $OpFilter }
    if (-not [string]::IsNullOrWhiteSpace($RecordType)) { $QueryParams["RecordType"] = $RecordType }

    try {
        $RawEvents = @(Search-UnifiedAuditLog @QueryParams)
    }
    catch {
        Write-Host "`n[AUDIT LOG ERROR] Failed to query Unified Audit Log." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nEnsure your account has the 'View-Only Audit Logs' or 'Audit Logs' role" -ForegroundColor Yellow
        Write-Host "and that Unified Auditing is enabled in your Microsoft 365 tenant." -ForegroundColor Yellow
        Wait-Console
        return
    }

    if ($RawEvents.Count -eq 0) {
        Write-Host "`n[RESULT] No audit events found matching the specified timeframe and criteria." -ForegroundColor Yellow
        Wait-Console
        return
    }

    # Transform events into display-friendly objects
    $EventsList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $Idx = 1
    foreach ($evt in $RawEvents) {
        $EventsList.Add([PSCustomObject]@{
            Index        = $Idx
            CreationDate = $evt.CreationDate
            UserIds      = if ($evt.UserIds) { $evt.UserIds } else { "N/A" }
            Operations   = $evt.Operations
            RecordType   = $evt.RecordType
            ResultStatus = if ($evt.ResultStatus) { $evt.ResultStatus } else { "Success" }
            AuditData    = $evt.AuditData
        })
        $Idx++
    }

    # Paginated Display Viewer
    Show-AuditLogViewer -AuditRecords $EventsList -StartDate $StartDate -EndDate $EndDate
}

function Show-AuditLogViewer {
    param(
        [System.Collections.Generic.List[PSCustomObject]]$AuditRecords,
        [DateTime]$StartDate,
        [DateTime]$EndDate
    )

    $PageSize = 15
    $CurrentPage = 1
    $TotalPages = [math]::Max(1, [math]::Ceiling($AuditRecords.Count / $PageSize))

    $Viewing = $true
    while ($Viewing) {
        Clear-Host
        $StartIndex = ($CurrentPage - 1) * $PageSize
        $PageItems = @($AuditRecords | Select-Object -Skip $StartIndex -First $PageSize)

        Write-Host "=========================================================================================================" -ForegroundColor Cyan
        Write-Host "                                   UNIFIED AUDIT LOG RESULTS                                             " -ForegroundColor Cyan
        Write-Host "=========================================================================================================" -ForegroundColor Cyan
        Write-Host (" Total Events: {0} | Page: {1} of {2} | Window: {3} to {4}" -f $AuditRecords.Count, $CurrentPage, $TotalPages, $StartDate.ToString("yyyy-MM-dd"), $EndDate.ToString("yyyy-MM-dd")) -ForegroundColor Yellow
        Write-Host "=========================================================================================================" -ForegroundColor Gray

        $FormatStr = "{0,-4} {1,-20} {2,-30} {3,-25} {4,-18}"
        Write-Host ($FormatStr -f "#", "TIMESTAMP", "USER / IDENTITY", "OPERATION", "RECORD TYPE") -ForegroundColor White
        Write-Host "---------------------------------------------------------------------------------------------------------" -ForegroundColor Gray

        foreach ($item in $PageItems) {
            $DateStr = if ($item.CreationDate) { $item.CreationDate.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
            $UserStr = if ($item.UserIds.Length -gt 28) { $item.UserIds.Substring(0, 25) + "..." } else { $item.UserIds }
            $OpStr   = if ($item.Operations.Length -gt 23) { $item.Operations.Substring(0, 20) + "..." } else { $item.Operations }
            Write-Host ($FormatStr -f $item.Index, $DateStr, $UserStr, $OpStr, $item.RecordType) -ForegroundColor Green
        }

        Write-Host "=========================================================================================================" -ForegroundColor Gray
        Write-Host " COMMANDS:" -ForegroundColor Yellow
        Write-Host "  [N] Next Page  | [P] Previous Page  | [E] Export All to CSV" -ForegroundColor Gray
        Write-Host "  [#] View Record Detail JSON (e.g. enter record index number)" -ForegroundColor Gray
        Write-Host "  [0] Return to Audit Menu" -ForegroundColor DarkGray
        Write-Host "=========================================================================================================" -ForegroundColor Gray

        $Cmd = (Read-Host "Command").Trim()

        switch -Regex ($Cmd) {
            "^0$" { $Viewing = $false }
            "(?i)^N$" {
                if ($CurrentPage -lt $TotalPages) { $CurrentPage++ }
                else { Write-Host "Already on the last page." -ForegroundColor Yellow; Start-Sleep -Milliseconds 600 }
            }
            "(?i)^P$" {
                if ($CurrentPage -gt 1) { $CurrentPage-- }
                else { Write-Host "Already on the first page." -ForegroundColor Yellow; Start-Sleep -Milliseconds 600 }
            }
            "(?i)^E$" {
                Export-AuditRecordsToCsv -Records $AuditRecords
            }
            "^\d+$" {
                $RecordId = [int]$Cmd
                $Matched = $AuditRecords | Where-Object { $_.Index -eq $RecordId }
                if ($Matched) {
                    Show-AuditRecordDetails -Record $Matched
                } else {
                    Write-Host "Invalid record number." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
            Default {
                Write-Host "Invalid command." -ForegroundColor Red
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

function Show-AuditRecordDetails {
    param([PSCustomObject]$Record)

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                       AUDIT RECORD DETAILS                          " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Index:       $($Record.Index)" -ForegroundColor White
    Write-Host " Timestamp:   $($Record.CreationDate)" -ForegroundColor White
    Write-Host " User:        $($Record.UserIds)" -ForegroundColor Yellow
    Write-Host " Operation:   $($Record.Operations)" -ForegroundColor Yellow
    Write-Host " RecordType:  $($Record.RecordType)" -ForegroundColor Gray
    Write-Host " Status:      $($Record.ResultStatus)" -ForegroundColor Gray
    Write-Host "---------------------------------------------------------------------"
    Write-Host " Extended Payload (AuditData):" -ForegroundColor Cyan

    if (-not [string]::IsNullOrWhiteSpace($Record.AuditData)) {
        try {
            $JsonObj = $Record.AuditData | ConvertFrom-Json
            $JsonObj | Format-List | Out-String | Write-Host -ForegroundColor DarkCyan
        }
        catch {
            Write-Host $Record.AuditData -ForegroundColor DarkGray
        }
    } else {
        Write-Host "[No extended AuditData payload present]" -ForegroundColor DarkGray
    }

    Write-Host "=====================================================================" -ForegroundColor Cyan
    Wait-Console "Press Enter to return to audit log viewer..."
}

function Export-AuditRecordsToCsv {
    param([System.Collections.Generic.List[PSCustomObject]]$Records)

    Clear-Host
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "                  EXPORT AUDIT LOG RESULTS TO CSV                    " -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Total Records to export: $($Records.Count)" -ForegroundColor Gray
    
    $TargetDir = (Read-Host "`nEnter export directory (leave empty for current directory, or '0' to cancel)").Trim()
    if ($TargetDir -eq "0") { return }
    if ([string]::IsNullOrWhiteSpace($TargetDir)) { $TargetDir = "." }

    if (-not (Test-Path -Path $TargetDir)) {
        try { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
        catch { $TargetDir = "." }
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $FilePath = Join-Path $TargetDir "EXO_AuditLog_$Timestamp.csv"

    Write-Host "Writing audit records to CSV..." -ForegroundColor Gray
    try {
        $Records | Select-Object Index, CreationDate, UserIds, Operations, RecordType, ResultStatus, AuditData |
            Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        Write-Host "`n[SUCCESS] Audit records exported successfully:" -ForegroundColor Green
        Write-Host " -> $FilePath" -ForegroundColor Cyan
    }
    catch {
        Write-Host "`n[ERROR] Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-Console
}
