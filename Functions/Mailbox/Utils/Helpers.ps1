function Wait-Console {
    param([string]$Message = "Press Enter to continue...")
    Read-Host "`n$Message"
}

function Write-ToggleStatus {
    param(
        [bool]$State,
        [string]$TrueLabel = "ENABLED",
        [string]$FalseLabel = "DISABLED"
    )
    if ($State) { 
        Write-Host "[$TrueLabel]" -ForegroundColor Green 
    } else { 
        Write-Host "[$FalseLabel]" -ForegroundColor Red 
    }
}

function Get-RawBytes {
    param($ByteField)
    if ($null -eq $ByteField) { return 0 }
    
    $StrValue = $ByteField.ToString().Trim()
    if ($StrValue -ieq "Unlimited") {
        return [double]::PositiveInfinity
    }
    
    # Safely extracts pure digits from complex Exchange strings like "45.12 GB (48,449,112,010 bytes)"
    if ($StrValue -match '\(([\d,]+)\s+bytes\)') {
        return [double]($matches[1] -replace ',','')
    }
    if ($StrValue -match '^\d+$') { 
        return [double]$StrValue 
    }
    return 0
}

function Format-StorageSizeMB {
    param([double]$Bytes)
    if ([double]::IsPositiveInfinity($Bytes)) {
        return "Unlimited"
    }
    return [math]::Round($Bytes / 1MB, 2)
}

function Format-StorageSizeGB {
    param([double]$Bytes)
    if ([double]::IsPositiveInfinity($Bytes)) {
        return "Unlimited"
    }
    return [math]::Round($Bytes / 1GB, 2)
}

function Get-CalendarFolderPath {
    param([string]$UserPrincipalName)
    try {
        # Check folder statistics to resolve regional calendar names (e.g. Kalender, Calendrier)
        $CalFolder = Get-MailboxFolderStatistics -Identity $UserPrincipalName -FolderScope Calendar -ErrorAction Stop |
            Select-Object -First 1
        if ($CalFolder -and $CalFolder.FolderPath) {
            $CleanPath = $CalFolder.FolderPath.TrimStart('/') -replace '/', '\'
            return "$($UserPrincipalName):\$CleanPath"
        }
    }
    catch {
        # Fallback to standard default
    }
    return "$($UserPrincipalName):\Calendar"
}
