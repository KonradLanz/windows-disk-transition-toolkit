function Invoke-NotebookEsataExport {
    param(
        [pscustomobject]$Config,
        [int]$DiskNumber = 1
    )

    $stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
    $shareRoot = $Config.NasShare
    $targetRel = $Config.NasTarget
    $drive     = $Config.DriveLetter
    $localOut  = $Config.LocalOutput

    # Ausgabeverzeichnis: lokaler Pfad hat Vorrang wenn angegeben, sonst NAS
    if ($localOut -and $localOut -ne '') {
        $runDir = Join-Path $localOut ("esata-disk${DiskNumber}-analysis_$stamp")
        New-Item -Path $runDir -ItemType Directory -Force | Out-Null
        Write-Host "[INFO] Ausgabe lokal: $runDir" -ForegroundColor Cyan
    } else {
        $ok = Connect-NasWithRetry -Drive $drive -ShareRoot $shareRoot -CacheKey 'nas'
        if (-not $ok) { return }
        $runDir = Join-Path "${drive}:\$targetRel" ("esata-disk${DiskNumber}-analysis_$stamp")
        New-Item -Path $runDir -ItemType Directory -Force | Out-Null
        Write-Host "[INFO] Ausgabe NAS: $runDir" -ForegroundColor Cyan
    }

    $disk  = Get-Disk -Number $DiskNumber
    $parts = Get-Partition -DiskNumber $DiskNumber

    $disk | Format-List * | Out-File (Join-Path $runDir 'disk.txt')

    $parts | Format-Table * -AutoSize | Out-String -Width 4096 |
        Out-File (Join-Path $runDir 'partitions-full.txt')

    $parts | Select-Object PartitionNumber, DriveLetter, Offset, Size, Type, MbrType, GptType |
        Format-Table -AutoSize | Out-String -Width 4096 |
        Out-File (Join-Path $runDir 'partitions-summary.txt')

    $map = $parts | ForEach-Object {
        $p = $_
        $v = $null
        try { $v = Get-Volume -Partition $p } catch {}
        [pscustomobject]@{
            PartitionNumber   = $p.PartitionNumber
            DriveLetter       = $p.DriveLetter
            Offset            = $p.Offset
            SizeGB            = [math]::Round($p.Size / 1GB, 2)
            Type              = $p.Type
            MbrType           = $p.MbrType
            GptType           = $p.GptType
            FileSystem        = $v.FileSystem
            Label             = $v.FileSystemLabel
            HealthStatus      = $v.HealthStatus
            OperationalStatus = $v.OperationalStatus
        }
    }

    $map | Format-Table -AutoSize | Out-String -Width 4096 |
        Out-File (Join-Path $runDir 'partition-volume-map.txt')
    $map | Export-Csv (Join-Path $runDir 'partition-volume-map.csv') -NoTypeInformation -Encoding UTF8

    $parts | Select-Object PartitionNumber, DiskPath, Offset, Size | Format-List |
        Out-File (Join-Path $runDir 'partition-paths.txt')

    $letters = $parts | Where-Object { $_.DriveLetter } | Select-Object -ExpandProperty DriveLetter
    if ($letters) {
        Get-Volume | Where-Object { $_.DriveLetter -in $letters } | Format-List * |
            Out-File (Join-Path $runDir 'volumes-on-disk.txt')
    }

    foreach ($p in ($parts | Where-Object { $_.DriveLetter })) {
        $letter = $p.DriveLetter
        $dst = Join-Path $runDir ('listing-' + $letter)
        New-Item -Path $dst -ItemType Directory -Force | Out-Null

        try {
            Get-ChildItem -LiteralPath "${letter}:\" -Force -ErrorAction SilentlyContinue |
                Select-Object Name, FullName, Length, LastWriteTime, Attributes |
                Format-List | Out-File (Join-Path $dst 'root-listing.txt')
        } catch {
            $_ | Out-String -Width 4096 | Out-File (Join-Path $dst 'root-listing-error.txt')
        }

        foreach ($special in @('Recovery', 'Recovery\WindowsRE', 'Boot', 'EFI', 'System Volume Information')) {
            $path = Join-Path "${letter}:\" $special
            $safe = $special -replace '[\\/:*?"<>| ]', '_'
            try {
                if (Test-Path -LiteralPath $path) {
                    Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue |
                        Select-Object Name, FullName, Length, LastWriteTime, Attributes |
                        Format-List | Out-File (Join-Path $dst "$safe.txt")
                }
            } catch {
                $_ | Out-String -Width 4096 | Out-File (Join-Path $dst "$safe-error.txt")
            }
        }
    }

    [pscustomobject]@{
        DiskNumber         = $disk.Number
        FriendlyName       = $disk.FriendlyName
        Model              = $disk.Model
        SerialNumber       = $disk.SerialNumber
        BusType            = $disk.BusType
        PartitionStyle     = $disk.PartitionStyle
        NumberOfPartitions = $disk.NumberOfPartitions
        SizeGB             = [math]::Round($disk.Size / 1GB, 2)
        Location           = $disk.Location
    } | Format-List | Out-File (Join-Path $runDir 'disk-summary.txt')

    Write-Host ''
    Write-Host 'eSATA Export abgeschlossen nach:' -ForegroundColor Green
    Write-Host $runDir -ForegroundColor Yellow
    Write-Host ''

    if (-not ($localOut -and $localOut -ne '')) {
        Disconnect-Nas -Drive $drive
    }
}
