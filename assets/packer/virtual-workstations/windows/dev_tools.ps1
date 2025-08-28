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

    # Refresh Chocolatey metadata
    Write-Status "Refreshing Chocolatey metadata..."
    choco upgrade chocolatey -y --no-progress

    # Configure Chocolatey for faster installations
    choco feature enable -n allowGlobalConfirmation
    choco feature disable -n showDownloadProgress

    # =================
    # DEV TOOLS INSTALL
    # =================

    Write-Status "Starting sequential installations for development tools..."

    # Visual Studio Community - Primary IDE for game development with required workloads and components for building on Unreal Engine
    # Workloads - Managed Desktop (.NET), Native Desktop (C++), .NET Cross-Platform Development
    # Components - Visual C++ Diagnostic Tools, Address Sanitizer, Windows 10 SDK (10.0.18362.0), Unreal Engine Component
    Write-Status "Installing Visual Studio 2022 Community and tools for building on Unreal Engine..."
    Write-Status "This installation may take 15-30 minutes. Please be patient..." -Level "WARNING"

    # Set longer timeout for Visual Studio installation (45 minutes)
    choco install -y visualstudio2022community --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCrossPlat --add Microsoft.VisualStudio.Component.VC.DiagnosticTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Microsoft.VisualStudio.Component.Windows10SDK.18362 --add Component.Unreal"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Visual Studio 2022 Community installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Visual Studio 2022 Community installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }

    # Install Git
    Write-Status "Installing Git..."
    choco install -y git --params="/GitAndUnixToolsOnPath /WindowsTerminal /NoShellIntegration"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Git installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Git installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }

    # Batch install of python3, AWS CLI, P4, and P4V
    Write-Status " Batch installing Python 3, AWS CLI, Perforce Server (P4) and Perforce Command Line Client (P4V)..."
    choco install -y --ignore-checksums python3 awscli p4 p4v
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Python 3, AWS CLI, Perforce Server (P4) and Perforce Command Line Client (P4V) installed successfully" -Level "SUCCESS"
    }
    else {
        Write-Status "Python 3, AWS CLI, Perforce Server (P4) and Perforce Command Line Client (P4V) installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
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
