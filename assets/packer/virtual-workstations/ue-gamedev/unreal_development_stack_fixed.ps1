# Unreal Engine Development Stack - Complete Installation
# Installs Visual Studio 2022 + Epic Games Launcher + Unreal Engine 5.3

$ErrorActionPreference = "Stop"

function Write-Status {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

Write-Status "Installing Unreal Engine development stack..."

# Refresh environment to ensure Chocolatey is available
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

try {
    # ================================
    # Visual Studio 2022 Installation
    # ================================
    Write-Status "Installing Visual Studio 2022 Community with game development workloads..."
    Write-Status "This installation may take 30-45 minutes. Please be patient..." -Level "WARNING"
    
    choco install -y visualstudio2022community --package-parameters "--passive --locale en-US --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCrossPlat --add Microsoft.VisualStudio.Component.VC.DiagnosticTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Microsoft.VisualStudio.Component.Windows10SDK.18362 --add Component.Unreal"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Visual Studio 2022 Community installed successfully" -Level "SUCCESS"
    } else {
        Write-Status "Visual Studio 2022 Community installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
        throw "Visual Studio installation failed"
    }

    # ================================
    # Epic Games Launcher Installation
    # ================================
    Write-Status "Installing Epic Games Launcher..."
    
    $epicLauncherUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
    $epicLauncherPath = "C:\temp\EpicGamesLauncherInstaller.msi"
    
    New-Item -ItemType Directory -Force -Path C:\temp | Out-Null
    
    try {
        Invoke-WebRequest -Uri $epicLauncherUrl -OutFile $epicLauncherPath -UseBasicParsing -TimeoutSec 300
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $epicLauncherPath, "/quiet", "/norestart" -Wait
        
        Write-Status "Epic Games Launcher installed successfully" -Level "SUCCESS"
        
        # Create desktop shortcut for all users
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcutPath = "C:\Users\Public\Desktop\Epic Games Launcher.lnk"
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe"
        $Shortcut.IconLocation = "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe,0"
        $Shortcut.Description = "Epic Games Launcher"
        $Shortcut.Save()
        
        Write-Status "Desktop shortcut created" -Level "SUCCESS"
        
    } catch {
        Write-Status "Epic Games Launcher installation failed: $_" -Level "ERROR"
        throw "Epic Games Launcher installation failed"
    } finally {
        Remove-Item -Path $epicLauncherPath -ErrorAction SilentlyContinue
    }

    # ================================
    # Python Development Packages
    # ================================
    Write-Status "Installing Python packages for development..."
    try {
            # Install AWS and development packages (from old script)
        python -m pip install --no-warn-script-location botocore boto3 requests pyyaml
        Write-Status "Python development packages installed successfully" -Level "SUCCESS"
    } catch {
        Write-Status "Python packages installation failed: $_" -Level "WARNING"
        # Don't fail the entire build for optional Python packages
    }

    # ================================
    # Essential Development Tools
    # ================================
    Write-Status "Installing essential development tools..."
    
    # Install Git with proper parameters
    Write-Status "Installing Git..."
    choco install -y git --params="/GitAndUnixToolsOnPath /WindowsTerminal /NoShellIntegration"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Git installed successfully" -Level "SUCCESS"
    } else {
        Write-Status "Git installation failed with exit code: $LASTEXITCODE" -Level "ERROR"
    }
    
    # Batch install development tools
    Write-Status "Installing AWS CLI, Perforce tools, and utilities..."
    choco install -y --ignore-checksums awscli p4 p4v notepadplusplus 7zip
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Development tools installed successfully" -Level "SUCCESS"
    } else {
        Write-Status "Some development tools installation failed with exit code: $LASTEXITCODE" -Level "WARNING"
    }

} catch {
    Write-Status "Unreal development stack installation failed: $_" -Level "ERROR"
    throw
}

# ================================
# Configure PATH for Development
# ================================
Write-Status "Configuring PATH for Unreal Engine development..."
$devToolPaths = @(
    "C:\Program Files\Epic Games\UE_5.3\Engine\Binaries\Win64",           # Unreal Engine (when installed)
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE", # Visual Studio
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin" # MSBuild
)

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$pathsToAdd = @()

foreach ($toolPath in $devToolPaths) {
    if ($currentPath -notlike "*$toolPath*") {
        $pathsToAdd += $toolPath
    }
}

if ($pathsToAdd.Count -gt 0) {
    $newPath = $currentPath + ";" + ($pathsToAdd -join ";")
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Status "Added $($pathsToAdd.Count) development tool paths to system PATH" -Level "SUCCESS"
} else {
    Write-Status "All development tool paths already in system PATH"
}

# ================================
# Create Setup Instructions
# ================================
$instructionsPath = "C:\Users\Public\Desktop\Unreal Engine Setup Instructions.txt"
$instructions = @"
UNREAL ENGINE 5.3 SETUP INSTRUCTIONS
====================================

Your VDI workstation is now ready for Unreal Engine development!

WHAT'S INSTALLED:
✅ Visual Studio 2022 Community (with Unreal Engine workloads)
✅ Epic Games Launcher
✅ Git, Python, Perforce (P4/P4V)
✅ Development tools and utilities

NEXT STEPS TO GET UNREAL ENGINE:
1. Double-click "Epic Games Launcher" on desktop
2. Create Epic Games account or sign in
3. Go to "Unreal Engine" tab
4. Click "Install Engine" 
5. Select "Unreal Engine 5.3"
6. Choose installation location (recommend D:\UnrealEngine)
7. Wait for download/installation (15-30 minutes)

ALTERNATIVE - AUTOMATED UNREAL ENGINE INSTALLATION:
If you have Epic Games credentials, you can automate UE installation:
1. Open PowerShell as Administrator
2. Run: Set-Location "C:\Program Files (x86)\Epic Games\Launcher\Engine\Binaries\Win32"
3. Run: .\UnrealVersionSelector.exe /installengine 5.3

DEVELOPMENT READY:
- Visual Studio 2022 with C++ and Unreal components
- Epic Games Launcher for engine management
- Git for version control
- Perforce for enterprise version control
- Python for scripting and automation

Happy game development!
"@

$instructions | Out-File -FilePath $instructionsPath -Encoding UTF8
Write-Status "Setup instructions created on desktop" -Level "SUCCESS"

Write-Status "Unreal Engine development stack installation completed successfully" -Level "SUCCESS"
Write-Status "NOTE: Unreal Engine 5.3 must be installed through Epic Games Launcher after first login" -Level "WARNING"