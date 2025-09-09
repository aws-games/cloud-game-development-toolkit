# Install Git via Chocolatey
param(
    [string]$LogGroup = "/aws/cgd-dev/installation"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Installing Git..."
    
    choco install git -y
    
    Write-Host "Git installation completed successfully"
    
    # Log to CloudWatch
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "git-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Git installed successfully"
    
    exit 0
} catch {
    Write-Error "Git installation failed: $_"
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "git-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Git installation failed: $_"
    exit 1
}