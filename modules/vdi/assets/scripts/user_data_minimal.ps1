# VDI Minimal User Data Script
# Basic setup only - SSM handles user creation and DCV setup

$ErrorActionPreference = 'Continue'
$LogFile = "C:\temp\vdi-minimal-setup.log"

# Create temp directory and start logging
New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
Start-Transcript -Path $LogFile -Append

Write-Host "=== VDI Minimal Setup Started ===" -ForegroundColor Green
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Yellow

# CRITICAL: Start EC2Launch service first (custom AMI has it stopped)
Start-Service "Amazon EC2Launch" -ErrorAction SilentlyContinue
Set-Service "Amazon EC2Launch" -StartupType Automatic -ErrorAction SilentlyContinue

# Get instance metadata
try {
    $InstanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -TimeoutSec 10
    $Region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region" -TimeoutSec 10
    Write-Host "Instance ID: $InstanceId, Region: $Region" -ForegroundColor Yellow
} catch {
    Write-Warning "Could not get instance metadata: $_"
    $InstanceId = "unknown"
    $Region = "us-east-1"
}

# Get configuration from template parameters
$WorkstationKey = "${workstation_key}"
$AssignedUser = "${assigned_user}"
$ProjectPrefix = "${project_prefix}"
$Region = "${region}"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  WorkstationKey: $WorkstationKey" -ForegroundColor Yellow
Write-Host "  AssignedUser: $AssignedUser" -ForegroundColor Yellow

# Verify AWS CLI is available
try {
    $awsVersion = aws --version
    Write-Host "AWS CLI Version: $awsVersion" -ForegroundColor Green
} catch {
    Write-Warning "AWS CLI not available: $_"
}

# Ensure DCV service is running (basic setup)
try {
    Start-Service -Name dcvserver -ErrorAction SilentlyContinue
    Set-Service -Name dcvserver -StartupType Automatic
    $dcvService = Get-Service -Name dcvserver
    Write-Host "DCV Service Status: $($dcvService.Status)" -ForegroundColor Green
} catch {
    Write-Warning "Could not start DCV service: $_"
}

# CREATE ALL VDI USERS DIRECTLY IN USER DATA
Write-Host "=== Creating VDI Users ===" -ForegroundColor Green

try {
    # Get all secrets for this workstation
    $AllSecrets = aws secretsmanager list-secrets --region $Region --query "SecretList[?starts_with(Name, '$ProjectPrefix/$WorkstationKey/users/')].Name" --output text
    
    foreach ($SecretName in ($AllSecrets -split '\s+')) {
        if ($SecretName) {
            Write-Host "Processing secret: $SecretName" -ForegroundColor Yellow
            $UserSecretJson = aws secretsmanager get-secret-value --secret-id $SecretName --region $Region --query SecretString --output text
            
            if ($UserSecretJson) {
                $UserData = $UserSecretJson | ConvertFrom-Json
                $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force
                $Username = $UserData.username
                $UserType = $UserData.user_type
                
                # Create or update user (idempotent)
                try {
                    New-LocalUser -Name $Username -Password $UserPassword -FullName "$($UserData.given_name) $($UserData.family_name)" -Description "VDI $UserType User" -ErrorAction Stop
                    Write-Host "Created new user: $Username ($UserType)" -ForegroundColor Green
                } catch {
                    if ($_.Exception.Message -like '*already exists*') {
                        Write-Host "User $Username already exists, updating password" -ForegroundColor Yellow
                        Set-LocalUser -Name $Username -Password $UserPassword
                    } else {
                        throw $_
                    }
                }
                
                # Add to appropriate Windows groups based on user type
                Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $Username -ErrorAction SilentlyContinue
                if ($UserType -eq 'administrator') {
                    Add-LocalGroupMember -Group 'Administrators' -Member $Username -ErrorAction SilentlyContinue
                    Write-Host "Added $Username to Administrators group" -ForegroundColor Green
                } else {
                    Add-LocalGroupMember -Group 'Users' -Member $Username -ErrorAction SilentlyContinue
                    Write-Host "Added $Username to Users group" -ForegroundColor Green
                }
                
                Write-Host "User $Username configured successfully" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Warning "User creation failed: $_"
}

# CREATE DCV SESSION
Write-Host "=== Creating DCV Session ===" -ForegroundColor Green
$dcvPath = 'C:\\Program Files\\NICE\\DCV\\Server\\bin\\dcv.exe'

# Close existing sessions
$existingSessions = & $dcvPath list-sessions 2>$null | Select-String "Session:" | ForEach-Object { ($_ -split "'")[1] }
foreach ($session in $existingSessions) {
    Write-Host "Closing session: $session" -ForegroundColor Yellow
    & $dcvPath close-session $session 2>$null
}

# Create session for assigned user
try {
    & $dcvPath create-session --owner $AssignedUser "$AssignedUser-session" 2>$null
    Write-Host "Created DCV session: $AssignedUser-session" -ForegroundColor Green
} catch {
    Write-Warning "Failed to create DCV session: $_"
}

Write-Host "=== VDI Setup Completed ===" -ForegroundColor Green
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Yellow

Stop-Transcript

# Signal completion
"VDI Setup Completed: $(Get-Date)" | Out-File -FilePath "C:\temp\vdi-setup-complete.txt" -Encoding UTF8