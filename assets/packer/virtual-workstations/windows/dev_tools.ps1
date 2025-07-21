# Sequential Development Tools Installation Script
# This script installs essential game development tools on Windows workstations

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
    # ===================
    # PREPARE ENVIRONMENT
    # ===================
    
    # Import the Chocolatey Profile that contains the necessary code to enable tab-completions to function for `choco`.
    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path($ChocolateyProfile)) {
        Import-Module "$ChocolateyProfile"
    }
    
    # ==================================
    # INSTALL CHOCOLATEY PACKAGE MANAGER
    # ==================================
    
    Write-Status "Installing Chocolatey package manager..."
    
    # Set security protocol to use TLS 1.2
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
    
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment path to include Chocolatey
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Status "Chocolatey installation completed" -Level "SUCCESS"

    # Configure Chocolatey for faster installations
    choco feature enable -n allowGlobalConfirmation
    choco feature disable -n showDownloadProgress

    # =================
    # DEV TOOLS INSTALL
    # =================
    
    Write-Status "Starting sequential installations for development tools..."
    
    # Visual Studio Community - Primary IDE for game development with C++/C# support
    Write-Status "Installing Visual Studio 2022 Community..."
    choco install -y --no-progress visualstudio2022community --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCrossPlat --add Microsoft.VisualStudio.Component.VC.DiagnosticTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Microsoft.VisualStudio.Component.Windows10SDK.18362 --add Component.Unreal"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Visual Studio 2022 Community installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Visual Studio 2022 Community installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }
    
    # # Windows Development Kit - Provides tools, headers, libraries, and samples for Windows development
    # Write-Status "Installing Windows Development Kit using Chocolatey..."
    # choco install -y --no-progress windows-sdk-10-version-2004-all
    
    # if ($LASTEXITCODE -eq 0) {
    #     Write-Status "Windows Development Kit installed successfully" -Level "SUCCESS"
    # }
    # else {
    #     Write-Status "Windows Development Kit installation failed with exit code: $LASTEXITCODE" -Level "WARNING"
    # }
    
    # Install Git
    Write-Status "Installing Git..."
    choco install -y --no-progress git --params="/GitAndUnixToolsOnPath /WindowsTerminal /NoShellIntegration"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Git installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Git installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }
    
    # Install Perforce Command Line Client (p4)
    Write-Status "Installing Perforce Command Line Client (p4)..."
    choco install -y --no-progress p4
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Perforce Command Line Client (p4) installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Perforce Command Line Client (p4) installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }
    
    # Install Perforce Visual Client (p4v)
    Write-Status "Installing Perforce Visual Client (p4v)..."
    choco install -y --no-progress p4v
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Perforce Visual Client (p4v) installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Perforce Visual Client (p4v) installation failed with exit code: $LASTEXITCODE" -Level "WARNING"
    }
    
    # Install Python
    Write-Status "Installing Python..."
    choco install -y --no-progress python3
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Python3 installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Python installation failed" -Level "ERROR"
    }
    
    # Install AWS CLI
    Write-Status "Installing AWS CLI..."
    choco install -y --no-progress awscli
    if ($LASTEXITCODE -eq 0) {
        Write-Status "AWS CLI installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "AWS CLI installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }
    
    Write-Status "Installing Python packages..."
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Install AWS Python libraries
    Write-Status "Installing AWS Python libraries..."
    python -m pip install --no-warn-script-location botocore boto3
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "AWS Python libraries installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Failed to install AWS Python libraries" -Level "WARNING"
    }

    Write-Status "Development tools installation completed" -Level "SUCCESS"
}
catch {
    Write-Status "Script execution failed: $_" -Level "ERROR"
    throw
}