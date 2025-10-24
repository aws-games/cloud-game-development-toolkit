# DCV Session Manager - Ensures proper session ownership after reboot
# This script should be installed as a Windows service or scheduled task

param(
    [string]$AssignedUser,
    [string]$WorkstationKey
)

# Function to setup DCV session for assigned user
function Set-DCVSession {
    param($Username)
    
    Write-Host "Setting up DCV session for user: $Username"
    
    # Configure DCV to automatically create sessions for specific user (not SYSTEM)
    try {
        $registryPath = "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management"
        
        # Create registry keys if they don't exist
        $regKey = "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv"
        if (-not (Test-Path "Registry::$regKey")) {
            New-Item -Path "Registry::$regKey" -Force | Out-Null
        }
        if (-not (Test-Path "Registry::$registryPath")) {
            New-Item -Path "Registry::$registryPath" -Force | Out-Null
        }
        
        # Enable automatic session creation for specific user
        Set-ItemProperty -Path "Registry::$registryPath" -Name "create-session" -Value 1 -Type DWord
        Set-ItemProperty -Path "Registry::$registryPath" -Name "owner" -Value $Username -Type String
        
        Write-Host "Configured DCV to automatically create sessions for user: $Username"
    } catch {
        Write-Host "Failed to configure DCV registry settings: $_" -ForegroundColor Yellow
    }
    
    # Restart DCV service to apply new configuration
    try {
        Write-Host "Restarting DCV service to apply configuration..."
        Restart-Service -Name dcvserver -Force
        Start-Sleep -Seconds 5
        Write-Host "DCV service restarted. Session will be created automatically for user: $Username"
    } catch {
        Write-Host "Failed to restart DCV service: $_" -ForegroundColor Yellow
    }
}

# Main execution - Configure DCV for automatic user sessions
if ($AssignedUser) {
    Set-DCVSession -Username $AssignedUser
    Write-Host "DCV configured for automatic session creation for user: $AssignedUser"
} else {
    Write-Host "No assigned user specified"
}

Write-Host "DCV configuration completed - sessions will be created automatically on startup"