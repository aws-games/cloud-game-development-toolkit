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
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
}

try {
    # ================================
    # Epic Games Launcher Installation
    # ================================

    Write-Status "Downloading Epic Games Launcher..."
    $epicInstallerUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
    $epicInstallerPath = "$env:TEMP\EpicGamesLauncherInstaller.msi"

    # Download the installer
    Write-Status "Downloading Epic Games Launcher installer..."
    try {
        Invoke-WebRequest -Uri $epicInstallerUrl -OutFile $epicInstallerPath -UseBasicParsing -TimeoutSec 300

        Write-Status "Epic Games Launcher installer downloaded successfully" -Level "SUCCESS"
    }
    catch {
        Write-Status "Failed to download Epic Games Launcher: $_" -Level "ERROR"
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
