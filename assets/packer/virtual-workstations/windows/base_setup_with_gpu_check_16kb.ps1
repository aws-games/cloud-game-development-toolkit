<powershell>
# Set vars for installation locations
$driveLetter = "C:"
$tempDir = "temp"
$installationDir = "CGD-Workstation-Tools"

# Create temp directory for script logging
New-Item -ItemType Directory -Force -Path "$driveLetter\temp"

try {
    # Start transcript to write script logs to a file
    Start-Transcript -Path "$driveLetter\$tempDir\cgd-workstation-config.txt" -Force

    # =============
    # GENERAL SETUP
    # =============

    # Metadata retrieval
    $token = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/api/token" -Method PUT -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"="21600"} -UseBasicParsing).Content
    $instanceId = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Headers @{"X-aws-ec2-metadata-token"=$token} -UseBasicParsing).Content
    $region = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/placement/region" -Headers @{"X-aws-ec2-metadata-token"=$token} -UseBasicParsing).Content

    # CONFIGURE SSM FOR CONNECTIVITY
    Set-Service AmazonSSMAgent -StartupType Automatic
    Start-Service AmazonSSMAgent

    # INSTALL GENERAL POWERSHELL TOOLS
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    # INSTALL AWS POWERSHELL TOOLS
    # Remove existing AWS modules if they exist
    Get-Module AWS.Tools.* | Remove-Module -Force -ErrorAction SilentlyContinue
    Get-Module AWS.Tools.* -ListAvailable | ForEach-Object {
        try { Uninstall-Module -Name $_.Name -AllVersions -Force -ErrorAction SilentlyContinue } catch { }
    }

    # Install AWS modules
    $latestVersion = (Find-Module -Name AWS.Tools.Common).Version
    $modules = @('AWS.Tools.Common', 'AWS.Tools.SecretsManager', 'AWS.Tools.EC2', 'AWS.Tools.S3')
    foreach ($module in $modules) {
        Install-Module $module -RequiredVersion $latestVersion -Force -AllowClobber
        Import-Module $module -RequiredVersion $latestVersion -Force
    }

    # INSTALL AWS CLI
    $installerPath = "$env:TEMP\AWSCLIV2.msi"
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installerPath
    Start-Process msiexec.exe -Wait -ArgumentList "/i $installerPath /quiet"
    Remove-Item $installerPath -ErrorAction SilentlyContinue
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # WINDOWS USER CONFIGURATION
    Initialize-AWSDefaultConfiguration
    $username = "Administrator"

    # ================================
    # ADDITIONAL SOFTWARE INSTALLATION
    # ================================

    # Install Chocolatey and packages
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    choco install --no-progress -y awscli vcredist140
    [Environment]::SetEnvironmentVariable("AWS_CLI_AUTO_PROMPT", "on-partial", "Machine")

    # =====================================
    # GPU DETECTION AND DRIVER INSTALLATION
    # =====================================

    $driverVersion = "573.07"
    $LocalPathDrivers = "$driveLetter\$installationDir\Drivers"
    if (-not (Test-Path "$driveLetter\$installationDir")) {
        New-Item -ItemType Directory -Path "$driveLetter\$installationDir" -Force
    }
    if (-not (Test-Path $LocalPathDrivers)) {
        New-Item -ItemType Directory -Path $LocalPathDrivers -Force
    }

    # Check if GPU is present
    $gpuPresent = $false
    $videoControllers = Get-WmiObject Win32_VideoController
    foreach ($controller in $videoControllers) {
        if ($controller.Name -like "*NVIDIA*") {
            $gpuPresent = $true
            break
        }
    }

    if ($gpuPresent) {
        # Install NVIDIA Tesla drivers
        $teslaUrls = @(
            "https://us.download.nvidia.com/tesla/$driverVersion/$driverVersion-data-center-tesla-desktop-winserver-2022-dch-international.exe",
            "https://us.download.nvidia.com/tesla/$driverVersion/$driverVersion-data-center-tesla-desktop-winserver-2019-2022-dch-international.exe"
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

        if ($driverDownloaded) {
            # Install Nvidia Desktop Manager
            try {
                Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*NVIDIAControlPanel*"} | Remove-AppxPackage -AllUsers
                Add-AppxPackage -Register "C:\Program Files\WindowsApps\NVIDIACorp.NVIDIAControlPanel_*\AppxManifest.xml" -DisableDevelopmentMode -ErrorAction SilentlyContinue
            }
            catch { }
        }
    }

    # INSTALL AMAZON DCV
    $dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
    $dcvInstaller = "$driveLetter\$installationDir\nice-dcv-installer.msi"
    $listenPort = 8443

    Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvInstaller
    Start-Process "msiexec.exe" -ArgumentList "/i `"$dcvInstaller`" ADDLOCAL=ALL /quiet /norestart" -Wait

    # Configure DCV registry settings
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management" /v create-session /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v owner /t REG_SZ /d "administrator" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v storage-root /t REG_SZ /d "C:/Users/Administrator/" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v enable-quic-frontend /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v web-port /t REG_DWORD /d $listenPort /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v quic-port /t REG_DWORD /d $listenPort /f
    reg.exe add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v web-client-max-head-resolution /t REG_SZ /d "(0, 0)" /f
    reg.exe add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v console-session-default-layout /t REG_SZ /d "[{'w':<1920>, 'h':<1080>, 'x':<0>, 'y': <0>}]" /f
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
</powershell>
