function Copy-ReportsToNas {
    param(
        [pscustomobject]$Config,
        [string]$SessionDir = '',
        [string]$SubFolder = ''
    )

    $stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
    $shareRoot = $Config.NasShare
    $targetRel = $Config.NasTarget
    $drive     = $Config.DriveLetter

    # Quelle: Session-Dir bevorzugt, Fallback auf LocalTemp
    $sourceDir = if ($SessionDir -and (Test-Path $SessionDir)) { $SessionDir } else { $Config.LocalTemp }

    $ok = Connect-NasWithRetry -Drive $drive -ShareRoot $shareRoot -CacheKey 'nas'
    if (-not $ok) { return }

    $folderName = if ($SubFolder) { $SubFolder } else { "reports_$stamp" }
    $runDir = Join-Path "${drive}:\$targetRel" $folderName
    New-Item -Path $runDir -ItemType Directory -Force | Out-Null

    # robocopy statt Copy-Item: automatischer Retry bei Netzwerkauslastung
    # ExitCode 0-7 = Erfolg (Bit-Flags), >= 8 = Fehler
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $rcOutput = robocopy $sourceDir $runDir /E /R:3 /W:5 /NP 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prev

    if ($rc -ge 8) {
        Write-Host "" 
        Write-Host "[FEHLER] robocopy ExitCode $rc - Transfer moeglicherweise unvollstaendig" -ForegroundColor Red
        $rcOutput | Where-Object { $_ -match 'ERROR|FEHLER' } | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
    } else {
        # Kopierte Dateien aus robocopy-Output extrahieren und anzeigen
        $rcOutput | Where-Object { $_ -match '^\s+\S' -and $_ -notmatch '^\s*-' } | ForEach-Object {
            $name = ($_ -split '\s+', 2)[-1].Trim()
            if ($name -and -not ($name -match '^-{3,}') ) {
                Write-Host "Kopiert: $name" -ForegroundColor Gray
            }
        }
    }

    Write-Host ''
    Write-Host 'Reports kopiert nach:' -ForegroundColor Green
    Write-Host $runDir -ForegroundColor Yellow
    Write-Host ''

    Disconnect-Nas -Drive $drive
}
