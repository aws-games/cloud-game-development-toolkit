param(
    [string]$WorkstationKey,
    [string]$ProjectPrefix,
    [string]$Region,
    [string]$VolumeHash,
    [string]$ForceRun
)

Write-Host "Fixing drive letters for $WorkstationKey"

# Get all partitions except C:
$partitions = Get-Partition | Where-Object { $_.DriveLetter -ne $null -and $_.DriveLetter -ne 'C' }

foreach ($partition in $partitions) {
    $disk = Get-Disk -Number $partition.DiskNumber
    $diskSize = [math]::Round($disk.Size/1GB, 0)

    Write-Host "Found partition $($partition.DriveLetter): ($diskSize GB)"

    # Move 2TB volume to D:
    if ($diskSize -ge 1900 -and $diskSize -le 2100 -and $partition.DriveLetter -ne 'D') {
        Write-Host "Moving $diskSize GB volume from $($partition.DriveLetter): to D:"
        Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$($partition.DriveLetter):"
        Add-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "D:"
    }
}

Write-Host "Drive letter fix completed"
