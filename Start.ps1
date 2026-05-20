#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# Load config
$localCfg  = Join-Path $root 'config.local.ps1'
$sampleCfg = Join-Path $root 'config.sample.ps1'
if (Test-Path $localCfg) {
    . $localCfg
} else {
    Write-Host '[INFO] No config.local.ps1 found. Running setup.ps1 first...' -ForegroundColor Yellow
    & (Join-Path $root 'setup.ps1')
    if (Test-Path $localCfg) { . $localCfg } else { exit 1 }
}

# Validate config loaded
if (-not $Config) {
    Write-Host '[FEHLER] $Config nicht geladen - setup.ps1 erneut ausfuehren.' -ForegroundColor Red
    exit 1
}

# Load lib
Get-ChildItem (Join-Path $root 'lib') -Filter '*.ps1' | ForEach-Object { . $_.FullName }

# Session-Verzeichnis in LocalTemp anlegen
$sessionStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$sessionDir   = Join-Path $Config.LocalTemp "session_$sessionStamp"
New-Item -Path $sessionDir -ItemType Directory -Force | Out-Null
Write-Host "[SESSION] $sessionDir" -ForegroundColor DarkGray

function Show-Menu {
    Write-Host ''
    Write-Host '=== Windows Disk Transition Toolkit ===' -ForegroundColor Cyan
    Write-Host '  1. Notebook eSATA export (Disk 1)'
    Write-Host '  2. HP Pro disk compare'
    Write-Host '  3. Copy local reports to NAS'
    Write-Host '  4. Show disk/partition map'
    Write-Host '  Q. Quit'
    Write-Host ''
}

$running = $true
while ($running) {
    Show-Menu
    $choice = Read-Host 'Choice'
    switch ($choice.ToUpper()) {
        '1' { Invoke-NotebookEsataExport -Config $Config -SessionDir $sessionDir }
        '2' { Invoke-HpProCompare        -Config $Config -SessionDir $sessionDir }
        '3' { Copy-ReportsToNas          -Config $Config -SessionDir $sessionDir }
        '4' { Get-DiskPartitionMap }
        'Q' { $running = $false }
        default { Write-Host 'Unbekannte Auswahl' -ForegroundColor Red }
    }
}

Write-Host 'Tschuess.' -ForegroundColor Gray
