function Wait-Console {
    Read-Host "`nPress Enter to continue..."
}

function Write-ToggleStatus {
    param([bool]$State)
    if ($State) { 
        Write-Host "ENABLED" -ForegroundColor Green 
    } else { 
        Write-Host "DISABLED" -ForegroundColor Red 
    }
}

function Get-RawBytes {
    param($ByteField)
    if ($null -eq $ByteField) { return 0 }
    
    # Safely extracts pure digits from complex Exchange strings like "45.12 GB (48,449,112,010 bytes)"
    if ($ByteField.ToString() -match '\(([\d,]+)\s+bytes\)') {
        return [long]($matches[1] -replace ',','')
    }
    if ($ByteField -match '^\d+$') { return [long]$ByteField }
    return 0
}