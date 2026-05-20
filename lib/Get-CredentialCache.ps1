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

# Fuehrt net use aus ohne NativeCommandError bei Fehler zu werfen.
function Invoke-NetUse {
    param([string[]]$Args)
    # Lokales EAP=Continue verhindert dass stderr-Output von net.exe als
    # terminating error behandelt wird (Start.ps1 setzt EAP=Stop global).
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $result = & net $Args 2>&1
    $ec = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return [pscustomobject]@{ ExitCode = $ec; Output = $result }
}

# Trennt ein Netzlaufwerk still - kein Fehler wenn nicht verbunden.
function Disconnect-Nas {
    param([string]$Drive)
    Invoke-NetUse 'use', "${Drive}:", '/delete', '/yes' | Out-Null
    if (Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $Drive -Force -ErrorAction SilentlyContinue
    }
}

# Verbindet ein NAS-Laufwerk mit automatischem Retry bei falschem Kennwort.
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

        Disconnect-Nas -Drive $Drive

        $user     = $cred.UserName
        $password = $cred.GetNetworkCredential().Password

        $r = Invoke-NetUse 'use', "${Drive}:", $ShareRoot, $password, "/user:$user", '/persistent:no'
        if ($r.ExitCode -eq 0) {
            Write-Host "[NAS] Laufwerk $Drive`: verbunden." -ForegroundColor Green
            return $true
        }

        $msg = ($r.Output | Out-String).Trim()
        Write-Host "[NAS] Fehler (Versuch $attempt/$MaxAttempts): $msg" -ForegroundColor Red
        Clear-CredentialCache -CacheKey $CacheKey
        if ($attempt -ge $MaxAttempts) {
            Write-Host '[NAS] Maximale Versuche erreicht. Vorgang abgebrochen.' -ForegroundColor Red
            return $false
        }
    }
    return $false
}
