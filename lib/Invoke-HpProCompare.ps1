function Invoke-HpProCompare {
    param([pscustomobject]$Config)

    $cred      = Get-CredentialCache -CacheKey "nas" -Message "NAS-Zugangsdaten fuer HP Pro Compare"
    $stamp     = Get-Date -Format "yyyyMMdd-HHmmss"
    $shareRoot = $Config.NasShare
    $targetRel = $Config.NasTarget
    $drive     = $Config.DriveLetter
    $localTemp = $Config.LocalTemp

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
    $report | Sort-Object DiskNumber, Offset |
        Export-Csv (Join-Path $localTemp "disk-compare.csv") -NoTypeInformation -Encoding UTF8

    # Check for signature conflict (clone indicator)
    $sigs = $report | Select-Object -ExpandProperty Signature -Unique | Where-Object { $_ }
    if (($sigs | Measure-Object).Count -lt ($disks | Measure-Object).Count) {
        Write-Host "[WARNUNG] Moeglicher Signaturkonflikt — gleiche MBR-Signatur auf mehreren Disks!" -ForegroundColor Red
    }

    # Copy to NAS
    try { Remove-PSDrive -Name $drive -Force -ErrorAction SilentlyContinue } catch {}
    New-PSDrive -Name $drive -PSProvider FileSystem -Root $shareRoot -Credential $cred -Scope Global | Out-Null

    $runDir = Join-Path "${drive}:\$targetRel" "hp-pro-analysis_$stamp"
    New-Item -Path $runDir -ItemType Directory -Force | Out-Null

    $report | Sort-Object DiskNumber, Offset |
        Export-Csv (Join-Path $runDir "disk-compare.csv") -NoTypeInformation -Encoding UTF8
    $report | Sort-Object DiskNumber, Offset | Format-Table -AutoSize | Out-String |
        Out-File (Join-Path $runDir "disk-compare.txt")

    foreach ($f in @("disk1.txt","disk1-partitions.txt","disk1-volumes.txt")) {
        $src = Join-Path $localTemp $f
        if (Test-Path $src) { Copy-Item $src -Destination $runDir -Force }
    }

    Write-Host ""
    Write-Host "HP Pro Compare abgeschlossen nach:" -ForegroundColor Green
    Write-Host $runDir -ForegroundColor Yellow
    Write-Host ""

    try { Remove-PSDrive -Name $drive -Force -ErrorAction SilentlyContinue } catch {}
}
