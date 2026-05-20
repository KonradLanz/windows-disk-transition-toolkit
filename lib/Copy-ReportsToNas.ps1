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

    # Rekursiv kopieren - Unterordner werden als Unterordner im Ziel angelegt
    $items = Get-ChildItem -Path $localTemp -Recurse -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        # Relativer Pfad innerhalb von $localTemp
        $rel = $item.FullName.Substring($localTemp.Length).TrimStart('\', '/')
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
