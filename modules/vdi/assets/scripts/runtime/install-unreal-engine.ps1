# Install Unreal Engine 5.3 via Epic Games Launcher
param(
    [string]$LogGroup = "/aws/cgd-dev/installation"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Installing Epic Games Launcher..."
    
    # Install Epic Games Launcher first
    choco install epicgameslauncher -y
    
    Write-Host "Epic Games Launcher installed. Unreal Engine 5.3 must be installed manually through the launcher."
    Write-Host "Instructions: Open Epic Games Launcher > Unreal Engine > Library > Install Engine 5.3"
    
    # Log to CloudWatch
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "unreal-engine-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Epic Games Launcher installed - Unreal Engine 5.3 requires manual installation"
    
    exit 0
} catch {
    Write-Error "Epic Games Launcher installation failed: $_"
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "unreal-engine-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Epic Games Launcher installation failed: $_"
    exit 1
}