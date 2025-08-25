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
    }
    else {
        Write-Status "No NVIDIA GPU found. Virtual display driver for DCV will be installed." -Level "WARNING"
    }

    # ==================
    # INSTALL AMAZON DCV
    # ==================

    Write-Status "Installing Amazon DCV..."
    $dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
    $dcvInstaller = "$env:TEMP\nice-dcv-installer.msi"

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

    # Configure DCV via Windows Registry
    Write-Status "Configuring DCV via Windows Registry..."

    # Set DCV authentication to system
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\security" /v authentication /t REG_SZ /d system /f

    # Configure session management
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management" /v create-session /t REG_DWORD /d 1 /f

    # Configure connectivity
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v web-port /t REG_DWORD /d 8443 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v quic-port /t REG_DWORD /d 8443 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v enable-quic-frontend /t REG_SZ /d true /f

    # Enable Windows Credentials Provider
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{8A2C93D0-D55F-4045-99D7-B27F5E263407}" /v Disabled /t REG_DWORD /d 0 /f

    Write-Status "DCV registry configuration completed" -Level "SUCCESS"

    # Restart DCV service to apply registry changes
    Write-Status "Restarting DCV service..."
    Restart-Service -Name dcvserver -Force
    Start-Sleep -Seconds 5

    # Delete any existing sessions
    & 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe' close-session console 2>$null
    Start-Sleep -Seconds 2

    # Create admin console session (owned by Administrator)
    & 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe' create-session --owner=Administrator admin-console 2>&1

    Write-Status "DCV session configuration completed" -Level "SUCCESS"

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

        # Install AWS.Tools.S3 module directly (suppress verbose output)
        Write-Status "Installing AWS PowerShell S3 tools for NVIDIA driver download..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Verbose:$false | Out-Null
        Install-Module -Name AWS.Tools.S3 -Force -Scope CurrentUser -AllowClobber -Verbose:$false | Out-Null
        Import-Module AWS.Tools.S3 -Verbose:$false

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
            Write-Status "Configuring NVIDIA GRID licensing..."
            $gridLicensingConfig = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\GridLicensing]
"FeatureType"=dword:00000001
"IgnoreSP"=dword:00000001
"@

            $gridRegFile = "$env:TEMP\nvidia-grid-config.reg"
            $gridLicensingConfig | Out-File -FilePath $gridRegFile -Encoding ASCII -Force
            Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$gridRegFile`"" -Wait -NoNewWindow
            Remove-Item -Path $gridRegFile -Force -ErrorAction SilentlyContinue

            Write-Status "NVIDIA GRID licensing configured" -Level "SUCCESS"
        }
    }
    else {
        Write-Status "No NVIDIA GPU detected. Skipping driver installation." -Level "INFO"
    }

    Write-Status "Setup completed successfully" -Level "SUCCESS"
}
catch {
    Write-Status "Script execution failed: $_" -Level "ERROR"
    throw
}
