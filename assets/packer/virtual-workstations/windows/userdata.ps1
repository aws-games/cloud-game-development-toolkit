# Core PowerShell script fed into EC2 User Data. Calls other PS Scripts

<powershell>
# Set vars for installation locations
$driveLetter = "C:"
$tempDir = "temp"
$installationDir = "CGD-Workstation-Tools"

# Create temp directory for script logging
New-Item -ItemType Directory -Force -Path "$driveLetter\temp"

# Define script paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$baseSetupScript = Join-Path $scriptDir "base_setup.ps1"
$gitScript = Join-Path $scriptDir "install_git.ps1"
$terraformScript = Join-Path $scriptDir "install_terraform.ps1"
$vscodeScript = Join-Path $scriptDir "install_vscode.ps1"
# Add more script paths as needed

# Function to run external scripts
function Invoke-ExternalScript {
    param (
        [string]$ScriptPath,
        [string]$ScriptName
    )

    if (Test-Path $ScriptPath) {
        Write-Information "Running $ScriptName script..." -InformationAction Continue
        try {
            # Dot-source the script to run in the current scope
            . $ScriptPath
            Write-Information "$ScriptName script completed successfully" -InformationAction Continue
        }
        catch {
            Write-Error "Failed to run $ScriptName script. Error: $_" -ErrorAction Continue
        }
    }
    else {
        Write-Warning "Script not found: $ScriptPath" -WarningAction Continue
    }
}

# Run base setup first
Invoke-ExternalScript -ScriptPath $baseSetupScript -ScriptName "Base Setup"

# Run software installation scripts if they exist
Invoke-ExternalScript -ScriptPath $gitScript -ScriptName "Git Installation"
Invoke-ExternalScript -ScriptPath $terraformScript -ScriptName "Terraform Installation"
Invoke-ExternalScript -ScriptPath $vscodeScript -ScriptName "VS Code Installation"
# Add more script calls as needed

# Create EC2Launch script for profile initialization
Write-Information "Creating EC2Launch script for profile initialization..." -InformationAction Continue
$ec2LaunchDir = "C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts"
if (-not (Test-Path $ec2LaunchDir)) {
    New-Item -ItemType Directory -Path $ec2LaunchDir -Force | Out-Null
}

# Get the username that was created in base_setup.ps1
$username = (Get-LocalUser | Where-Object { $_.Name -ne "Administrator" -and $_.Enabled -eq $true } | Select-Object -First 1).Name

$profileInitScript = @"
# Initialize user profile for $username
`$taskName = "InitUserProfile_$username"
`$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c echo Profile initialized"
`$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$username"
`$settings = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter "00:00:01"
`$principal = New-ScheduledTaskPrincipal -UserId "$username" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName `$taskName -Action `$action -Trigger `$trigger -Settings `$settings -Principal `$principal -Force
"@

Set-Content -Path "$ec2LaunchDir\InitUserProfile.ps1" -Value $profileInitScript
Write-Information "EC2Launch script created for profile initialization" -InformationAction Continue
</powershell>
