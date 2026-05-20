function Get-CredentialCache {
    param(
        [string]$CacheKey = 'nas',
        [string]$Message  = 'Bitte Zugangsdaten eingeben'
    )
    $cacheDir = Join-Path $env:APPDATA 'WDT-Bootstrap'
    $credFile = Join-Path $cacheDir "$CacheKey.xml"
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
    if (-not $cred) { return $null }
    $cred | Export-Clixml $credFile
    Write-Host "[$CacheKey] Credentials gecacht." -ForegroundColor Green
    return $cred
}

function Clear-CredentialCache {
    param([string]$CacheKey = 'nas')
    $cacheDir = Join-Path $env:APPDATA 'WDT-Bootstrap'
    $credFile = Join-Path $cacheDir "$CacheKey.xml"
    if (Test-Path $credFile) {
        Remove-Item $credFile -Force
        Write-Host "[$CacheKey] Cache geloescht." -ForegroundColor Yellow
    }
}

# Trennt ein Netzlaufwerk still - kein Fehler wenn nicht verbunden.
function Disconnect-Nas {
    param([string]$Drive)
    # cmd /c schluckt NativeCommandError wenn das Laufwerk nicht existiert
    cmd /c "net use ${Drive}: /delete /yes" 2>$null | Out-Null
    if (Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $Drive -Force -ErrorAction SilentlyContinue
    }
}

# Verbindet ein NAS-Laufwerk mit automatischem Retry bei falschem Kennwort.
# Verwendet 'net use' statt New-PSDrive damit das Laufwerk Windows-weit sichtbar
# ist und Join-Path / dir z: sofort funktionieren.
# Gibt $true zurueck wenn erfolgreich, $false wenn User abbricht.
function Connect-NasWithRetry {
    param(
        [string]$Drive,
        [string]$ShareRoot,
        [string]$CacheKey  = 'nas',
        [int]$MaxAttempts  = 3
    )
    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        $cred = Get-CredentialCache -CacheKey $CacheKey -Message "NAS-Zugangsdaten fuer $ShareRoot"
        if (-not $cred) {
            Write-Host '[NAS] Abgebrochen.' -ForegroundColor Yellow
            return $false
        }

        # Vorhandene Verbindung still trennen
        Disconnect-Nas -Drive $Drive

        $user     = $cred.UserName
        $password = $cred.GetNetworkCredential().Password

        # cmd /c verhindert PS NativeCommandError bei Fehler
        $result = cmd /c "net use ${Drive}: `"$ShareRoot`" `"$password`" /user:`"$user`" /persistent:no" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[NAS] Laufwerk $Drive`: verbunden." -ForegroundColor Green
            return $true
        }

        $msg = ($result | Out-String).Trim()
        Write-Host "[NAS] Fehler (Versuch $attempt/$MaxAttempts): $msg" -ForegroundColor Red
        Clear-CredentialCache -CacheKey $CacheKey
        if ($attempt -ge $MaxAttempts) {
            Write-Host '[NAS] Maximale Versuche erreicht. Vorgang abgebrochen.' -ForegroundColor Red
            return $false
        }
    }
    return $false
}
