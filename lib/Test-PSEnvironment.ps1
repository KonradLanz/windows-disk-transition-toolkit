# Test-PSEnvironment.ps1
# Synced from KonradLanz/ExecutionPolicy-Foundation
# Baseline: PowerShell 5.1 (ships with Windows 10/11, no install required)
#
# Naming convention:
#   *.ps1          -> PS 5.1 compatible (default baseline)
#   *.pwsh7.ps1    -> Requires pwsh.exe >= 7.x
#   *.pwsh74.ps1   -> Requires pwsh.exe >= 7.4 LTS

function Test-PSEnvironment {
    param(
        [version]$MinimumVersion     = [version]'5.1',
        [version]$RecommendedVersion = [version]'7.4',
        [switch]$RequirePS7,
        [switch]$Quiet
    )

    $cur     = $PSVersionTable.PSVersion
    $edition = $PSVersionTable.PSEdition
    $os      = [System.Environment]::OSVersion.Version
    $isPS7   = $cur.Major -ge 7
    $isPS51  = ($edition -eq 'Desktop') -and ($cur.Major -eq 5)

    if (-not $Quiet) {
        Write-Host "PowerShell : $cur ($edition)" -ForegroundColor Cyan
        Write-Host "Windows    : $os" -ForegroundColor Cyan
    }

    if ($RequirePS7 -and -not $isPS7) {
        Write-Host ''
        Write-Host '[FEHLER] Dieses Skript benoetigt pwsh.exe >= 7.x (PowerShell Core).' -ForegroundColor Red
        Write-Host "         Aktuell: powershell.exe $cur" -ForegroundColor Red
        Write-Host '         Installieren: winget install Microsoft.PowerShell' -ForegroundColor Gray
        exit 1
    }

    if ($cur -lt $MinimumVersion) {
        Write-Host ''
        Write-Host "[FEHLER] PowerShell $cur zu alt. Mindestens $MinimumVersion erforderlich." -ForegroundColor Red
        exit 1
    }

    if ($cur -lt $RecommendedVersion -and -not $Quiet) {
        Write-Host ''
        Write-Host "[HINWEIS] PS $cur gefunden. Empfohlen: PS $RecommendedVersion+" -ForegroundColor Yellow
        Write-Host '          winget install Microsoft.PowerShell' -ForegroundColor Gray
    }

    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $hasGit    = [bool](Get-Command git    -ErrorAction SilentlyContinue)
    $hasWT     = [bool](Get-Command wt     -ErrorAction SilentlyContinue)

    if (-not $hasWinget -and -not $Quiet) {
        Write-Host ''
        Write-Host '[HINWEIS] winget nicht gefunden. https://aka.ms/getwinget' -ForegroundColor Yellow
    }
    if (-not $hasGit -and -not $Quiet) {
        Write-Host ''
        Write-Host '[HINWEIS] git nicht gefunden. winget install Git.Git' -ForegroundColor Yellow
    }
    if (-not $hasWT -and -not $Quiet) {
        Write-Host '[HINWEIS] Windows Terminal nicht gefunden (empfohlen).' -ForegroundColor Gray
        Write-Host '          winget install Microsoft.WindowsTerminal' -ForegroundColor Gray
    }

    return [pscustomobject]@{
        PSVersion    = $cur
        PSEdition    = $edition
        IsPS7Plus    = $isPS7
        IsPS51       = $isPS51
        OSVersion    = $os
        HasWinget    = $hasWinget
        HasGit       = $hasGit
        HasWT        = $hasWT
    }
}
