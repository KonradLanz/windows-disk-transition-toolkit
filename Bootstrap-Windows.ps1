# Bootstrap-Windows.ps1
# Thin Wrapper - delegiert an bootstrap-foundation
# Projektspezifisch: NAS mounten + windows-disk-transition-toolkit klonen
# PS 5.1 kompatibel
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
Write-Host '  windows-disk-transition-toolkit Bootstrap'     -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

# 1) bootstrap-foundation delegieren (git, winget, ExecutionPolicy-Foundation)
Write-Host '[1/3] bootstrap-foundation laden...' -ForegroundColor Yellow
$bfUrl = 'https://raw.githubusercontent.com/KonradLanz/bootstrap-foundation/main/windows/bootstrap.ps1'
try {
    & ([scriptblock]::Create((New-Object Net.WebClient).DownloadString($bfUrl))) -GitHubUser $GitHubUser
} catch {
    Write-Host "      [FEHLER] bootstrap-foundation nicht erreichbar: $_" -ForegroundColor Red
    exit 1
}

# 2) Dieses Repo klonen / aktualisieren
Write-Host '[2/3] windows-disk-transition-toolkit klonen...' -ForegroundColor Yellow
$dir = Join-Path $repoBase 'windows-disk-transition-toolkit'
if (-not (Test-Path $dir)) {
    git clone "https://github.com/$GitHubUser/windows-disk-transition-toolkit.git" $dir
} else {
    Push-Location $dir; git pull; Pop-Location
}
Write-Host '      OK' -ForegroundColor Green

# 3) NAS (projektspezifisch, optional)
Write-Host '[3/3] NAS verbinden...' -ForegroundColor Yellow
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
