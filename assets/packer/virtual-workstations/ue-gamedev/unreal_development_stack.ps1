# Unreal Engine Development Stack Installation
# Adds Visual Studio 2022 + Epic Games Launcher to base infrastructure

$ErrorActionPreference = "Stop"

Write-Host "Installing Unreal Engine development stack..."

# CRITICAL: Chocolatey was installed in base_infrastructure.ps1 but this PowerShell session can't see it
# Windows installers update system PATH but current session still has old PATH from when it started
# Without this refresh, 'choco' command fails and Visual Studio never gets installed
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Resolve choco.exe by absolute path rather than relying on PATH alone. The machine
# PATH written by the Chocolatey installer in the previous provisioner's session is
# not always visible to this one yet, which made this check fail intermittently --
# unchanged builds would resolve Chocolatey on one run and report
# "Chocolatey dependency not met" on the next.
$chocoInstall = if ($env:ChocolateyInstall) { $env:ChocolateyInstall } else { Join-Path $env:ProgramData 'chocolatey' }
$chocoExe = Join-Path $chocoInstall 'bin\choco.exe'

# Give the installer's PATH/filesystem changes a moment to land before giving up.
$chocoVersion = $null
foreach ($delay in 0, 5, 10, 20) {
    if ($delay -gt 0) {
        Write-Host "Chocolatey not resolvable yet; waiting ${delay}s..."
        Start-Sleep -Seconds $delay
    }
    if (Test-Path $chocoExe) {
        $chocoVersion = & $chocoExe --version
        break
    }
    # Fall back to PATH lookup in case Chocolatey lives somewhere non-standard.
    $onPath = Get-Command choco -ErrorAction SilentlyContinue
    if ($onPath) {
        $chocoExe = $onPath.Source
        $chocoVersion = & $chocoExe --version
        break
    }
}

if (-not $chocoVersion) {
    Write-Host "Chocolatey not found at $chocoExe or on PATH - required for the Unreal development stack" -ForegroundColor Red
    throw "Chocolatey dependency not met"
}
Write-Host "Chocolatey found: $chocoVersion (at $chocoExe)"

# Make sure the rest of this script's `choco` calls resolve, even if PATH is stale.
$chocoBin = Split-Path $chocoExe -Parent
if ($env:Path -notlike "*$chocoBin*") {
    $env:Path = "$chocoBin;$env:Path"
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
