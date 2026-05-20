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

    $items = Get-ChildItem -Path $sourceDir -Recurse -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $rel  = $item.FullName.Substring($sourceDir.Length).TrimStart('\', '/')
        $dest = Join-Path $runDir $rel
        if ($item.PSIsContainer) {
            New-Item -Path $dest -ItemType Directory -Force | Out-Null
        } else {
            Copy-Item -LiteralPath $item.FullName -Destination $dest -Force
            Write-Host "Kopiert: $rel" -ForegroundColor Gray
        }
    }

    Write-Host ''
    Write-Host 'Reports kopiert nach:' -ForegroundColor Green
    Write-Host $runDir -ForegroundColor Yellow
    Write-Host ''

    Disconnect-Nas -Drive $drive
}
