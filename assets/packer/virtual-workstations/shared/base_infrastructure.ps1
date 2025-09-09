# Shared Base Infrastructure Setup - All VDI AMIs
# NVIDIA drivers, DCV, AWS tools, and common development tools
$ErrorActionPreference = "Stop"

Write-Host "Starting shared VDI base infrastructure setup..."

# Install NVIDIA GRID drivers if GPU instance
$instanceType = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-type" -TimeoutSec 10)
if ($instanceType -match "^(g3|g4|g5|p2|p3|p4)") {
    Write-Host "GPU instance detected ($instanceType), installing NVIDIA GRID drivers..."
    
    # Install AWS.Tools.S3 module for NVIDIA driver download
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Verbose:$false | Out-Null
    Install-Module -Name AWS.Tools.S3 -Force -Scope CurrentUser -AllowClobber -Verbose:$false | Out-Null
    Import-Module AWS.Tools.S3 -Verbose:$false
    
    # Download latest NVIDIA GRID drivers from S3
    $Bucket = "ec2-windows-nvidia-drivers"
    $KeyPrefix = "latest"
    $LocalPath = "C:\temp\drivers"
    New-Item -ItemType Directory -Force -Path $LocalPath
    
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
    }
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

# Basic DCV configuration - no automatic session creation
@"
[session-management]
create-session = false

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

# Add DCV and NVIDIA tools to system PATH
$dcvPath = "C:\Program Files\NICE\DCV\Server\bin"
$nvidiaPath = "C:\Program Files\NVIDIA Corporation\NVSMI"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($currentPath -notlike "*$dcvPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dcvPath", "Machine")
    Write-Host "Added DCV to system PATH"
}

if ($currentPath -notlike "*$nvidiaPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dcvPath;$nvidiaPath", "Machine")
    Write-Host "Added NVIDIA tools to system PATH"
}

# Configure DCV service (no session creation in Packer)
Start-Sleep -Seconds 10  # Wait for service registration
Set-Service -Name dcvserver -StartupType Automatic
Write-Host "DCV Server configured for automatic startup"
Write-Host "Note: DCV sessions will be created at runtime via VDI module"

# Install and configure SSM Agent
Write-Host "Installing and configuring SSM Agent..."
try {
    # Download and install latest SSM Agent
    $ssmAgentUrl = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe"
    $ssmAgentPath = "C:\temp\AmazonSSMAgentSetup.exe"
    
    Invoke-WebRequest -Uri $ssmAgentUrl -OutFile $ssmAgentPath -TimeoutSec 300
    Start-Process -FilePath $ssmAgentPath -ArgumentList "/S" -Wait
    
    # Ensure SSM Agent service is configured properly
    Set-Service -Name AmazonSSMAgent -StartupType Automatic
    Start-Service -Name AmazonSSMAgent -ErrorAction SilentlyContinue
    
    Write-Host "SSM Agent installed and configured successfully"
} catch {
    Write-Host "SSM Agent installation failed: $_" -ForegroundColor Yellow
}

# Install AWS CLI
Write-Host "Installing AWS CLI..."
try {
    $awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $awsCliPath = "C:\temp\AWSCLIV2.msi"
    
    Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliPath -TimeoutSec 300
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $awsCliPath, "/quiet", "/norestart" -Wait
    
    # AWS CLI will be available in PATH automatically after installation
    
    Write-Host "AWS CLI installed successfully"
} catch {
    Write-Host "AWS CLI installation failed: $_" -ForegroundColor Yellow
}

# Install PowerShell modules for management
Write-Host "Installing PowerShell modules..."
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name AWS.Tools.Common -Force -AllowClobber
    Install-Module -Name AWS.Tools.EC2 -Force -AllowClobber  
    Install-Module -Name AWS.Tools.SimpleSystemsManagement -Force -AllowClobber
    Install-Module -Name AWS.Tools.SecretsManager -Force -AllowClobber
    Write-Host "PowerShell modules installed successfully"
} catch {
    Write-Host "PowerShell module installation failed: $_" -ForegroundColor Yellow
    Write-Host "Continuing without modules (non-critical)"
}

# Install Active Directory management tools (for admin use)
Write-Host "Installing Active Directory management tools..."
try {
    Install-WindowsFeature -Name RSAT-AD-PowerShell, RSAT-AD-Tools, RSAT-DNS-Server -IncludeAllSubFeature -ErrorAction Stop
    Write-Host "Active Directory management tools installed successfully"
} catch {
    Write-Host "AD tools installation failed: $_" -ForegroundColor Yellow
}

# Configure PowerShell profile for automatic module loading
$profilePath = "C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1"
New-Item -ItemType Directory -Force -Path (Split-Path $profilePath)
@"
# Auto-import AD module if available
if (Get-Module -ListAvailable ActiveDirectory) {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
}
"@ | Out-File -FilePath $profilePath -Encoding UTF8 -Force
Write-Host "Configured PowerShell profile for AD module auto-import"

# Install Chocolatey package manager
Write-Host "Installing Chocolatey package manager..."
try {
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Chocolatey will be available in PATH after installation
    
    # Configure Chocolatey for faster installations
    choco feature enable -n allowGlobalConfirmation
    choco feature disable -n showDownloadProgress
    
    Write-Host "Chocolatey installed successfully"
} catch {
    Write-Host "Chocolatey installation failed: $_" -ForegroundColor Yellow
}

# Install common development tools
Write-Host "Installing common development tools..."
try {
    # Install Git, Perforce, and Python in batch
    choco install -y git python3 p4 p4v --ignore-checksums
    
    Write-Host "Common development tools installed successfully"
} catch {
    Write-Host "Development tools installation failed: $_" -ForegroundColor Yellow
}

# Tools will be available in PATH automatically after installation

Write-Host "Shared VDI base infrastructure setup completed successfully"