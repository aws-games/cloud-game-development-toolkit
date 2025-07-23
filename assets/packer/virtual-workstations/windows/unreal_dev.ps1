# Unreal Engine Development Environment Setup
# This script installs the Epic Games Launcher, which is essential for Unreal Engine development

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
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG"   { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage }
    }
}

try {
    # Log system information
    Write-Status "Starting Unreal Development Environment Setup"
    Write-Status "Computer Name: $env:COMPUTERNAME"
    Write-Status "Windows Version: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
    Write-Status "Current User: $env:USERNAME"

    # ================================
    # Epic Games Launcher Installation
    # ================================

    Write-Status "Downloading Epic Games Launcher..."
    $epicInstallerUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
    $epicInstallerPath = "$env:TEMP\EpicGamesLauncherInstaller.msi"

    # Download the installer with retry logic
    $maxRetries = 3
    $retryCount = 0
    $downloadSuccess = $false

    while (-not $downloadSuccess -and $retryCount -lt $maxRetries) {
        try {
            Write-Status "Download attempt $($retryCount + 1) of $maxRetries..."
            $downloadParams = @{
                Uri = $epicInstallerUrl
                OutFile = $epicInstallerPath
                UseBasicParsing = $true
                TimeoutSec = 300  # 5 minute timeout
            }
            Invoke-WebRequest @downloadParams

            if (Test-Path $epicInstallerPath) {
                $fileSize = (Get-Item $epicInstallerPath).Length
                if ($fileSize -gt 1MB) {
                    $downloadSuccess = $true
                    Write-Status "Epic Games Launcher installer downloaded successfully ($fileSize bytes)" -Level "SUCCESS"
                } else {
                    Write-Status "Downloaded file is too small ($fileSize bytes), retrying..." -Level "WARNING"
                    Remove-Item -Path $epicInstallerPath -Force -ErrorAction SilentlyContinue
                    $retryCount++
                }
            } else {
                Write-Status "Download failed, file not found" -Level "WARNING"
                $retryCount++
            }
        } catch {
            Write-Status "Download failed: $_" -Level "WARNING"
            $retryCount++
            Start-Sleep -Seconds 10  # Wait before retrying
        }
    }

    if (-not $downloadSuccess) {
        Write-Status "Failed to download Epic Games Launcher after $maxRetries attempts" -Level "ERROR"
        throw "Epic Games Launcher download failed"
    }

    # Install the Epic Games Launcher
    Write-Status "Installing Epic Games Launcher..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$epicInstallerPath`" /quiet" -Wait -PassThru

    # Clean up the installer file
    Remove-Item -Path $epicInstallerPath -ErrorAction SilentlyContinue

    # =======================
    # Create Desktop Shortcut
    # =======================

    Write-Status "Creating desktop shortcut for Epic Games Launcher..."

    # Use Windows Script Host to create the shortcut
    $WshShell = New-Object -ComObject WScript.Shell

    # Create shortcut in Public Desktop so it's available to all users
    $shortcutPath = "C:\Users\Public\Desktop\Epic Games Launcher.lnk"
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)

    # Set the target executable path
    $Shortcut.TargetPath = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe"
    $Shortcut.IconLocation = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe,0"
    $Shortcut.Description = "Epic Games Launcher"

    # Save the shortcut
    $Shortcut.Save()
    Write-Status "Desktop shortcut created" -Level "SUCCESS"

    Write-Status "Unreal Development Environment Setup completed successfully" -Level "SUCCESS"
}
catch {
    Write-Status "Script execution failed: $_" -Level "ERROR"
    throw
}
