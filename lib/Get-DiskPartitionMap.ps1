function Get-DiskPartitionMap {
    param([int[]]$DiskNumbers = @())

    $disks = if ($DiskNumbers.Count -gt 0) {
        $DiskNumbers | ForEach-Object { Get-Disk -Number $_ }
    } else {
        Get-Disk
    }

    $map = foreach ($d in $disks) {
        $parts = Get-Partition -DiskNumber $d.Number
        foreach ($p in $parts) {
            $v = $null
            try { $v = Get-Volume -Partition $p } catch {}
            [pscustomobject]@{
                DiskNumber        = $d.Number
                DiskModel         = $d.FriendlyName
                BusType           = $d.BusType
                PartitionStyle    = $d.PartitionStyle
                Signature         = $d.Signature
                DiskUniqueId      = $d.UniqueId
                PartNo            = $p.PartitionNumber
                Offset            = $p.Offset
                SizeGB            = [math]::Round($p.Size / 1GB, 2)
                Type              = $p.Type
                MbrType           = $p.MbrType
                GptType           = $p.GptType
                DriveLetter       = $p.DriveLetter
                FileSystem        = $v.FileSystem
                Label             = $v.FileSystemLabel
                HealthStatus      = $v.HealthStatus
                OperationalStatus = $v.OperationalStatus
            }
        }
    }

    $map | Sort-Object DiskNumber, Offset | Format-Table -AutoSize
}
