function Get-CredentialCache {
    param(
        [string]$CacheKey = "nas",
        [string]$Message  = "Bitte Zugangsdaten eingeben"
    )
    $cacheDir  = Join-Path $env:APPDATA "WDT-Bootstrap"
    $credFile  = Join-Path $cacheDir "$CacheKey.xml"
    New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null

    if (Test-Path $credFile) {
        try {
            $cred = Import-Clixml $credFile
            Write-Host "[$CacheKey] Credentials aus Cache geladen." -ForegroundColor Cyan
            return $cred
        } catch {
            Write-Host "[$CacheKey] Cache ungueltig, frage neu ab..." -ForegroundColor Yellow
            Remove-Item $credFile -Force
        }
    }
    $cred = Get-Credential -Message $Message
    $cred | Export-Clixml $credFile
    Write-Host "[$CacheKey] Credentials gecacht." -ForegroundColor Green
    return $cred
}

function Clear-CredentialCache {
    param([string]$CacheKey = "nas")
    $cacheDir = Join-Path $env:APPDATA "WDT-Bootstrap"
    $credFile = Join-Path $cacheDir "$CacheKey.xml"
    if (Test-Path $credFile) {
        Remove-Item $credFile -Force
        Write-Host "[$CacheKey] Cache geloescht." -ForegroundColor Yellow
    }
}
