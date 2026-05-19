# Bootstrap-HpPro.ps1
# PS 5.1 kompatibel - kein git noetig zum Starten
#
# STARTEN:
#   PowerShell als Administrator:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-HpPro.ps1'))
#
# MIT NAS:
#   $s='https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-HpPro.ps1'
#   & ([scriptblock]::Create((New-Object Net.WebClient).DownloadString($s))) -NasShare '\\nas-hostname-removed\Software'

param(
    [string]$NasShare    = '',
    [string]$DriveLetter = 'Z',
    [string]$GitHubUser  = 'KonradLanz'
)

$ErrorActionPreference = 'Continue'
$repoBase = Join-Path $env:USERPROFILE 'github'

Write-Host ''
Write-Host '================================================' -ForegroundColor Cyan
Write-Host '  HP Pro Bootstrap - windows-disk-transition'    -ForegroundColor Cyan
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
    Write-Host '      git nicht gefunden - installiere...' -ForegroundColor Yellow
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host '' 
        Write-Host '      git installiert - bitte PowerShell neu starten und Script nochmal ausfuehren.' -ForegroundColor Yellow
        exit 0
    }
}
Write-Host '      git OK' -ForegroundColor Green

# 4) Repos klonen / aktualisieren
Write-Host '[4/5] Repos klonen / aktualisieren...' -ForegroundColor Yellow
New-Item -Path $repoBase -ItemType Directory -Force | Out-Null

foreach ($repo in @('ExecutionPolicy-Foundation','windows-disk-transition-toolkit')) {
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
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $NasShare -Credential $cred -Scope Global | Out-Null
    Write-Host "      NAS gemountet als ${DriveLetter}: -> $NasShare" -ForegroundColor Green
} else {
    Write-Host '      Kein NAS angegeben - uebersprungen.' -ForegroundColor Gray
    Write-Host "      Tipp: -NasShare '\\\\nas-hostname-removed\\Software'" -ForegroundColor Gray
}

Write-Host ''
Write-Host '================================================' -ForegroundColor Green
Write-Host '  Bootstrap abgeschlossen!' -ForegroundColor Green
Write-Host "  Repos: $repoBase" -ForegroundColor Green
Write-Host '================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Naechster Schritt - Truncation-Suche:' -ForegroundColor Cyan
Write-Host "  cd '$repoBase\windows-disk-transition-toolkit'" -ForegroundColor Cyan
Write-Host "  .\tools\Search-Truncations.ps1" -ForegroundColor Cyan
Write-Host ''
