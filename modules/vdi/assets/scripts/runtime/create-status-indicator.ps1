# VDI Installation Status Indicator
# Creates desktop shortcut showing installation progress

$StatusFile = "C:\temp\vdi-installation-status.txt"
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$StatusShortcut = "$DesktopPath\VDI Installation Status.txt"

# Function to check if software is installed
function Test-SoftwareInstalled {
    param([string]$SoftwareName)
    
    switch ($SoftwareName) {
        "Chocolatey" { 
            return (Get-Command choco -ErrorAction SilentlyContinue) -ne $null 
        }
        "Git" { 
            return (Get-Command git -ErrorAction SilentlyContinue) -ne $null 
        }
        "UnrealEngine" { 
            return Test-Path "C:\Program Files\Epic Games\UE_*" 
        }
        "VisualStudio" { 
            return Test-Path "C:\Program Files\Microsoft Visual Studio\*" 
        }
        default { return $false }
    }
}

# Check installation status
$Status = @()
$Status += "VDI Installation Status - $(Get-Date)"
$Status += "=" * 50

# Check users
$Users = Get-LocalUser | Where-Object { $_.Name -in @('VDIAdmin', 'john-doe', 'jane-smith') }
if ($Users.Count -gt 1) {
    $Status += "✅ Users: Ready ($($Users.Count) users created)"
} else {
    $Status += "⏳ Users: In Progress"
}

# Check software
$Software = @("Chocolatey", "Git", "UnrealEngine", "VisualStudio")
foreach ($App in $Software) {
    if (Test-SoftwareInstalled $App) {
        $Status += "✅ $App: Installed"
    } else {
        $Status += "⏳ $App: Installing..."
    }
}

# Overall status
$InstalledCount = ($Software | Where-Object { Test-SoftwareInstalled $_ }).Count
if ($InstalledCount -eq $Software.Count) {
    $Status += ""
    $Status += "🎉 VDI READY - All software installed!"
} else {
    $Status += ""
    $Status += "⏳ VDI IN PROGRESS - $InstalledCount/$($Software.Count) complete"
}

# Write to desktop
$Status | Out-File -FilePath $StatusShortcut -Encoding UTF8
$Status | Out-File -FilePath $StatusFile -Encoding UTF8

# Copy real-time status script to desktop
$StatusScript = "$DesktopPath\Check VDI Status.ps1"
Copy-Item "C:\temp\check-vdi-status.ps1" $StatusScript -Force

# Create auto-refresh scheduled task
$TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\temp\create-status-indicator.ps1"
$TaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "VDI-Status-Update" -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -Force

Write-Host "Status indicator created on desktop with auto-refresh every 5 minutes"
Write-Host "Real-time status script available: 'Check VDI Status.ps1' on desktop"