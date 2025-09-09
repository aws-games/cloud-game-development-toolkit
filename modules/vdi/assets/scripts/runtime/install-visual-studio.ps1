# Install Visual Studio 2022 Community via Chocolatey
param(
    [string]$LogGroup = "/aws/cgd-dev/installation"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Installing Visual Studio 2022..."
    
    # Install via Chocolatey with game development workload
    choco install visualstudio2022community --params "--add Microsoft.VisualStudio.Workload.NativeGame --add Microsoft.VisualStudio.Workload.ManagedGame" -y
    
    Write-Host "Visual Studio 2022 installation completed successfully"
    
    # Log to CloudWatch
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "visual-studio-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Visual Studio 2022 installed successfully"
    
    exit 0
} catch {
    Write-Error "Visual Studio installation failed: $_"
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "visual-studio-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Visual Studio 2022 installation failed: $_"
    exit 1
}