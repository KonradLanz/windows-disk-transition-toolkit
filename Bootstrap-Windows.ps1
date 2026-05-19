# Bootstrap-Windows.ps1
# Generisches Windows-Bootstrap - laeuft auf jedem Windows-Rechner (PS 5.1+)
# Kein git noetig zum Starten - wird bei Bedarf automatisch installiert.
#
# STARTEN (PowerShell als Administrator):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-Windows.ps1'))
#
# MIT NAS:
#   $s = 'https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-Windows.ps1'
#   & ([scriptblock]::Create((New-Object Net.WebClient).DownloadString($s))) -NasShare '\\<nas-hostname>\Software'

param(
    [string]$NasShare    = '',
    [string]$DriveLetter = 'Z',
    [string]$GitHubUser  = 'KonradLanz'
)

$ErrorActionPreference = 'Continue'
$repoBase = Join-Path $env:USERPROFILE 'github'

Write-Host ''
Write-Host '================================================' -ForegroundColor Cyan
Write-Host '  Windows Bootstrap - windows-disk-transition'   -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

# 1) PS Version
Write-Host "[1/5] PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Green

# 2) winget
Write-Host '[2/5] Pruefe winget...' -ForegroundColor Yellow
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host '      winget nicht gefunden!' -ForegroundColor Red
    Write-Host '      -> https://aka.ms/getwinget installieren, dann neu starten.' -ForegroundColor Red
    exit 1
}
Write-Host '      winget OK' -ForegroundColor Green

# 3) git
Write-Host '[3/5] Pruefe git...' -ForegroundColor Yellow
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '      git nicht gefunden - wird automatisch installiert (~62 MB)...' -ForegroundColor Yellow
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host ''
        Write-Host '      git installiert!' -ForegroundColor Green
        Write-Host '  >>> PowerShell schliessen, neu oeffnen (als Admin) und Script nochmal starten.' -ForegroundColor Yellow
        Write-Host '  >>>   iex ((New-Object Net.WebClient).DownloadString(''https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-Windows.ps1''))' -ForegroundColor Cyan
        Read-Host 'Enter druecken zum Beenden'
        exit 0
    }
}
Write-Host '      git OK' -ForegroundColor Green

# 4) Repos klonen / aktualisieren
Write-Host '[4/5] Repos klonen / aktualisieren...' -ForegroundColor Yellow
New-Item -Path $repoBase -ItemType Directory -Force | Out-Null

foreach ($repo in @('ExecutionPolicy-Foundation', 'windows-disk-transition-toolkit')) {
    $dir = Join-Path $repoBase $repo
    if (-not (Test-Path $dir)) {
        Write-Host "      Klone $repo..." -ForegroundColor Yellow
        git clone "https://github.com/${GitHubUser}/${repo}.git" $dir
    } else {
        Write-Host "      Aktualisiere $repo..." -ForegroundColor Cyan
        Push-Location $dir; git pull; Pop-Location
    }
}
Write-Host '      Repos OK' -ForegroundColor Green

# 5) NAS (optional)
Write-Host '[5/5] NAS verbinden...' -ForegroundColor Yellow
if ($NasShare -ne '') {
    $cred = Get-Credential -Message "NAS Zugangsdaten fuer $NasShare"
    try { Remove-PSDrive -Name $DriveLetter -Force -ErrorAction SilentlyContinue } catch {}
    try {
        New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $NasShare `
            -Credential $cred -Scope Global -ErrorAction Stop | Out-Null
        Write-Host "      NAS gemountet als ${DriveLetter}: -> $NasShare" -ForegroundColor Green
    } catch {
        Write-Host "      [FEHLER] NAS konnte nicht gemountet werden: $_" -ForegroundColor Red
        Write-Host '      Benutzername/Passwort pruefen.' -ForegroundColor Gray
    }
} else {
    Write-Host '      Kein NAS angegeben - uebersprungen.' -ForegroundColor Gray
}

Write-Host ''
Write-Host '================================================' -ForegroundColor Green
Write-Host '  Bootstrap abgeschlossen!' -ForegroundColor Green
Write-Host "  Repos: $repoBase" -ForegroundColor Green
Write-Host '================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Weiter mit:' -ForegroundColor Cyan
Write-Host "  cd '$repoBase\windows-disk-transition-toolkit'" -ForegroundColor Cyan
Write-Host "  .\Start.ps1" -ForegroundColor Cyan
Write-Host ''
