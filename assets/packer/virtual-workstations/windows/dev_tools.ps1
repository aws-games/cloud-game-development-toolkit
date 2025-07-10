# Development Tools Installation Script for Windows Workstations
# This script installs various development tools and IDEs

# Set vars for installation locations
$driveLetter = "C:"
$tempDir = "temp"
$installationDir = "CGD-Workstation-Tools"
$toolsDir = "$driveLetter\$installationDir\DevTools"

# Create temp directory for script logging
New-Item -ItemType Directory -Force -Path "$driveLetter\temp"

# Start transcript to write script logs to a file
Start-Transcript -Path "$driveLetter\$tempDir\dev-tools-install.txt" -Force -Verbose

try {
    # System information
    Write-Host "Starting Development Tools Installation"
    Write-Host "Computer Name: $env:COMPUTERNAME"
    Write-Host "Windows Version: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
    Write-Host "Current User: $env:USERNAME"

    # Create tools directory if it doesn't exist
    if (-not (Test-Path -Path $toolsDir)) {
        New-Item -ItemType Directory -Force -Path $toolsDir
        Write-Host "Created tools directory: $toolsDir"
    }

    # Set path to choco executable
    $chocoPath = "$env:ProgramData\chocolatey\bin\choco.exe"
    if (Test-Path $chocoPath) {
        Write-Host "Using Chocolatey from: $chocoPath"
    } else {
        throw "Chocolatey not found. Cannot proceed with installations."
    }

    # ===================================
    # IDE and Development Tools
    # ===================================

    # Visual Studio Community
    Write-Host "Installing Visual Studio 2022 Community and Build Tool..."
    & $chocoPath install -y --no-progress visualstudio2022community --package-parameters "--passive --locale en-US --add  --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCrossPlat --add Microsoft.VisualStudio.Component.VC.DiagnosticTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Microsoft.VisualStudio.Component.Windows10SDK.18362 --add Component.Unreal"

    # Windows Development Kit
    Write-Host "Installing Windows Development Kit..."
    $WDK_DOWNLOAD_LINK = "https://go.microsoft.com/fwlink/?linkid=2320455"
    $WDK_DESTINATION = "$toolsDir\wdksetup.exe"

    Invoke-WebRequest -Uri $WDK_DOWNLOAD_LINK -OutFile $WDK_DESTINATION
    Start-Process -FilePath $WDK_DESTINATION -ArgumentList "/q" -Wait -PassThru

    Write "Windows Development Kit Installed successfully."

    # ===================================
    # Source Control
    # ===================================

    # Git installation
    Write-Host "Installing Git..."
    & $chocoPath install -y --no-progress git --params "/GitAndUnixToolsOnPath /WindowsTerminal /NoShellIntegration"

    # Refresh environment variables to get Git in the path
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Perforce (P4) client installation
    Write-Host "Installing Perforce (P4) client..."
    & $chocoPath install -y --no-progress p4

    # Refresh environment variables to get P4 in the path
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # ===================================
    # Languages and Frameworks
    # ===================================

    # Python
    Write-Host "Installing Python and AWS libraries..."
    & $chocoPath install -y --no-progress python

    # Refresh environment to get Python in the path
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # INSTALL AWS CLI
    Write-Host "Installing AWS CLI..."
    $installerPath = "$env:TEMP\AWSCLIV2.msi"
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installerPath
    Start-Process msiexec.exe -Wait -ArgumentList "/i $installerPath /quiet"

    if (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") {
        Write-Host "AWS CLI installed successfully"
    } else {
        Write-Warning "AWS CLI installation could not be verified"
    }

    # - Delete installer after installation -
    Remove-Item $installerPath -ErrorAction SilentlyContinue
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Install AWS libraries
    Write-Host "Installing Python AWS libraries..."
    & pip install --no-warn-script-location botocore boto3
    
    # Store EC2 admin password in AWS Secrets Manager
    Write-Host "Storing EC2 admin password in AWS Secrets Manager..."
    try {
        # Get instance ID from instance metadata service
        $instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id"
        
        # Get AMI ID from instance metadata service
        $amiId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/ami-id"
        
        # Create a secret name using the specified naming convention
        $secretName = "cgdt-workshop-admin-password-$amiId"
        
        # Get password from Packer build environment
        # Packer passes the password as PACKER_PASSWORD environment variable
        $adminPassword = $env:PACKER_PASSWORD
        if (-not $adminPassword) {
            Write-Warning "Admin password not found in PACKER_PASSWORD environment variable. Attempting to retrieve from other sources."
            # Try to retrieve from elevated_password parameter if available
            if ($args.Length -gt 0) {
                $adminPassword = $args[0]
            }
        }
        
        # Create JSON structure for the secret
        $secretValue = @{
            "password" = $adminPassword
            "username" = "Administrator"
            "created_date" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            "instance_id" = $instanceId
        } | ConvertTo-Json
        
        # Validate password is not empty
        if (-not $adminPassword) {
            Write-Error "Unable to retrieve administrator password. Cannot store in Secrets Manager."
        } else {
            Write-Host "Retrieved administrator password successfully. Storing in AWS Secrets Manager..."
            
            # First try to create a new secret
            try {
                aws secretsmanager create-secret --name $secretName --secret-string $secretValue --description "Windows admin password for workshop AMI $amiId"
                Write-Host "Password stored successfully in AWS Secrets Manager as $secretName"
            } catch {
                # If creation fails, the secret might already exist, try to update it
                Write-Host "Failed to create secret, attempting to update existing secret: $_"
                try {
                    aws secretsmanager update-secret --secret-id $secretName --secret-string $secretValue --description "Windows admin password for workshop AMI $amiId"
                    Write-Host "Existing secret updated successfully in AWS Secrets Manager as $secretName"
                } catch {
                    Write-Error "Failed to update existing secret in AWS Secrets Manager: $_"
                }
            }
        }
    } catch {
        Write-Error "Failed during AWS Secrets Manager operation: $_"
        Write-Host "Error Details: $($_.Exception | Format-List -Force | Out-String)"
    }
} 
finally {
    if (Get-Command Stop-Transcript -ErrorAction SilentlyContinue) {
        try { Stop-Transcript } catch { }
    }
}
