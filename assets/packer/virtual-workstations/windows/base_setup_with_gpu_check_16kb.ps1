<powershell>
# Create log directory first thing
Write-Output "Creating log directory..."
New-Item -ItemType Directory -Force -Path "C:\temp"

# Write directly to a log file since transcript might fail
$logFile = "C:\temp\setup-log.txt"
"Setup started at $(Get-Date)" | Out-File -FilePath $logFile

try {
    # Install AWS CLI
    "Installing AWS CLI..." | Out-File -FilePath $logFile -Append
    $installerPath = "$env:TEMP\AWSCLIV2.msi"
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installerPath -UseBasicParsing
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$installerPath`" /quiet /norestart"
    Remove-Item $installerPath -ErrorAction SilentlyContinue

    # Verify AWS CLI installation
    if (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") {
        "AWS CLI installed successfully" | Out-File -FilePath $logFile -Append
    } else {
        "AWS CLI installation could not be verified" | Out-File -FilePath $logFile -Append
    }

    # Install Chocolatey
    "Installing Chocolatey..." | Out-File -FilePath $logFile -Append
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Wait for Chocolatey to finish installing
    Start-Sleep -Seconds 10

    # Use full path to choco
    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (Test-Path $chocoPath) {
        "Chocolatey installed successfully" | Out-File -FilePath $logFile -Append
        # Install packages with Chocolatey
        & $chocoPath install --no-progress -y vcredist140
        "Visual C++ Redistributable installed" | Out-File -FilePath $logFile -Append
    } else {
        "Chocolatey installation could not be verified" | Out-File -FilePath $logFile -Append
    }

    # Create installation directory
    "Creating installation directory..." | Out-File -FilePath $logFile -Append
    New-Item -ItemType Directory -Force -Path "C:\CGD-Workstation-Tools"

    # Install Amazon DCV
    "Installing Amazon DCV..." | Out-File -FilePath $logFile -Append
    $dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
    $dcvInstaller = "C:\CGD-Workstation-Tools\nice-dcv-installer.msi"

    Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvInstaller -UseBasicParsing
    Start-Process "msiexec.exe" -ArgumentList "/i `"$dcvInstaller`" ADDLOCAL=ALL /quiet /norestart" -Wait

    # Configure DCV registry settings
    "Configuring DCV registry settings..." | Out-File -FilePath $logFile -Append
    $listenPort = 8443
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management" /v create-session /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v owner /t REG_SZ /d "administrator" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management\automatic-console-session" /v storage-root /t REG_SZ /d "C:/Users/Administrator/" /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v enable-quic-frontend /t REG_DWORD /d 1 /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v web-port /t REG_DWORD /d $listenPort /f
    reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v quic-port /t REG_DWORD /d $listenPort /f
    reg.exe add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v web-client-max-head-resolution /t REG_SZ /d "(0, 0)" /f
    reg.exe add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v console-session-default-layout /t REG_SZ /d "[{'w':<1920>, 'h':<1080>, 'x':<0>, 'y': <0>}]" /f

    "Setup completed successfully at $(Get-Date)" | Out-File -FilePath $logFile -Append

    # Install NVIDIA drivers directly
    "Installing NVIDIA drivers..." | Out-File -FilePath $logFile -Append

    # Create drivers directory
    New-Item -ItemType Directory -Force -Path "C:\CGD-Workstation-Tools\Drivers"

    # Check for NVIDIA GPU
    $gpuInfo = Get-WmiObject Win32_VideoController | Select-Object Name
    "Detected video controllers: $($gpuInfo | Out-String)" | Out-File -FilePath $logFile -Append

    # Download NVIDIA driver
    "Downloading NVIDIA driver..." | Out-File -FilePath $logFile -Append
    $driverUrl = "https://us.download.nvidia.com/tesla/576.57/576.57-data-center-tesla-desktop-winserver-2022-2025-dch-international.exe"
    $driverFile = "C:\CGD-Workstation-Tools\Drivers\nvidia-driver.exe"

    try {
        Invoke-WebRequest -Uri $driverUrl -OutFile $driverFile -UseBasicParsing
        "Driver downloaded successfully" | Out-File -FilePath $logFile -Append

        # Install NVIDIA driver
        "Installing NVIDIA driver..." | Out-File -FilePath $logFile -Append
        Start-Process $driverFile -ArgumentList "/s" -Wait
        "NVIDIA driver installation completed" | Out-File -FilePath $logFile -Append
    }
    catch {
        "Error downloading/installing NVIDIA driver: $_" | Out-File -FilePath $logFile -Append
    }

    "All setup tasks completed, restarting in 60 seconds..." | Out-File -FilePath $logFile -Append
    shutdown /r /t 60 /f
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
}
</powershell>

