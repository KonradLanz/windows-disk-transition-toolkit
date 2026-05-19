function Copy-ReportsToNas {
    param(
        [pscustomobject]$Config,
        [string]$SubFolder = ''
    )

    $stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
    $shareRoot = $Config.NasShare
    $targetRel = $Config.NasTarget
    $drive     = $Config.DriveLetter
    $localTemp = $Config.LocalTemp

    $ok = Connect-NasWithRetry -Drive $drive -ShareRoot $shareRoot -CacheKey 'nas'
    if (-not $ok) { return }

    $folderName = if ($SubFolder) { $SubFolder } else { "reports_$stamp" }
    $runDir = Join-Path "${drive}:\$targetRel" $folderName
    New-Item -Path $runDir -ItemType Directory -Force | Out-Null

    $files = Get-ChildItem -Path $localTemp -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item -LiteralPath $f.FullName -Destination $runDir -Force
        Write-Host "Kopiert: $($f.Name)" -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host 'Reports kopiert nach:' -ForegroundColor Green
    Write-Host $runDir -ForegroundColor Yellow
    Write-Host ''

    try { Remove-PSDrive -Name $drive -Force -ErrorAction SilentlyContinue } catch {}
}
