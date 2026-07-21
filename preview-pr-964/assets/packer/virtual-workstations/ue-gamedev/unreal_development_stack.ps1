# Unreal Engine Development Stack Installation
# Adds Visual Studio 2022 + Epic Games Launcher to base infrastructure

$ErrorActionPreference = "Stop"

Write-Host "Installing Unreal Engine development stack..."

# CRITICAL: Chocolatey was installed in base_infrastructure.ps1 but this PowerShell session can't see it
# Windows installers update system PATH but current session still has old PATH from when it started
# Without this refresh, 'choco' command fails and Visual Studio never gets installed
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
Write-Host "Refreshed PATH - Chocolatey now available in current PowerShell session"

# Verify Chocolatey is available
try {
    $chocoVersion = choco --version
    Write-Host "Chocolatey found: $chocoVersion"
} catch {
    Write-Host "Chocolatey not found in PATH - this is required for Unreal development stack" -ForegroundColor Red
    throw "Chocolatey dependency not met"
}

try {
    # Install Visual Studio 2022 Community with game development workloads
    Write-Host "Installing Visual Studio 2022 Community with game development workloads..."
    Write-Host "This installation may take 30-45 minutes. Please be patient..." -ForegroundColor Yellow

    choco install -y visualstudio2022community --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCrossPlat --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.VC.DiagnosticTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Component.Unreal"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Visual Studio 2022 Community installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Visual Studio 2022 Community installation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }

    # Install Epic Games Launcher
    Write-Host "Installing Epic Games Launcher..."
    Write-Host "This installation may take 10-15 minutes. Please be patient..." -ForegroundColor Yellow

    # Download Epic Games Launcher
    $epicLauncherUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
    $epicLauncherPath = "C:\temp\EpicGamesLauncherInstaller.msi"

    New-Item -ItemType Directory -Force -Path C:\temp
    Invoke-WebRequest -Uri $epicLauncherUrl -OutFile $epicLauncherPath -TimeoutSec 300

    # Install Epic Games Launcher
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $epicLauncherPath, "/quiet", "/norestart" -Wait

    Write-Host "Epic Games Launcher installed successfully" -ForegroundColor Green
    Write-Host "Note: Unreal Engine will need to be installed manually through Epic Games Launcher after first login" -ForegroundColor Yellow

    # Note: Python packages are installed by base infrastructure script

} catch {
    Write-Host "Unreal development stack installation failed: $_" -ForegroundColor Red
    throw
}

# Configure additional PATH entries for Unreal Engine development
Write-Host "Configuring PATH for Unreal Engine development..."

# Refresh PATH first to include any recent installations (like AWS CLI)
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$ueToolPaths = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE", # Visual Studio
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin" # MSBuild
)

$pathsToAdd = @()
foreach ($toolPath in $ueToolPaths) {
    if ($currentPath -notlike "*$toolPath*") {
        $pathsToAdd += $toolPath
    }
}

if ($pathsToAdd.Count -gt 0) {
    $newPath = $currentPath + ";" + ($pathsToAdd -join ";")
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "Added $($pathsToAdd.Count) Unreal Engine tool paths to system PATH"
} else {
    Write-Host "All Unreal Engine tool paths already in system PATH"
}

Write-Host "Unreal Engine development stack installation completed successfully" -ForegroundColor Green
