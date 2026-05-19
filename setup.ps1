# setup.ps1
# Interaktives Setup - erstellt config.local.ps1
# Letzte Eingaben werden als Default vorgeschlagen: [letzter Wert] -> Enter = uebernehmen
# PS 5.1 kompatibel

param([switch]$Force)

$configFile = Join-Path $PSScriptRoot 'config.local.ps1'

# Letzte Werte laden falls vorhanden
$prev = [pscustomobject]@{
    NasShare    = ''
    NasTarget   = ''
    DriveLetter = 'Z'
    LocalTemp   = 'C:\Temp'
    LocalOutput = ''
    GitHubUser  = ''
    RepoName    = 'windows-disk-transition-toolkit'
    RepoBase    = 'C:\Tools'
}
if (Test-Path $configFile) {
    if (-not $Force) {
        Write-Host '[INFO] config.local.ps1 gefunden - Werte werden als Vorschlag verwendet.' -ForegroundColor Cyan
        Write-Host '       -Force zum kompletten Neustart ohne Vorschlaege.' -ForegroundColor Gray
        Write-Host ''
    }
    try { . $configFile } catch {}
    if ($Config) {
        foreach ($p in $prev.PSObject.Properties.Name) {
            if ($Config.PSObject.Properties[$p]) {
                $prev.$p = $Config.$p
            }
        }
    }
}

# Helper: Read-Host mit Default-Wert in eckigen Klammern
function Read-Default {
    param([string]$Prompt, [string]$Default = '')
    $display = if ($Default -ne '') { "$Prompt [$Default]" } else { $Prompt }
    $val = Read-Host $display
    if ($val -eq '') { $Default } else { $val }
}

Write-Host ''
Write-Host '=== Setup: Windows Disk Transition Toolkit ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Ausgabeziel: NAS (UNC) ODER lokaler Pfad (z.B. C:\Temp oder G:\USB-STICK\TEMP)' -ForegroundColor Yellow
Write-Host 'Wird LocalOutput angegeben, wird NAS komplett uebersprungen.' -ForegroundColor Gray
Write-Host 'Enter = letzten Wert uebernehmen.' -ForegroundColor Gray
Write-Host ''

$nasShare = Read-Default 'NAS share root (z.B. \\nas\Software) - leer = lokal' $prev.NasShare

$nasTarget   = $prev.NasTarget
$driveLetter = $prev.DriveLetter
if ($nasShare -ne '') {
    $nasTarget   = Read-Default 'NAS subfolder fuer Reports (z.B. ISOs\Windows10HpPro)' $prev.NasTarget
    $driveLetter = Read-Default 'Laufwerksbuchstabe fuer NAS' $prev.DriveLetter
}

$localOutput = Read-Default 'Lokaler Ausgabepfad (z.B. C:\Temp oder G:\USB-STICK\TEMP) - leer = NAS' $prev.LocalOutput
$localTemp   = Read-Default 'Lokaler Temp-Ordner fuer Zwischendateien' $prev.LocalTemp

if ($nasShare -eq '' -and $localOutput -eq '') {
    $localOutput = $localTemp
    Write-Host "[INFO] Kein NAS und kein LocalOutput - verwende LocalTemp: $localOutput" -ForegroundColor Yellow
}

$githubUser = Read-Default 'GitHub username' $prev.GitHubUser
$repoName   = Read-Default 'GitHub repo name' $prev.RepoName
$repoBase   = Read-Default 'Lokale Basis fuer geklonte Repos' $prev.RepoBase

# Werte als Literale schreiben - KEIN Here-String wegen Backslash-Escaping
# Jede Zeile einzeln zusammenbauen damit PS keine Backslashes verdoppelt
$lines = @(
    '# config.local.ps1 - automatisch generiert von setup.ps1'
    '# NICHT einchecken (.gitignore)'
    ''
    '$Config = [pscustomobject]@{'
    ('    NasShare    = ' + "'$nasShare'")
    ('    NasTarget   = ' + "'$nasTarget'")
    ('    DriveLetter = ' + "'$driveLetter'")
    ('    LocalTemp   = ' + "'$localTemp'")
    ('    LocalOutput = ' + "'$localOutput'")
    ('    GitHubUser  = ' + "'$githubUser'")
    ('    RepoName    = ' + "'$repoName'")
    ('    RepoBase    = ' + "'$repoBase'")
    '}'
)
$lines | Set-Content -Path $configFile -Encoding UTF8

Write-Host ''
Write-Host "config.local.ps1 geschrieben: $configFile" -ForegroundColor Green

foreach ($path in @($localTemp, $localOutput) | Where-Object { $_ -ne '' } | Select-Object -Unique) {
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    Write-Host "Ordner sichergestellt: $path" -ForegroundColor Green
}
Write-Host ''
