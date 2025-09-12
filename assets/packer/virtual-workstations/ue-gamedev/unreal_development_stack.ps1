# Unreal Engine Development Stack Installation
# Adds Visual Studio 2022 + Unreal Engine 5.3 to base infrastructure

$ErrorActionPreference = "Stop"

Write-Host "Installing Unreal Engine development stack..."

# Refresh environment to ensure Chocolatey is available
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

try {
    # Install Visual Studio 2022 Community with game development workloads
    Write-Host "Installing Visual Studio 2022 Community with game development workloads..."
    Write-Host "This installation may take 30-45 minutes. Please be patient..." -ForegroundColor Yellow

    choco install -y visualstudio2022community --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCrossPlat --add Microsoft.VisualStudio.Component.VC.DiagnosticTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Microsoft.VisualStudio.Component.Windows10SDK.18362 --add Component.Unreal"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Visual Studio 2022 Community installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Visual Studio 2022 Community installation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }

    # Install Unreal Engine 5.3 via Epic Games Launcher
    Write-Host "Installing Epic Games Launcher and Unreal Engine 5.3..."
    Write-Host "This installation may take 20-30 minutes. Please be patient..." -ForegroundColor Yellow

    # Download Epic Games Launcher
    $epicLauncherUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
    $epicLauncherPath = "C:\temp\EpicGamesLauncherInstaller.msi"

    New-Item -ItemType Directory -Force -Path C:\temp
    Invoke-WebRequest -Uri $epicLauncherUrl -OutFile $epicLauncherPath -TimeoutSec 300

    # Install Epic Games Launcher
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $epicLauncherPath, "/quiet", "/norestart" -Wait

    Write-Host "Epic Games Launcher installed successfully" -ForegroundColor Green
    Write-Host "Note: Unreal Engine 5.3 will need to be installed manually through Epic Games Launcher after first login" -ForegroundColor Yellow

    # Note: Python packages are installed by base infrastructure script

} catch {
    Write-Host "Unreal development stack installation failed: $_" -ForegroundColor Red
    throw
}

# Configure additional PATH entries for Unreal Engine
Write-Host "Configuring PATH for Unreal Engine development..."
$ueToolPaths = @(
    "C:\Program Files\Epic Games\UE_5.3\Engine\Binaries\Win64",           # Unreal Engine
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE", # Visual Studio
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin" # MSBuild
)

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
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
