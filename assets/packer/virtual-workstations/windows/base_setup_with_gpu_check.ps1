# ====================================
# Base Setup Script with GPU Detection
# ====================================

# Simple console logging function
function Write-Status {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with color based on level for immediate feedback
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
}

try {
    # =============
    # GPU DETECTION
    # =============

    # Check if GPU is present using PCI devices
    Write-Status "Checking for GPU hardware..."
    $gpuPresent = $false
    $devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.DeviceID -like "*VEN_10DE*" }
    
    if ($devices) {
        $gpuPresent = $true
        Write-Status "Found NVIDIA GPU" -Level "SUCCESS"
    } else {
        Write-Status "No NVIDIA GPU found. Virtual display driver for DCV will be installed." -Level "WARNING"
    }
    
    # ==================
    # INSTALL AMAZON DCV
    # ==================
    
    Write-Status "Installing Amazon DCV..."
    $dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
    $dcvInstaller = "$env:TEMP\nice-dcv-installer.msi"
    $listenPort = 8443

    # Download and install DCV server
    Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvInstaller -UseBasicParsing
    Start-Process "msiexec.exe" -ArgumentList "/i `"$dcvInstaller`" ADDLOCAL=ALL /quiet /norestart" -Wait
    Write-Status "DCV server installed" -Level "SUCCESS"

    # Install virtual display driver if no GPU is present
    if (-not $gpuPresent) {
        Write-Status "No GPU detected. Installing DCV virtual display driver..."
        $virtualDisplayUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-virtual-display-x64-Release.msi"
        $virtualDisplayInstaller = "$env:TEMP\nice-dcv-virtual-display-x64-Release.msi"
        
        Invoke-WebRequest -Uri $virtualDisplayUrl -OutFile $virtualDisplayInstaller -UseBasicParsing
        Start-Process "msiexec.exe" -ArgumentList "/i `"$virtualDisplayInstaller`" ADDLOCAL=ALL /quiet /norestart" -Wait
        Write-Status "Virtual display driver installed" -Level "SUCCESS"
        
        # Clean up installer file
        Remove-Item -Path $virtualDisplayInstaller -Force -ErrorAction SilentlyContinue
    }
    
    # Configure DCV registry settings
    Write-Status "Configuring DCV registry settings for Administrator user..."
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management" /v create-session /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v owner /t REG_SZ /d "Administrator" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v storage-root /t REG_SZ /d "%home%" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v enable-quic-frontend /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v web-port /t REG_DWORD /d $listenPort /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v quic-port /t REG_DWORD /d $listenPort /f

    # Restart DCV service to apply changes
    Write-Status "Restarting DCV service to apply configuration changes..."
    Restart-Service -Name dcvserver -Force
    
    # Clean up installer file
    if (Test-Path $dcvInstaller) {
        Remove-Item -Path $dcvInstaller -Force
    }

    Write-Status "DCV installation and configuration completed" -Level "SUCCESS"

    # ===========================
    # INSTALL NVIDIA GRID DRIVERS
    # ===========================
    
    # Only attempt to install drivers if GPU is present
    if ($gpuPresent) {
        Write-Status "Installing NVIDIA GRID drivers for GPU instance..."
        
        # Install AWS.Tools.S3 module directly
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module -Name AWS.Tools.S3 -Force -Scope CurrentUser -AllowClobber
        Import-Module AWS.Tools.S3
        
        # Download and install the drivers
        $Bucket = "ec2-windows-nvidia-drivers"
        $KeyPrefix = "latest"
        $LocalPath = "C:\temp\drivers"
        
        $Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1
        
        foreach ($Object in $Objects) {
            if ($Object.Key -ne '' -and $Object.Size -ne 0) {
                $LocalFilePath = Join-Path $LocalPath $Object.Key
                Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $LocalFilePath -Region us-east-1
            }
        }
        
        # Find and install the driver
        $gridDriverPath = Get-ChildItem -Path $LocalPath -Filter "*.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        if ($gridDriverPath) {
            Start-Process -FilePath $gridDriverPath -ArgumentList "/s" -Wait -PassThru -NoNewWindow
            Write-Status "NVIDIA GRID driver installation completed" -Level "SUCCESS"
            
            # Configure GRID licensing for workstation features
            reg add "HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\GridLicensing" /v FeatureType /t REG_DWORD /d 1 /f
            reg add "HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\GridLicensing" /v IgnoreSP /t REG_DWORD /d 1 /f
        }
    }
    else {
        Write-Status "No NVIDIA GPU detected. Skipping driver installation." -Level "INFO"
    }

    # ======================================
    # SYSPREP CONFIGURATION FOR GRID DRIVERS
    # ======================================
    
    Write-Status "Configuring Sysprep for driver persistence..."
    
    # Create EC2Launch config directory
    $ec2LaunchV2Dir = "C:\ProgramData\Amazon\EC2Launch\config"
    New-Item -Path $ec2LaunchV2Dir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    
    # Create agent-config.yml with driver persistence enabled
    $agentYml = @"
# EC2Launch v2 agent configuration
version: 1.0
config:
  name: WindowsServerAMI
  initializeSystem: true
  setComputerName: false
  setWallpaper: true
  addDnsSuffixList: true
  extendBootVolumeSize: true
  handleUserData: true
  adminPasswordType: Random
  configSsmAgent: true
  persistDrivers: true
"@
    Set-Content -Path "$ec2LaunchV2Dir\agent-config.yml" -Value $agentYml
    
    # Create sysprep directory and Unattend.xml
    New-Item -Path "$ec2LaunchV2Dir\sysprep" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    
    $unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="generalize">
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
            <DoNotCleanUpNonPresentDevices>true</DoNotCleanUpNonPresentDevices>
        </component>
    </settings>
</unattend>
"@
    Set-Content -Path "$ec2LaunchV2Dir\sysprep\Unattend.xml" -Value $unattendXml
    
    Write-Status "Sysprep configuration completed" -Level "SUCCESS"

    Write-Status "Setup completed successfully" -Level "SUCCESS"
}
catch {
    Write-Status "Script execution failed: $_" -Level "ERROR"
    throw
}