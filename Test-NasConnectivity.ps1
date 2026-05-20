#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Vergleicht net use vs. New-PSDrive fuer NAS-Verbindungen und testet robocopy vs. Copy-Item.
    Hilft zu entscheiden welche Methode auf dieser Maschine zuverlaessig funktioniert.

.USAGE
    .\Test-NasConnectivity.ps1 -ShareRoot '\\server\share' -Drive Z
#>
param(
    [Parameter(Mandatory)]
    [string]$ShareRoot,

    [string]$Drive = 'T',

    [System.Management.Automation.PSCredential]
    $Credential = (Get-Credential -Message "NAS-Credentials fuer $ShareRoot")
)

if (-not $Credential) { Write-Host 'Abgebrochen.' -ForegroundColor Yellow; exit 1 }

$user     = $Credential.UserName
$password = $Credential.GetNetworkCredential().Password
$results  = [System.Collections.Generic.List[pscustomobject]]::new()

function Add-Result($test, $method, $success, $detail) {
    $results.Add([pscustomobject]@{
        Test    = $test
        Methode = $method
        OK      = if ($success) { 'JA' } else { 'NEIN' }
        Detail  = $detail
    })
    $col = if ($success) { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1} ({2})" -f (if ($success) { 'OK  ' } else { 'FAIL' }), $test, $method) -ForegroundColor $col
}

# --- Hilfsfunktion: EAP-sicherer net.exe-Aufruf ---
function Invoke-NetUse { 
    param([string[]]$NetArgs)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & net.exe @NetArgs 2>&1; $ec = $LASTEXITCODE
    $ErrorActionPreference = $prev
    [pscustomobject]@{ ExitCode = $ec; Output = $out }
}

function Cleanup-Drive {
    Invoke-NetUse @('use', "${Drive}:", '/delete', '/yes') | Out-Null
    Remove-PSDrive -Name $Drive -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== NAS Connectivity Test ==="  -ForegroundColor Cyan
Write-Host "  Ziel : $ShareRoot"
Write-Host "  User : $user"
Write-Host "  Drive: ${Drive}:"
Write-Host ""

# -----------------------------------------------------------------------
Write-Host "-- Test 1: net use" -ForegroundColor DarkCyan
Cleanup-Drive
$r = Invoke-NetUse @('use', "${Drive}:", $ShareRoot, $password, "/user:$user", '/persistent:no')
if ($r.ExitCode -eq 0) {
    $reachable = Test-Path "${Drive}:\"
    Add-Result 'net use verbinden'  'net.exe'  $true  "ExitCode=0, Laufwerk erreichbar=$reachable"

    # Test: Datei schreiben
    $testFile = Join-Path "${Drive}:\" "wdt-test-$([System.IO.Path]::GetRandomFileName()).tmp"
    try {
        [System.IO.File]::WriteAllText($testFile, 'WDT connectivity test')
        Remove-Item $testFile -Force
        Add-Result 'Datei schreiben' 'net use + IO' $true 'Schreib/Loeschtest OK'
    } catch {
        Add-Result 'Datei schreiben' 'net use + IO' $false $_.Exception.Message
    }
} else {
    $msg = ($r.Output | Out-String).Trim()
    Add-Result 'net use verbinden' 'net.exe' $false "ExitCode=$($r.ExitCode): $msg"
}
Cleanup-Drive

# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- Test 2: New-PSDrive" -ForegroundColor DarkCyan
Cleanup-Drive
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $cred = New-Object System.Management.Automation.PSCredential($user,
        (ConvertTo-SecureString $password -AsPlainText -Force))
    $pd = New-PSDrive -Name $Drive -PSProvider FileSystem -Root $ShareRoot -Credential $cred -Persist -ErrorAction Stop
    $reachable = Test-Path "${Drive}:\"
    Add-Result 'New-PSDrive verbinden' 'New-PSDrive' $true "Laufwerk erreichbar=$reachable"
    Remove-PSDrive -Name $Drive -Force -ErrorAction SilentlyContinue
} catch {
    Add-Result 'New-PSDrive verbinden' 'New-PSDrive' $false $_.Exception.Message
}
$ErrorActionPreference = $prev
Cleanup-Drive

# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- Test 3: robocopy vs Copy-Item" -ForegroundColor DarkCyan
$tmpSrc = Join-Path $env:TEMP "wdt-test-src-$([System.IO.Path]::GetRandomFileName())"
$tmpDst = Join-Path $env:TEMP "wdt-test-dst-$([System.IO.Path]::GetRandomFileName())"
New-Item $tmpSrc -ItemType Directory -Force | Out-Null
1..5 | ForEach-Object { [System.IO.File]::WriteAllText((Join-Path $tmpSrc "file$_.txt"), "Test $_") }

# robocopy lokal
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
robocopy $tmpSrc $tmpDst /E /R:1 /W:1 /NP /NFL /NDL 2>&1 | Out-Null
$rc = $LASTEXITCODE
$ErrorActionPreference = $prev
$copied = (Get-ChildItem $tmpDst -File -ErrorAction SilentlyContinue | Measure-Object).Count
Add-Result 'robocopy lokal' 'robocopy' ($rc -lt 8 -and $copied -eq 5) "ExitCode=$rc, Dateien kopiert=$copied/5"
Remove-Item $tmpDst -Recurse -Force -ErrorAction SilentlyContinue

# Copy-Item lokal
try {
    Copy-Item -Path "$tmpSrc\*" -Destination (New-Item $tmpDst -ItemType Directory -Force) -Recurse -Force
    $copied = (Get-ChildItem $tmpDst -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Add-Result 'Copy-Item lokal' 'Copy-Item' ($copied -eq 5) "Dateien kopiert=$copied/5"
} catch {
    Add-Result 'Copy-Item lokal' 'Copy-Item' $false $_.Exception.Message
}
Remove-Item $tmpSrc -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $tmpDst -Recurse -Force -ErrorAction SilentlyContinue

# robocopy auf NAS (wenn net use funktioniert hat)
$r2 = Invoke-NetUse @('use', "${Drive}:", $ShareRoot, $password, "/user:$user", '/persistent:no')
if ($r2.ExitCode -eq 0) {
    $nasSrc = Join-Path $env:TEMP "wdt-nas-src-$([System.IO.Path]::GetRandomFileName())"
    $nasDst = "${Drive}:\wdt-connectivity-test"
    New-Item $nasSrc -ItemType Directory -Force | Out-Null
    1..3 | ForEach-Object { [System.IO.File]::WriteAllText((Join-Path $nasSrc "file$_.txt"), "NAS Test $_") }

    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    robocopy $nasSrc $nasDst /E /R:2 /W:3 /NP /NFL /NDL 2>&1 | Out-Null
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $copied = (Get-ChildItem $nasDst -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Add-Result 'robocopy auf NAS' 'robocopy' ($rc -lt 8 -and $copied -eq 3) "ExitCode=$rc, Dateien=$copied/3"

    # Cleanup NAS
    Invoke-NetUse @('use', "${Drive}:", $ShareRoot, $password, "/user:$user", '/persistent:no') | Out-Null
    Remove-Item $nasDst -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $nasSrc -Recurse -Force -ErrorAction SilentlyContinue
    Cleanup-Drive
}

# -----------------------------------------------------------------------
Write-Host ""
Write-Host "=== Ergebnis ==="  -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host ""
Write-Host "Empfehlung:" -ForegroundColor Yellow
if (($results | Where-Object { $_.Test -eq 'net use verbinden' -and $_.OK -eq 'JA' })) {
    Write-Host "  -> net use: funktioniert. Verwende Connect-NasWithRetry aus lib/Get-CredentialCache.ps1" -ForegroundColor Green
} else {
    Write-Host "  -> net use: fehlgeschlagen. Credentials pruefen oder alternative Methode evaluieren." -ForegroundColor Red
}
if (($results | Where-Object { $_.Test -eq 'robocopy auf NAS' -and $_.OK -eq 'JA' })) {
    Write-Host "  -> robocopy auf NAS: funktioniert. Verwende Copy-ReportsToNas." -ForegroundColor Green
} else {
    Write-Host "  -> robocopy: nicht getestet (net use fehlgeschlagen) oder Fehler." -ForegroundColor Yellow
}
