# Unreal Engine Development Environment Setup
# This script installs the Epic Games Launcher

# Create log directory first thing
$logDir = "C:\temp"
$logFile = "$logDir\unreal-dev-install.log"

if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

# Initialize log file
"Unreal Development Environment Setup started at $(Get-Date)" | Out-File -FilePath $logFile -Force

# Start transcript for complete command logging
try {
    Start-Transcript -Path "$logDir\unreal-dev-transcript.txt" -Append
    "Started transcript logging" | Out-File -FilePath $logFile -Append
}
catch {
    "Failed to start transcript: $_" | Out-File -FilePath $logFile -Append
}

function Log-Message {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    $logMessage | Out-File -FilePath $logFile -Append

    # Write to console with color based on level
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
    Log-Message "Starting Unreal Development Environment Setup" -Level "INFO"
    Log-Message "Computer Name: $env:COMPUTERNAME" -Level "INFO"
    Log-Message "Windows Version: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)" -Level "INFO"
    Log-Message "Current User: $env:USERNAME" -Level "INFO"

    # Set vars for installation locations
    $driveLetter = "C:"
    $installationDir = "CGD-Workstation-Tools"
    $unrealDir = "$driveLetter\$installationDir\UnrealEngine"

    # Create Unreal directory if it doesn't exist
    if (-not (Test-Path -Path $unrealDir)) {
        New-Item -ItemType Directory -Force -Path $unrealDir | Out-Null
        Log-Message "Created Unreal directory: $unrealDir" -Level "SUCCESS"
    }

    # Create scripts directory
    $scriptsDir = "$unrealDir\Scripts"
    if (-not (Test-Path -Path $scriptsDir)) {
        New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null
        Log-Message "Created scripts directory: $scriptsDir" -Level "SUCCESS"
    }

    # Create docs directory
    $docsDir = "$unrealDir\Docs"
    if (-not (Test-Path -Path $docsDir)) {
        New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
        Log-Message "Created documentation directory: $docsDir" -Level "SUCCESS"
    }

    # ===================================
    # Epic Games Launcher Installation
    # ===================================

    Log-Message "Downloading Epic Games Launcher..." -Level "INFO"
    $epicInstallerUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
    $epicInstallerPath = "$unrealDir\EpicGamesLauncherInstaller.msi"

    try {
        Invoke-WebRequest -Uri $epicInstallerUrl -OutFile $epicInstallerPath -UseBasicParsing
        Log-Message "Epic Games Launcher installer downloaded successfully" -Level "SUCCESS"
    }
    catch {
        Log-Message "Failed to download Epic Games Launcher: $_" -Level "ERROR"
        throw "Download failed. Cannot proceed with installation."
    }

    # Install the Epic Games Launcher
    Log-Message "Installing Epic Games Launcher..." -Level "INFO"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$epicInstallerPath`" /quiet" -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Log-Message "Epic Games Launcher installed successfully" -Level "SUCCESS"
    } else {
        Log-Message "Epic Games Launcher installation completed with exit code: $($process.ExitCode)" -Level "WARNING"
    }

    # Clean up the installer
    Remove-Item -Path $epicInstallerPath -ErrorAction SilentlyContinue

    # ===========================================
    # Create Epic Games Launcher Desktop Shortcut
    # ===========================================

    Log-Message "Creating desktop shortcut for Epic Games Launcher..." -Level "INFO"
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcutPath = "C:\Users\Public\Desktop\Epic Games Launcher.lnk"
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe"
    $Shortcut.IconLocation = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe,0"
    $Shortcut.Description = "Epic Games Launcher"
    $Shortcut.Save()
    Log-Message "Desktop shortcut created" -Level "SUCCESS"
}
catch {
    Log-Message "ERROR: $($_.Exception.Message)" -Level "ERROR"
    Log-Message "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
}
finally {
    # Stop transcript
    try {
        Stop-Transcript
        Log-Message "Transcript logging stopped" -Level "INFO"
    }
    catch {
        Log-Message "Failed to stop transcript: $_" -Level "WARNING"
    }

    # Final log message
    Log-Message "Unreal Development Environment Setup process completed at $(Get-Date)" -Level "INFO"
}
