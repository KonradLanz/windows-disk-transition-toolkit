function Invoke-HpProCompare {
    param([pscustomobject]$Config)

    $stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
    $shareRoot = $Config.NasShare
    $targetRel = $Config.NasTarget
    $drive     = $Config.DriveLetter
    $localTemp = $Config.LocalTemp
    $localOut  = $Config.LocalOutput

    # Build live compare report
    $disks  = Get-Disk
    $report = foreach ($d in $disks) {
        $parts = Get-Partition -DiskNumber $d.Number
        foreach ($p in $parts) {
            $v = $null
            try { $v = Get-Volume -Partition $p } catch {}
            [pscustomobject]@{
                DiskNumber     = $d.Number
                DiskModel      = $d.FriendlyName
                BusType        = $d.BusType
                PartitionStyle = $d.PartitionStyle
                DiskUniqueId   = $d.UniqueId
                Signature      = $d.Signature
                PartNo         = $p.PartitionNumber
                Offset         = $p.Offset
                SizeGB         = [math]::Round($p.Size / 1GB, 2)
                Type           = $p.Type
                MbrType        = $p.MbrType
                DriveLetter    = $p.DriveLetter
                FileSystem     = $v.FileSystem
                Label          = $v.FileSystemLabel
            }
        }
    }

    $report | Sort-Object DiskNumber, Offset | Format-Table -AutoSize

    # CSV lokal zwischenspeichern
    if ($localTemp) {
        $report | Sort-Object DiskNumber, Offset |
            Export-Csv (Join-Path $localTemp 'disk-compare.csv') -NoTypeInformation -Encoding UTF8
    }

    # Signaturkonflikt pruefen (Klon-Indikator)
    $sigs = $report | Select-Object -ExpandProperty Signature -Unique | Where-Object { $_ }
    if (($sigs | Measure-Object).Count -lt ($disks | Measure-Object).Count) {
        Write-Host '[WARNUNG] Moeglicher Signaturkonflikt - gleiche MBR-Signatur auf mehreren Disks!' -ForegroundColor Red
    }

    # Ausgabeverzeichnis: lokaler Pfad hat Vorrang wenn angegeben, sonst NAS
    if ($localOut -and $localOut -ne '') {
        $runDir = Join-Path $localOut ("hp-pro-analysis_$stamp")
        New-Item -Path $runDir -ItemType Directory -Force | Out-Null
        Write-Host "[INFO] Ausgabe lokal: $runDir" -ForegroundColor Cyan
    } else {
        $ok = Connect-NasWithRetry -Drive $drive -ShareRoot $shareRoot -CacheKey 'nas'
        if (-not $ok) { return }
        $runDir = Join-Path "${drive}:\$targetRel" ("hp-pro-analysis_$stamp")
        New-Item -Path $runDir -ItemType Directory -Force | Out-Null
        Write-Host "[INFO] Ausgabe NAS: $runDir" -ForegroundColor Cyan
    }

    $report | Sort-Object DiskNumber, Offset |
        Export-Csv (Join-Path $runDir 'disk-compare.csv') -NoTypeInformation -Encoding UTF8
    $report | Sort-Object DiskNumber, Offset | Format-Table -AutoSize | Out-String |
        Out-File (Join-Path $runDir 'disk-compare.txt')

    foreach ($f in @('disk1.txt', 'disk1-partitions.txt', 'disk1-volumes.txt')) {
        $src = Join-Path $localTemp $f
        if ($src -and (Test-Path $src)) { Copy-Item $src -Destination $runDir -Force }
    }

    Write-Host ''
    Write-Host 'HP Pro Compare abgeschlossen nach:' -ForegroundColor Green
    Write-Host $runDir -ForegroundColor Yellow
    Write-Host ''

    if (-not ($localOut -and $localOut -ne '')) {
        Disconnect-Nas -Drive $drive
    }
}
