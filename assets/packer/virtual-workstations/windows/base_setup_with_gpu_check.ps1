# This script handles core system setup, AWS tools, and GPU driver installation

# Set vars for installation locations
$driveLetter = "C:"
$tempDir = "temp"
$installationDir = "CGD-Workstation-Tools"

# Create temp directory for script logging
New-Item -ItemType Directory -Force -Path "$driveLetter\temp"

# Start transcript to write script logs to a file
Start-Transcript -Path "$driveLetter\$tempDir\cgd-workstation-config.txt" -Force -Verbose

try {
    # System information
    Write-Host "Starting Windows Workstation Setup"
    Write-Host "Computer Name: $env:COMPUTERNAME"
    Write-Host "Windows Version: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
    Write-Host "Current User: $env:USERNAME"

    # Create installation directory
    if (-not (Test-Path "$driveLetter\$installationDir")) {
        New-Item -ItemType Directory -Path "$driveLetter\$installationDir" -Force
    }
    Write-Host "Created installation directory: $driveLetter\$installationDir"

    # - GENERAL SETUP -
    # Metadata retrieval
    Write-Host "Retrieving EC2 instance metadata..."
    $token = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/api/token" -Method PUT -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"="21600"} -UseBasicParsing).Content
    $instanceId = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Headers @{"X-aws-ec2-metadata-token"=$token} -UseBasicParsing).Content
    $region = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/placement/region" -Headers @{"X-aws-ec2-metadata-token"=$token} -UseBasicParsing).Content

    Write-Host "Instance ID: $instanceId"
    Write-Host "Region: $region"

    # - CONFIGURE SSM FOR CONNECTIVITY -
    Write-Host "Configuring SSM service..."
    Set-Service AmazonSSMAgent -StartupType Automatic
    Start-Service AmazonSSMAgent
    Write-Host "SSM service configured"

    # - INSTALL AWS CLI -
    Write-Host "Installing AWS CLI..."
    $installerPath = "$env:TEMP\AWSCLIV2.msi"
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installerPath
    Start-Process msiexec.exe -Wait -ArgumentList "/i $installerPath /quiet"

    if (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") {
        Write-Host "AWS CLI installed successfully"
    } else {
        Write-Warning "AWS CLI installation could not be verified"
    }

    # - Delete installer after installation -
    Remove-Item $installerPath -ErrorAction SilentlyContinue
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # - INSTALL CHOCOLATEY -
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    choco install --no-progress -y vcredist140
    [Environment]::SetEnvironmentVariable("AWS_CLI_AUTO_PROMPT", "on-partial", "Machine")

    # Wait for Chocolatey to finish installing
    Start-Sleep -Seconds 10

    # Use full path to choco
    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (Test-Path $chocoPath) {
        Write-Host "Chocolatey installed successfully"
        # Install Visual C++ Redistributable
        & $chocoPath install --no-progress -y vcredist140
        Write-Host "Visual C++ Redistributable installed"
    } else {
        Write-Warning "Chocolatey installation could not be verified"
    }

    # - INSTALL OPENSSH SERVER -
    Write-Host "Installing OpenSSH Server..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Set-Service -Name sshd -StartupType 'Automatic'
    Start-Service sshd

    $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($sshService -and $sshService.Status -eq 'Running') {
        Write-Host "OpenSSH Server installed and running"
    } else {
        Write-Warning "OpenSSH Server installation could not be verified"
    }

    # - INSTALL NFS CLIENT -
    Write-Host "Installing NFS Client feature..."

    # Install NFS Client Windows feature
    $nfsclient = Install-WindowsFeature -Name NFS-Client

    if ($nfsclient.Success) {
        Write-Host "NFS Client feature installed successfully"
        Write-Host "Reboot required: $($nfsclient.RestartNeeded)"

        # Configure NFS client settings for better performance with Unix/Linux NFS servers
        Write-Host "Configuring NFS client settings..."

        # Enable case sensitivity in NFS
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default" -Name "CaseSensitive" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        # Use NFS v3 by default (more widely compatible)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default" -Name "UseReservedPorts" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        # Restart the NFS client service to apply changes
        Restart-Service NfsClnt -Force -ErrorAction SilentlyContinue
    } else {
        Write-Error "NFS Client feature installation failed"
    }

    # - INSTALL AMAZON DCV -
    Write-Host "Installing Amazon DCV..."
    $dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
    $dcvInstaller = "$driveLetter\$installationDir\nice-dcv-installer.msi"
    $listenPort = 8443

    Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvInstaller -UseBasicParsing
    Start-Process "msiexec.exe" -ArgumentList "/i `"$dcvInstaller`" ADDLOCAL=ALL /quiet /norestart" -Wait

    # Configure DCV registry settings
    Write-Host "Configuring DCV registry settings..."
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management" /v create-session /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v owner /t REG_SZ /d "administrator" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v storage-root /t REG_SZ /d "C:/Users/Administrator/" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v enable-quic-frontend /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v web-port /t REG_DWORD /d $listenPort /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v quic-port /t REG_DWORD /d $listenPort /f
    reg.exe add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v web-client-max-head-resolution /t REG_SZ /d "(0, 0)" /f
    reg.exe add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v console-session-default-layout /t REG_SZ /d "[{'w':1920, 'h':1080, 'x':0, 'y':0}]" /f

    Write-Host "DCV installation and configuration completed"

    # - GPU DETECTION AND DRIVER INSTALLATION -
    # Define driver type variable
    $driverType = "NVIDIA-Tesla"

    # Check if GPU is present using Win32_VideoController
    Write-Host "Checking for GPU hardware..."
    $gpuPresent = $false
    if (-not $gpuPresent) {
        Write-Host "checking PCI devices for Nvidia devices..."
        $devices = Get-WmiObject Win32_PnPEntity
        foreach ($device in $devices) {
            # NVIDIA GPUs have a specific vendor ID: VEN_10DE
            if ($device.DeviceID -like "*VEN_10DE*") {
                $gpuPresent = $true
                Write-Host "Found NVIDIA GPU via DeviceID: $($device.Name) [$($device.DeviceID)]" -ForegroundColor Green
                break
            }
        }
    }

    # Create directory structure if it doesn't exist
    $LocalPathDrivers = "$driveLetter\$installationDir\Drivers"
    if (-not (Test-Path $LocalPathDrivers)) {
        New-Item -ItemType Directory -Path $LocalPathDrivers -Force
    }

    # Only attempt to install drivers if GPU is present
    if ($gpuPresent) {
        Write-Host "This AMI will be optimized for GPU instances"

        # Install drivers based on type
        switch ($driverType) {
            "NVIDIA-Tesla" {
                Write-Host "Installing NVIDIA Tesla drivers..."

                # Define URLs for Tesla driver versions
                $teslaUrls = @(
                    "https://us.download.nvidia.com/tesla/573.39/573.39-data-center-tesla-desktop-winserver-2022-2025-dch-international.exe"
                )

                $driverDownloaded = $false
                foreach ($url in $teslaUrls) {
                    try {
                        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -ErrorAction SilentlyContinue
                        if ($response.StatusCode -eq 200) {
                            $teslaDriverInstaller = "$LocalPathDrivers\nvidia-tesla-driver.exe"
                            Invoke-WebRequest -Uri $url -OutFile $teslaDriverInstaller
                            Start-Process $teslaDriverInstaller -ArgumentList "/s" -Wait
                            $driverDownloaded = $true
                            break
                        }
                    }
                    catch { }
                }

                if (-not $driverDownloaded) {
                    Write-Warning "Failed to download any Tesla driver version"
                }

                # Create completion marker
                "NVIDIA driver installation completed at $(Get-Date)" | Out-File -FilePath "$LocalPathDrivers\nvidia-install-complete.txt"

                # Install Nvidia Desktop Manager if applicable
                try {
                    Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*NVIDIAControlPanel*"} | Remove-AppxPackage -AllUsers
                    Add-AppxPackage -Register "C:\Program Files\WindowsApps\NVIDIACorp.NVIDIAControlPanel_*\AppxManifest.xml" -DisableDevelopmentMode -ErrorAction SilentlyContinue
                }
                catch { }
            }
        }
    } else {
        Write-Warning "No NVIDIA GPU detected. Skipping driver installation."
    }

    Write-Host "Setup completed successfully at $(Get-Date)"
}
catch {
    Write-Error "Script execution failed: $_"
    throw
}
finally {
    if (Get-Command Stop-Transcript -ErrorAction SilentlyContinue) {
        try { Stop-Transcript } catch { }
    }
}
