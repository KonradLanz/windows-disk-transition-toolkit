# setup.ps1
# Interaktives Setup - erstellt config.local.ps1
# PS 5.1 kompatibel

param([switch]$Force)

$configFile = Join-Path $PSScriptRoot 'config.local.ps1'
if ((Test-Path $configFile) -and -not $Force) {
    Write-Host '[INFO] config.local.ps1 bereits vorhanden. -Force zum Ueberschreiben.' -ForegroundColor Cyan
    return
}

Write-Host ''
Write-Host '=== Setup: Windows Disk Transition Toolkit ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Ausgabeziel: entweder NAS (UNC-Pfad) ODER lokaler Pfad (z.B. C:\Temp oder G:\USB-STICK\TEMP)' -ForegroundColor Yellow
Write-Host 'Wird LocalOutput angegeben, wird NAS komplett uebersprungen.' -ForegroundColor Gray
Write-Host ''

$nasShare   = Read-Host 'NAS share root (z.B. \\\\nas\\Software) - leer lassen wenn lokal'
$nasTarget  = ''
$driveLetter = 'Z'
if ($nasShare -ne '') {
    $nasTarget   = Read-Host 'NAS subfolder fuer Reports (z.B. ISOs\Windows10HpPro)'
    $driveLetter = Read-Host 'Laufwerksbuchstabe fuer NAS (Standard Z)'
    if ($driveLetter -eq '') { $driveLetter = 'Z' }
}

$localOutput = Read-Host 'Lokaler Ausgabepfad (z.B. C:\Temp oder G:\USB-STICK\TEMP) - leer = NAS nutzen'
$localTemp   = Read-Host 'Lokaler Temp-Ordner fuer Zwischendateien (Standard C:\Temp)'
if ($localTemp -eq '') { $localTemp = 'C:\Temp' }

# Wenn weder NAS noch LocalOutput gesetzt: auf LocalTemp fallbacken
if ($nasShare -eq '' -and $localOutput -eq '') {
    $localOutput = $localTemp
    Write-Host "[INFO] Kein NAS und kein LocalOutput - verwende LocalTemp: $localOutput" -ForegroundColor Yellow
}

$githubUser = Read-Host 'GitHub username'
$repoName   = Read-Host 'GitHub repo name (Standard windows-disk-transition-toolkit)'
if ($repoName -eq '') { $repoName = 'windows-disk-transition-toolkit' }
$repoBase   = Read-Host 'Lokale Basis fuer geklonte Repos (Standard C:\Tools)'
if ($repoBase -eq '') { $repoBase = 'C:\Tools' }

$content = @"
# config.local.ps1 - automatisch generiert von setup.ps1
# NICHT einchecken (in .gitignore)

`$Config = [pscustomobject]@{
    NasShare    = '$nasShare'
    NasTarget   = '$nasTarget'
    DriveLetter = '$driveLetter'
    LocalTemp   = '$localTemp'
    LocalOutput = '$localOutput'
    GitHubUser  = '$githubUser'
    RepoName    = '$repoName'
    RepoBase    = '$repoBase'
}
"@

$content | Set-Content -Path $configFile -Encoding UTF8
Write-Host ''
Write-Host "config.local.ps1 geschrieben: $configFile" -ForegroundColor Green

if ($localTemp -ne '') {
    New-Item -Path $localTemp -ItemType Directory -Force | Out-Null
    Write-Host "Lokaler Temp-Ordner: $localTemp" -ForegroundColor Green
}
if ($localOutput -ne '' -and $localOutput -ne $localTemp) {
    New-Item -Path $localOutput -ItemType Directory -Force | Out-Null
    Write-Host "Lokaler Ausgabe-Ordner: $localOutput" -ForegroundColor Green
}
Write-Host ''
