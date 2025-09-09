# Lightweight Base Setup - GPU drivers, DCV, and essential components only
$ErrorActionPreference = "Stop"

Write-Host "Starting lightweight VDI base setup..."

# Install NVIDIA GRID drivers if GPU instance
$instanceType = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-type" -TimeoutSec 10)
if ($instanceType -match "^(g3|g4|g5|p2|p3|p4)") {
    Write-Host "GPU instance detected ($instanceType), installing NVIDIA GRID drivers..."
    
    # Download and install NVIDIA GRID drivers (latest available)
    $gridDriverUrl = "https://ec2-windows-nvidia-drivers.s3.amazonaws.com/grid-12.2/462.31_grid_win10_server2016_server2019_64bit_AWS_SWL.exe"
    $driverPath = "C:\temp\nvidia-grid-driver.exe"
    
    New-Item -ItemType Directory -Force -Path C:\temp
    Invoke-WebRequest -Uri $gridDriverUrl -OutFile $driverPath -TimeoutSec 600
    
    Start-Process -FilePath $driverPath -ArgumentList "/s" -Wait
    Write-Host "NVIDIA GRID drivers installed"
} else {
    Write-Host "Non-GPU instance ($instanceType), skipping NVIDIA driver installation"
}

# Install DCV Server (use AWS's latest redirect)
Write-Host "Installing DCV Server..."
$dcvUrl = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"
$dcvPath = "C:\temp\dcv-server.msi"

try {
    Invoke-WebRequest -Uri $dcvUrl -OutFile $dcvPath -TimeoutSec 300
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $dcvPath, "/quiet", "/norestart" -Wait
    Write-Host "DCV Server installed successfully"
} catch {
    Write-Host "Failed to install DCV Server: $_"
    throw
}

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
Start-Sleep -Seconds 10  # Wait for service registration
Set-Service -Name dcvserver -StartupType Automatic
Write-Host "DCV Server configured for automatic startup"
Write-Host "Note: DCV sessions will be created at runtime via user data"

# Install AWS CLI
Write-Host "Installing AWS CLI..."
try {
    $awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $awsCliPath = "C:\temp\AWSCLIV2.msi"
    
    Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliPath -TimeoutSec 300
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $awsCliPath, "/quiet", "/norestart" -Wait
    
    # Add AWS CLI to PATH
    $awsPath = "C:\Program Files\Amazon\AWSCLIV2"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$awsPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$awsPath", "Machine")
    }
    
    Write-Host "AWS CLI installed successfully"
} catch {
    Write-Host "AWS CLI installation failed: $_" -ForegroundColor Yellow
}

# Install PowerShell modules for management
Write-Host "Installing PowerShell modules..."
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
    Install-Module -Name AWS.Tools.Common -Force -AllowClobber -ErrorAction Stop
    Install-Module -Name AWS.Tools.EC2 -Force -AllowClobber -ErrorAction Stop
    Install-Module -Name AWS.Tools.SSM -Force -AllowClobber -ErrorAction Stop
    Install-Module -Name AWS.Tools.SecretsManager -Force -AllowClobber -ErrorAction Stop
    Write-Host "PowerShell modules installed successfully"
} catch {
    Write-Host "PowerShell module installation failed: $_" -ForegroundColor Yellow
    Write-Host "Continuing without modules (non-critical)"
}

Write-Host "Lightweight VDI base setup completed successfully"