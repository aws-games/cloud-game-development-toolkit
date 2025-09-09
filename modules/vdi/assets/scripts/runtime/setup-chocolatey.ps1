# Setup Chocolatey package manager
param(
    [string]$LogGroup = "/aws/cgd-dev/installation"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Setting up Chocolatey..."
    
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "Chocolatey setup completed successfully"
    
    # Log to CloudWatch
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "chocolatey-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Chocolatey installed successfully"
    
    exit 0
} catch {
    Write-Error "Chocolatey setup failed: $_"
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "chocolatey-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Chocolatey setup failed: $_"
    exit 1
}