# Search-Truncations.ps1
# Durchsucht Analyse-Ordner nach abgeschnittenen Zeilen (...)
# PS 5.1 kompatibel - keine externen Abhaengigkeiten
#
# VERWENDUNG (Z: bereits gemountet):
#   .\tools\Search-Truncations.ps1
#   .\tools\Search-Truncations.ps1 -Dirs @('esata-disk1-analysis_20260519-230954','analysis_20260519-224759')
#
# VERWENDUNG (Z: noch nicht gemountet):
#   .\tools\Search-Truncations.ps1 -NasShare '\\nas.ad.own.dedyn.io\Software' -SearchBase 'ISOs\Windows10HpPro'

param(
    [string]$NasShare    = '',
    [string]$DriveLetter = 'Z',
    [string]$SearchBase  = 'ISOs\Windows10HpPro',
    [string[]]$Dirs      = @(),
    [string]$OutputCsv   = (Join-Path $env:TEMP 'truncation-report.csv')
)

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '======================================' -ForegroundColor Cyan
Write-Host '  Truncation-Suche (.txt Dateien)'    -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan
Write-Host ''

# NAS mounten falls Pfad angegeben
if ($NasShare -ne '') {
    Write-Host "NAS verbinden: $NasShare" -ForegroundColor Yellow
    $cred = Get-Credential -Message "NAS Zugangsdaten fuer $NasShare"
    try { Remove-PSDrive -Name $DriveLetter -Force -ErrorAction SilentlyContinue } catch {}
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $NasShare -Credential $cred -Scope Global | Out-Null
    Write-Host "NAS gemountet als ${DriveLetter}:" -ForegroundColor Green
} else {
    if (-not (Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue)) {
        Write-Host "[FEHLER] Laufwerk ${DriveLetter}: nicht gefunden und kein -NasShare angegeben." -ForegroundColor Red
        Write-Host '         Beispiel: -NasShare \"\\\\nas.ad.own.dedyn.io\\Software\"' -ForegroundColor Gray
        exit 1
    }
    Write-Host "Verwende ${DriveLetter}: (bereits gemountet)" -ForegroundColor Cyan
}

$rootPath = "${DriveLetter}:\$SearchBase"

if (-not (Test-Path $rootPath)) {
    Write-Host "[FEHLER] Pfad nicht gefunden: $rootPath" -ForegroundColor Red
    exit 1
}

# Verzeichnisse ermitteln
if ($Dirs.Count -eq 0) {
    Write-Host 'Kein -Dirs angegeben - suche alle Unterordner...' -ForegroundColor Yellow
    $Dirs = Get-ChildItem -Path $rootPath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    if ($Dirs.Count -eq 0) { $Dirs = @('') }
}

Write-Host "Durchsuche $($Dirs.Count) Verzeichnis(se) in: $rootPath" -ForegroundColor Cyan
Write-Host ''

$results = @()
foreach ($dir in $Dirs) {
    $fullDir = if ($dir -eq '') { $rootPath } else { Join-Path $rootPath $dir }

    if (-not (Test-Path $fullDir)) {
        Write-Host "[SKIP] Nicht gefunden: $fullDir" -ForegroundColor Yellow
        continue
    }

    $files = Get-ChildItem -Path $fullDir -Recurse -File -Filter '*.txt' -ErrorAction SilentlyContinue
    Write-Host "$dir  ($($files.Count) .txt Dateien)" -ForegroundColor Gray

    foreach ($file in $files) {
        $hits = Select-String -LiteralPath $file.FullName -Pattern '\.\.\.' -ErrorAction SilentlyContinue
        foreach ($hit in $hits) {
            $results += [pscustomobject]@{
                Dir     = $dir
                File    = $file.FullName.Replace($rootPath,'')
                Line    = $hit.LineNumber
                Content = $hit.Line.Trim()
            }
        }
    }
}

Write-Host ''
if ($results.Count -gt 0) {
    Write-Host "=== $($results.Count) Truncation(s) gefunden ===" -ForegroundColor Red
    $results | Format-Table Dir, File, Line, Content -AutoSize -Wrap
    $results | Export-Csv $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Bericht gespeichert: $OutputCsv" -ForegroundColor Yellow
} else {
    Write-Host 'Keine Truncations gefunden.' -ForegroundColor Green
}
Write-Host ''
