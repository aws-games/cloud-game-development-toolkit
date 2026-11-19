param(
    [string]$WorkstationKey,
    [string]$ProjectPrefix,
    [string]$Region,
    [string]$VolumeHash,
    [string]$VolumeMapping
)

# Exit codes for different scenarios
$EXIT_SUCCESS = 0
$EXIT_GENERAL_FAILURE = 1
$EXIT_DISK_NOT_FOUND = 2
$EXIT_FORMAT_FAILED = 3
$EXIT_DRIVE_LETTER_FAILED = 4
$EXIT_ALREADY_COMPLETED = 5

# Enhanced logging function
function Write-StatusLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [VDI-$WorkstationKey] $Message"
    Write-Host $logMessage

    # Also write to Windows Event Log for CloudWatch agent pickup
    try {
        Write-EventLog -LogName Application -Source "VDI-VolumeScript" -EventId 1001 -EntryType Information -Message $logMessage -ErrorAction SilentlyContinue
    } catch { }
}

# Register event source if it doesn't exist
try {
    New-EventLog -LogName Application -Source "VDI-VolumeScript" -ErrorAction SilentlyContinue
} catch { }

Write-StatusLog "Starting volume management for workstation $WorkstationKey (Hash: $VolumeHash)" "START"

# Configuration files for tracking state
$markerFile = "C:\temp\volume_config_${VolumeHash}.complete"
$previousConfigFile = "C:\temp\previous_volume_config.json"

# Parse current volume mapping
$volumeMap = @{}
$expectedVolumeCount = 0
try {
    if ($VolumeMapping -and $VolumeMapping -ne "") {
        Write-Host "DEBUG: Raw VolumeMapping parameter: $VolumeMapping"

        # Handle potential JSON escaping issues from SSM
        $cleanedMapping = $VolumeMapping
        if ($VolumeMapping.StartsWith('{') -and -not $VolumeMapping.Contains('"')) {
            # Fix unquoted JSON keys/values: {/dev/sdf:Learning} -> {"/dev/sdf":"Learning"}
            $cleanedMapping = $VolumeMapping -replace '([^{,]+):([^,}]+)', '"$1":"$2"'
            Write-Host "DEBUG: Cleaned VolumeMapping: $cleanedMapping"
        }

        $volumeMap = ConvertFrom-Json $cleanedMapping
        $expectedVolumeCount = $volumeMap.PSObject.Properties.Count
        Write-Host "STATUS: Expected $expectedVolumeCount volumes from current mapping"

        # Debug: Show parsed volume mapping
        foreach ($deviceName in $volumeMap.PSObject.Properties.Name) {
            Write-Host "DEBUG: Device $deviceName -> Volume $($volumeMap.$deviceName)"
        }
    }
} catch {
    Write-StatusLog "FAILED to parse volume mapping - $($_.Exception.Message): $VolumeMapping" "ERROR"
    exit $EXIT_GENERAL_FAILURE
}

# Load previous configuration for comparison
$previousVolumeMap = @{}
try {
    if (Test-Path $previousConfigFile) {
        $previousConfig = Get-Content $previousConfigFile | ConvertFrom-Json
        $previousVolumeMap = $previousConfig.VolumeMapping
        Write-Host "STATUS: Loaded previous configuration with $($previousVolumeMap.PSObject.Properties.Count) volumes"
    }
} catch {
    Write-Host "WARNING: Could not load previous configuration - treating as first run"
}

# Detect volume changes
$addedVolumes = @()
$removedVolumes = @()
$sizeChangedVolumes = @()

# Compare current vs previous configuration
foreach ($deviceName in $volumeMap.PSObject.Properties.Name) {
    $volumeName = $volumeMap.$deviceName
    if (-not $previousVolumeMap.$deviceName) {
        $addedVolumes += @{ DeviceName = $deviceName; VolumeName = $volumeName }
        Write-Host "STATUS: Detected new volume: $volumeName ($deviceName)"
    }
}

foreach ($deviceName in $previousVolumeMap.PSObject.Properties.Name) {
    $volumeName = $previousVolumeMap.$deviceName
    if (-not $volumeMap.$deviceName) {
        $removedVolumes += @{ DeviceName = $deviceName; VolumeName = $volumeName }
        Write-Host "WARNING: Detected removed volume: $volumeName ($deviceName)"
    }
}

# Idempotency check - skip if already completed and no changes detected
if (Test-Path $markerFile -and $addedVolumes.Count -eq 0) {
    try {
        $markerContent = Get-Content $markerFile | ConvertFrom-Json
        if ($markerContent.VolumeHash -eq $VolumeHash) {
            Write-Host "STATUS: Volume configuration $VolumeHash already completed on $($markerContent.CompletedDate)"

            # Still check for size changes and extensions
            Write-Host "STATUS: Checking for volume size changes..."
            $extendedPartitions = Invoke-VolumeExtension

            if ($extendedPartitions -gt 0) {
                Write-Host "SUCCESS: Extended $extendedPartitions partitions"
            } else {
                Write-Host "STATUS: No volume extensions needed"
            }

            # Report removed volumes but don't auto-cleanup
            if ($removedVolumes.Count -gt 0) {
                Write-Host "WARNING: $($removedVolumes.Count) volumes were removed from configuration:"
                foreach ($removed in $removedVolumes) {
                    Write-Host "  - $($removed.VolumeName) ($($removed.DeviceName))"
                }
                Write-Host "INFO: Manual cleanup may be required in Windows Disk Management"
            }

            exit $EXIT_SUCCESS
        }
    } catch {
        Write-Host "WARNING: Could not validate marker file - proceeding with full initialization"
    }
}

