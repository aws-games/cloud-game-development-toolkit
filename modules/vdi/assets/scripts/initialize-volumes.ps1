param(
    [string]$WorkstationKey,
    [string]$ProjectPrefix,
    [string]$Region,
    [string]$VolumeHash,
    [string]$ForceRun
)

Write-Host "Initializing volumes for $WorkstationKey (Hash: $VolumeHash)"

# Check if we need to run based on volume hash
$hashParam = "/$ProjectPrefix/$WorkstationKey/volume_hash"
try {
    $storedHash = aws ssm get-parameter --name $hashParam --region $Region --query Parameter.Value --output text 2>$null
    if ($storedHash -eq $VolumeHash -and $ForceRun -ne "true") {
        Write-Host "Volume configuration unchanged, skipping initialization"
        return
    }
} catch {
    Write-Host "No previous volume hash found, proceeding with initialization"
}

# WARNING: Drive letter changes can cause data access issues
Write-Host "WARNING: Changing drive letters on existing systems may cause applications to lose access to data" -ForegroundColor Yellow

# Initialize and format EBS volumes
Write-Host "Initializing EBS volumes..."
try {
    # Stop ShellHWDetection service as recommended by AWS
    Stop-Service -Name ShellHWDetection -ErrorAction SilentlyContinue
    
    # Bring offline disks online first
    Get-Disk | Where-Object { $_.OperationalStatus -eq 'Offline' -and $_.Number -ne 0 } | ForEach-Object {
        Write-Host "Bringing disk $($_.Number) online (Size: $([math]::Round($_.Size/1GB, 2))GB)"
        Set-Disk -Number $_.Number -IsOffline $false
    }
    
    # Get all RAW disks (uninitialized) excluding boot disk
    $rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Number -ne 0 }
    
    Write-Host "Found $($rawDisks.Count) uninitialized (RAW) disks"
    
    # Initialize RAW disks
    if ($rawDisks.Count -gt 0) {
        Write-Host "Initializing $($rawDisks.Count) RAW disks"
        
        $rawDisks | ForEach-Object {
            $partitionStyle = if ($_.Size -gt 2TB) { "GPT" } else { "MBR" }
            Write-Host "Initializing disk $($_.Number) with $partitionStyle"
            $_ | Initialize-Disk -PartitionStyle $partitionStyle -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
        }
        
        Write-Host "All RAW disks initialized successfully"
    } else {
        Write-Host "No RAW disks found to initialize"
    }
    
    # Restart ShellHWDetection service
    Start-Service -Name ShellHWDetection -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "Failed to initialize disks: $_" -ForegroundColor Yellow
    return
}

# Extend existing partitions
Write-Host "Extending partitions to use full disk space..."
try {
    $allDisks = Get-Disk | Where-Object { $_.Number -ne 0 }
    
    foreach ($disk in $allDisks) {
        $partitions = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -eq 'Basic' }
        
        foreach ($partition in $partitions) {
            try {
                $maxSize = (Get-PartitionSupportedSize -DriveLetter $partition.DriveLetter).SizeMax
                $currentSize = $partition.Size
                
                if ($maxSize -gt ($currentSize + 100MB)) {
                    Write-Host "Extending partition $($partition.DriveLetter): from $([math]::Round($currentSize/1GB, 2))GB to $([math]::Round($maxSize/1GB, 2))GB"
                    Resize-Partition -DriveLetter $partition.DriveLetter -Size $maxSize
                }
            } catch {
                Write-Host "Could not extend partition $($partition.DriveLetter): $_" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "Failed to extend partitions: $_" -ForegroundColor Yellow
    return
}

# Organize drive letters based on Terraform configuration
Write-Host "Organizing drive letters..."
try {
    $partitions = Get-Partition | Where-Object { $_.DriveLetter -ne $null -and $_.DriveLetter -ne 'C' }
    
    foreach ($partition in $partitions) {
        $disk = Get-Disk -Number $partition.DiskNumber
        $serialNumber = $disk.SerialNumber
        
        # AWS Official Detection: EBS starts with "vol", Instance store starts with "AWS"
        if ($serialNumber -and $serialNumber.StartsWith('AWS')) {
            # Instance store -> T: drive
            if ($partition.DriveLetter -ne 'T') {
                Write-Host "Moving instance store to T: drive"
                try {
                    Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$($partition.DriveLetter):"
                    Add-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "T:"
                } catch {
                    Write-Host "Failed to reassign instance store: $_" -ForegroundColor Yellow
                }
            }
        }
    }
} catch {
    Write-Host "Failed to organize drive letters: $_" -ForegroundColor Yellow
    return
}

# Store volume hash to prevent unnecessary re-runs
try {
    aws ssm put-parameter --name $hashParam --value $VolumeHash --overwrite --region $Region | Out-Null
    Write-Host "Volume hash stored for future reference"
} catch {
    Write-Host "Failed to store volume hash: $_" -ForegroundColor Yellow
}

Write-Host "Volume initialization completed"