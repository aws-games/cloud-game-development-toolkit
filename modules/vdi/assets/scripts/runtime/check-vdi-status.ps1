# Real-time VDI Status Checker
# Run this script anytime to get current installation status

param(
    [switch]$Watch,  # Continuous monitoring mode
    [int]$RefreshSeconds = 30  # Refresh interval for watch mode
)

function Get-VDIStatus {
    Clear-Host
    Write-Host "VDI Installation Status - $(Get-Date)" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    # Check users
    $Users = Get-LocalUser | Where-Object { $_.Name -notin @('Administrator', 'DefaultAccount', 'Guest', 'WDAGUtilityAccount') }
    if ($Users.Count -gt 0) {
        Write-Host "✅ Users: Ready ($($Users.Count) users created)" -ForegroundColor Green
        $Users | ForEach-Object { Write-Host "   - $($_.Name) (Enabled: $($_.Enabled))" -ForegroundColor Gray }
    } else {
        Write-Host "⏳ Users: In Progress" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Check software installations
    $Software = @{
        "Chocolatey" = { (Get-Command choco -ErrorAction SilentlyContinue) -ne $null }
        "Git" = { (Get-Command git -ErrorAction SilentlyContinue) -ne $null }
        "UnrealEngine" = { Test-Path "C:\Program Files\Epic Games\UE_*" }
        "VisualStudio" = { Test-Path "C:\Program Files\Microsoft Visual Studio\*" }
    }
    
    $InstalledCount = 0
    foreach ($App in $Software.Keys) {
        $IsInstalled = & $Software[$App]
        if ($IsInstalled) {
            Write-Host "✅ $App`: Installed" -ForegroundColor Green
            $InstalledCount++
        } else {
            Write-Host "⏳ $App`: Installing..." -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    
    # Check DCV sessions
    $dcvPath = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'
    if (Test-Path $dcvPath) {
        $sessions = & $dcvPath list-sessions 2>$null | Select-String "Session:" 
        if ($sessions) {
            Write-Host "✅ DCV Sessions: Ready" -ForegroundColor Green
            $sessions | ForEach-Object { 
                $sessionInfo = $_ -replace "Session: '(.+?)' \(owner:(.+?) type:(.+?)\)", "   - $1 (owner: $2)"
                Write-Host $sessionInfo -ForegroundColor Gray
            }
        } else {
            Write-Host "⏳ DCV Sessions: In Progress" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ DCV: Not Available" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Overall status
    $TotalSoftware = $Software.Count
    if ($InstalledCount -eq $TotalSoftware -and $Users.Count -gt 0) {
        Write-Host "🎉 VDI READY - All components installed!" -ForegroundColor Green -BackgroundColor DarkGreen
    } else {
        Write-Host "⏳ VDI IN PROGRESS - $InstalledCount/$TotalSoftware software, $($Users.Count) users" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Last checked: $(Get-Date)" -ForegroundColor Gray
    
    if ($Watch) {
        Write-Host "Refreshing in $RefreshSeconds seconds... (Ctrl+C to stop)" -ForegroundColor Gray
    }
}

# Main execution
if ($Watch) {
    Write-Host "Starting continuous VDI status monitoring..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
    Write-Host ""
    
    while ($true) {
        Get-VDIStatus
        Start-Sleep -Seconds $RefreshSeconds
    }
} else {
    Get-VDIStatus
    Write-Host ""
    Write-Host "💡 Tip: Run with -Watch for continuous monitoring" -ForegroundColor Cyan
    Write-Host "   Example: .\check-vdi-status.ps1 -Watch" -ForegroundColor Gray
}