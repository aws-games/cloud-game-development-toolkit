# Install Perforce Client Tools via Chocolatey
param(
    [string]$LogGroup = "/aws/cgd-dev/installation"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Installing Perforce client tools..."
    
    # Install P4 command line client
    choco install perforce -y
    
    # Install P4V visual client
    choco install p4v -y
    
    # Install P4Admin (if available via chocolatey, otherwise download directly)
    try {
        choco install p4admin -y
    } catch {
        Write-Host "P4Admin not available via Chocolatey, downloading directly..."
        $p4adminUrl = "https://cdist2.perforce.com/perforce/r23.2/bin.ntx64/p4admin.exe"
        Invoke-WebRequest -Uri $p4adminUrl -OutFile "C:\Program Files\Perforce\p4admin.exe"
    }
    
    Write-Host "Perforce client tools installation completed successfully"
    
    # Log to CloudWatch
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "perforce-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Perforce client tools installed successfully"
    
    exit 0
} catch {
    Write-Error "Perforce installation failed: $_"
    aws logs put-log-events --log-group-name $LogGroup --log-stream-name "perforce-$(Get-Date -Format 'yyyy-MM-dd')" --log-events timestamp=$(Get-Date -UFormat %s),message="Perforce installation failed: $_"
    exit 1
}