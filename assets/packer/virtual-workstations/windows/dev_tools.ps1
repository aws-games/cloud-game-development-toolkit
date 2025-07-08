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
    Write-Host "Installing Visual Studio 2022 Community..."
    & $chocoPath install -y --no-progress visualstudio2022community --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.Data --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.Net.Component.4.8.SDK"

    # Visual Studio Build Tools
    Write-Host "Installing Visual Studio 2022 Build Tools..."
    & $chocoPath install -y --no-progress visualstudio2022buildtools --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools;includeRecommended --add Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64 --add Microsoft.Net.Component.4.6.2.TargetingPack"

    # Windows Development Kit
    Write-Host "Installing Windows Development Kit..."
    $WDK_DOWNLOAD_LINK = "https://go.microsoft.com/fwlink/?linkid=2320455"
    $WDK_DESTINATION = "$toolsDir\wdksetup.exe"

    Invoke-WebRequest -Uri $WDK_DOWNLOAD_LINK -OutFile $WDK_DESTINATION
    Start-Process -FilePath $WDK_DESTINATION -ArgumentList "/q" -Wait -PassThru

    Write "Windows Development Kit Installed successfully."

    # VSCode
    Write-Host "Installing Visual Studio Code..."
    & $chocoPath install -y --no-progress vscode

    # ===================================
    # Source Control
    # ===================================

    # Git installation
    Write-Host "Installing Git..."
    & $chocoPath install -y --no-progress git --params "/GitAndUnixToolsOnPath /WindowsTerminal /NoShellIntegration"

    # Refresh environment variables to get Git in the path
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # ===================================
    # Languages and Frameworks
    # ===================================

    # Python
    Write-Host "Installing Python and AWS libraries..."
    & $chocoPath install -y --no-progress python

    # Refresh environment to get Python in the path
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Install AWS libraries
    Write-Host "Installing Python AWS libraries..."
    & pip install --no-warn-script-location botocore boto3

    # Node.js
    Write-Host "Installing Node.js..."
    & $chocoPath install -y --no-progress nodejs-lts

    # ===================================
    # Infrastructure Tools
    # ===================================

    # Terraform
    Write-Host "Installing Terraform..."
    & $chocoPath install -y --no-progress terraform

    # tfenv (Terraform version manager)
    Write-Host "Installing tfenv..."

    # Create directory for tfenv
    $tfenvDir = "$toolsDir\tfenv"
    if (-not (Test-Path -Path $tfenvDir)) {
        New-Item -ItemType Directory -Force -Path $tfenvDir
    }

    # Clone tfenv repository
    try {
        # Check if Git is available in PATH
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue

        if ($gitCmd) {
            Write-Host "Git found, cloning tfenv..."
            & git clone https://github.com/tfutils/tfenv.git $tfenvDir

            # Add tfenv to the PATH environment variable
            [Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$tfenvDir\bin", "Machine")
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "tfenv installed successfully"
        } else {
            Write-Warning "Git command not available, skipping tfenv installation"
        }
    }
    catch {
        Write-Warning "Failed to install tfenv: $_"
    }

    # ===================================
    # VS Code Extensions
    # ===================================

    Write-Host "Installing VS Code Extensions..."

    $vsCodeExtensions = @(
        "ms-vscode-remote.vscode-remote-extensionpack",
        "ms-vscode-remote.remote-containers",
        "ms-vscode-remote.remote-ssh",
        "ms-vscode-remote.remote-ssh-edit",
        "ms-vscode-remote.remote-ssh-explorer",
        "ms-vscode-remote.remote-ssh-extension-pack"
    )

    # Check if VS Code is installed
    if (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd") {
        foreach ($extension in $vsCodeExtensions) {
            Write-Host "Installing VS Code extension: $extension"
            try {
                $process = Start-Process -FilePath "C:\Program Files\Microsoft VS Code\bin\code.cmd" -ArgumentList "--install-extension $extension" -Wait -PassThru -NoNewWindow

                if ($process.ExitCode -eq 0) {
                    Write-Host "Extension $extension installed successfully"
                } else {
                    Write-Warning "Extension $extension installation completed with exit code: $($process.ExitCode)"
                }
            } catch {
                Write-Error "Failed to install extension $extension : $_"
            }
        }
    } else {
        Write-Warning "VS Code command not found, skipping extension installation"
    }

    Write-Host "Development tools installation completed successfully!"
}
catch {
    Write-Error "Script execution failed: $_"
    throw
}
finally {
    if (Get-Command Stop-Transcript -ErrorAction SilentlyContinue) {
        try { Stop-Transcript } catch { }
    }
}