# Function to extend existing partitions
function Invoke-VolumeExtension {
    $extendedCount = 0
    try {
        # Get ALL disks including disk 0 (root disk) - exclude only RAW disks
        $allDisks = Get-Disk | Where-Object { $_.PartitionStyle -ne 'RAW' }

        foreach ($disk in $allDisks) {
            # Get all partitions with drive letters (including C: on disk 0)
            $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }

            foreach ($partition in $partitions) {
                try {
                    $maxSize = (Get-PartitionSupportedSize -DriveLetter $partition.DriveLetter).SizeMax
                    $currentSize = $partition.Size

                    if ($maxSize -gt ($currentSize + 100MB)) {
                        $currentGB = [math]::Round($currentSize/1GB, 2)
                        $maxGB = [math]::Round($maxSize/1GB, 2)
                        Write-Host "STATUS: Extending partition $($partition.DriveLetter): from ${currentGB}GB to ${maxGB}GB"
                        Resize-Partition -DriveLetter $partition.DriveLetter -Size $maxSize
                        $extendedCount++
                    }
                } catch {
                    Write-Host "WARNING: Could not extend partition $($partition.DriveLetter): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Host "WARNING: Volume extension check failed - $($_.Exception.Message)"
    }
    return $extendedCount
}

# Wait for EBS volumes to be recognized by Windows with retry logic
Write-Host "STATUS: Waiting for EBS volumes to be recognized..."
$maxRetries = 30
$retryDelay = 10
$availableDisks = @()

for ($i = 0; $i -lt $maxRetries; $i++) {
    try {
        # Force disk rescan
        "rescan" | diskpart | Out-Null
        Start-Sleep -Seconds 2

        # Get available EBS disks (exclude boot disk only)
        $availableDisks = Get-Disk | Where-Object {
            $_.Number -ne 0 -and
            $_.BusType -in @('NVMe', 'SCSI')
        }

        if ($availableDisks.Count -ge $expectedVolumeCount) {
            Write-Host "STATUS: Found $($availableDisks.Count) EBS disks (expected: $expectedVolumeCount)"
            break
        }

        Write-Host "STATUS: Retry $($i + 1)/$maxRetries - Found $($availableDisks.Count)/$expectedVolumeCount disks"
        Start-Sleep -Seconds $retryDelay
    } catch {
        Write-Host "WARNING: Disk scan retry $($i + 1) failed - $($_.Exception.Message)"
    }
}

if ($availableDisks.Count -lt $expectedVolumeCount) {
    Write-Host "ERROR: Only found $($availableDisks.Count) disks, expected $expectedVolumeCount"
    exit $EXIT_DISK_NOT_FOUND
}

# Initialize volumes with comprehensive state checking
Write-Host "STATUS: Processing disk initialization and management..."
$processedDisks = 0
$skippedDisks = 0
$failedDisks = 0

try {
    # Stop ShellHWDetection service as recommended by AWS
    Stop-Service -Name ShellHWDetection -ErrorAction SilentlyContinue

    # Bring offline disks online
    Get-Disk | Where-Object { $_.OperationalStatus -eq 'Offline' -and $_.Number -ne 0 } | ForEach-Object {
        Write-Host "STATUS: Bringing disk $($_.Number) online (Size: $([math]::Round($_.Size/1GB, 2))GB)"
        Set-Disk -Number $_.Number -IsOffline $false
    }

    # Process each available disk
    foreach ($disk in $availableDisks) {
        $diskNumber = $disk.Number
        $diskSize = [math]::Round($disk.Size/1GB, 2)

        # Check if disk already has any partitions (regardless of partition style)
        $existingPartitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue | Where-Object { $_.Type -in @('Basic', 'Primary', 'Extended', 'Logical') }
        if ($existingPartitions.Count -gt 0) {
            Write-Host "STATUS: Disk $diskNumber already has $($existingPartitions.Count) partition(s) ($($disk.PartitionStyle)) - skipping initialization"
            $skippedDisks++
            continue
        }

        # Initialize RAW disks only
        if ($disk.PartitionStyle -eq 'RAW') {
            try {
                $partitionStyle = if ($disk.Size -gt 2TB) { "GPT" } else { "MBR" }

                # Check if this is an ephemeral drive (instance store) vs EBS
                $serialNumber = $disk.SerialNumber
                if ($serialNumber -and $serialNumber.StartsWith('AWS')) {
                    Write-Host "STATUS: Initializing instance store disk $diskNumber (${diskSize}GB) with $partitionStyle as 'Ephemeral'"
                    $volumeLabel = "Ephemeral"
                } else {
                    Write-Host "STATUS: Initializing EBS disk $diskNumber (${diskSize}GB) with $partitionStyle as 'Data'"
                    $volumeLabel = "Data"
                }

                $partition = $disk | Initialize-Disk -PartitionStyle $partitionStyle -PassThru |
                            New-Partition -AssignDriveLetter -UseMaximumSize

                if (-not $partition.DriveLetter) {
                    Write-Host "ERROR: Failed to assign drive letter to disk $diskNumber"
                    $failedDisks++
                    continue
                }

                $driveLetter = $partition.DriveLetter
                Write-Host "STATUS: Formatting drive ${driveLetter}: (${diskSize}GB) as '$volumeLabel'"

                Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel $volumeLabel -Confirm:$false | Out-Null

                Write-Host "SUCCESS: Disk $diskNumber initialized as ${driveLetter}: '$volumeLabel' (${diskSize}GB)"
                $processedDisks++

            } catch {
                Write-Host "ERROR: Failed to initialize disk $diskNumber - $($_.Exception.Message)"
                $failedDisks++
            }
        } else {
            Write-Host "STATUS: Disk $diskNumber already initialized ($($disk.PartitionStyle)) - skipping"
            $skippedDisks++
        }
    }

    # Extend existing partitions to use full disk space
    Write-Host "STATUS: Extending partitions to use full disk space..."
    $extendedPartitions = Invoke-VolumeExtension

    # Restart ShellHWDetection service
    Start-Service -Name ShellHWDetection -ErrorAction SilentlyContinue

} catch {
    Write-Host "ERROR: Disk processing failed - $($_.Exception.Message)"
    exit $EXIT_GENERAL_FAILURE
}

# Report volume changes
if ($removedVolumes.Count -gt 0) {
    Write-Host "WARNING: Volume removal detected - manual cleanup recommended:"
    foreach ($removed in $removedVolumes) {
        Write-Host "  - Volume '$($removed.VolumeName)' ($($removed.DeviceName)) was removed from configuration"
        Write-Host "    Manual action: Check Windows Disk Management for orphaned drive letters"
    }
}

# Report final status
Write-Host "STATUS: Volume management summary:"
Write-Host "  - New volumes processed: $processedDisks"
Write-Host "  - Existing volumes skipped: $skippedDisks"
Write-Host "  - Failed initializations: $failedDisks"
Write-Host "  - Partitions extended: $extendedPartitions"
Write-Host "  - Volumes added: $($addedVolumes.Count)"
Write-Host "  - Volumes removed: $($removedVolumes.Count)"

# List all current volumes
Write-Host "STATUS: Current volume configuration:"
try {
    $dataDisks = Get-Disk | Where-Object { $_.Number -ne 0 -and $_.PartitionStyle -ne 'RAW' }
    foreach ($disk in $dataDisks) {
        $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq 'Basic' -and $_.DriveLetter }
        foreach ($partition in $partitions) {
            try {
                $volume = Get-Volume -DriveLetter $partition.DriveLetter
                $sizeGB = [math]::Round($partition.Size/1GB, 2)
                Write-Host "  - Drive $($partition.DriveLetter): '$($volume.FileSystemLabel)' (${sizeGB}GB)"
            } catch {
                Write-Host "  - Drive $($partition.DriveLetter): Unable to read volume info"
            }
        }
    }
} catch {
    Write-Host "WARNING: Could not enumerate volumes - $($_.Exception.Message)"
}

# Save current configuration for next run
try {
    $currentConfig = @{
        VolumeHash = $VolumeHash
        VolumeMapping = $volumeMap
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } | ConvertTo-Json

    New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
    Set-Content -Path $previousConfigFile -Value $currentConfig -Force
    Write-Host "STATUS: Current configuration saved for change detection"
} catch {
    Write-Host "WARNING: Could not save current configuration - $($_.Exception.Message)"
}

# Only create completion marker if no failures occurred
if ($failedDisks -eq 0) {
    try {
        $markerContent = @{
            VolumeHash = $VolumeHash
            CompletedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            VolumeCount = $expectedVolumeCount
            ProcessedDisks = $processedDisks
            SkippedDisks = $skippedDisks
            ExtendedPartitions = $extendedPartitions
        } | ConvertTo-Json

        Set-Content -Path $markerFile -Value $markerContent -Force
        Write-Host "SUCCESS: Volume configuration marked as complete"
    } catch {
        Write-Host "WARNING: Could not create completion marker - $($_.Exception.Message)"
    }

    Write-StatusLog "Volume management completed successfully - $processedDisks processed, $skippedDisks skipped, $extendedPartitions extended" "SUCCESS"
    exit $EXIT_SUCCESS
} else {
    Write-StatusLog "Volume management FAILED - $failedDisks failures out of $($availableDisks.Count) disks" "ERROR"
    exit $EXIT_FORMAT_FAILED
}
