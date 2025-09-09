# Lightweight Base Setup - GPU drivers, DCV, and essential components only
$ErrorActionPreference = "Stop"

Write-Host "Starting lightweight VDI base setup..."

# Install NVIDIA GRID drivers if GPU instance
$instanceType = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-type" -TimeoutSec 10)
if ($instanceType -match "^(g3|g4|g5|p2|p3|p4)") {
    Write-Host "GPU instance detected ($instanceType), installing NVIDIA GRID drivers..."
    
    # Download and install NVIDIA GRID drivers
    $gridDriverUrl = "https://ec2-windows-nvidia-drivers.s3.amazonaws.com/grid-12.2/462.31_grid_win10_server2016_server2019_64bit_AWS_SWL.exe"
    $driverPath = "C:\temp\nvidia-grid-driver.exe"
    
    New-Item -ItemType Directory -Force -Path C:\temp
    Invoke-WebRequest -Uri $gridDriverUrl -OutFile $driverPath
    
    Start-Process -FilePath $driverPath -ArgumentList "/s" -Wait
    Write-Host "NVIDIA GRID drivers installed"
} else {
    Write-Host "Non-GPU instance ($instanceType), skipping NVIDIA driver installation"
}

# Install DCV Server
Write-Host "Installing DCV Server..."
$dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
$dcvPath = "C:\temp\dcv-server.msi"

Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvPath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $dcvPath, "/quiet", "/norestart" -Wait

# Configure DCV
Write-Host "Configuring DCV Server..."
New-Item -ItemType Directory -Force -Path "C:\Program Files\NICE\DCV\Server\conf"

# Basic DCV configuration
@"
[session-management]
create-session = true

[session-management/defaults]
permissions-file = "C:\Program Files\NICE\DCV\Server\conf\default.pv"

[connectivity]
web-url-path = "/dcv"

[security]
authentication = "system"
"@ | Out-File -FilePath "C:\Program Files\NICE\DCV\Server\conf\dcv.conf" -Encoding ASCII

# DCV permissions file
@"
[permissions]
%any% allow builtin
"@ | Out-File -FilePath "C:\Program Files\NICE\DCV\Server\conf\default.pv" -Encoding ASCII

# Add DCV to system PATH
$dcvPath = "C:\Program Files\NICE\DCV\Server\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$dcvPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dcvPath", "Machine")
    Write-Host "Added DCV to system PATH"
}

# Configure DCV service (no session creation in Packer)
Set-Service -Name dcvserver -StartupType Automatic
Write-Host "DCV Server configured for automatic startup"
Write-Host "Note: DCV sessions will be created at runtime via user data"

# Install PowerShell modules for management
Write-Host "Installing PowerShell modules..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name AWS.Tools.Common -Force -AllowClobber
Install-Module -Name AWS.Tools.EC2 -Force -AllowClobber
Install-Module -Name AWS.Tools.SSM -Force -AllowClobber

Write-Host "Lightweight VDI base setup completed successfully"