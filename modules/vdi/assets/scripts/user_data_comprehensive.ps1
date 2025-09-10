# VDI Comprehensive User Data Script
# Handles user creation, DCV setup, and software installation at boot time
# This ensures critical setup happens immediately, not via unreliable SSM associations

# CRITICAL: Start EC2Launch service first (custom AMI has it stopped)
Start-Service "Amazon EC2Launch" -ErrorAction SilentlyContinue
Set-Service "Amazon EC2Launch" -StartupType Automatic -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Continue'  # Continue on errors to complete as much as possible
$LogFile = "C:\temp\vdi-setup.log"

# Create temp directory and start logging
New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
Start-Transcript -Path $LogFile -Append

Write-Host "=== VDI Comprehensive Setup Started ===" -ForegroundColor Green
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Yellow

# Get instance metadata
try {
    $InstanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -TimeoutSec 10
    $Region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region" -TimeoutSec 10
    Write-Host "Instance ID: $InstanceId, Region: $Region" -ForegroundColor Yellow
} catch {
    Write-Warning "Could not get instance metadata: $_"
    $InstanceId = "unknown"
    $Region = "us-east-1"  # Default fallback
}

# Function to safely execute commands with error handling
function Invoke-SafeCommand {
    param(
        [string]$Description,
        [scriptblock]$Command
    )
    
    Write-Host "`n--- $Description ---" -ForegroundColor Cyan
    try {
        & $Command
        Write-Host "✅ $Description completed successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "❌ $Description failed: $_"
        return $false
    }
}

# Wait for AWS CLI to be available (should be pre-installed on AMI)
Invoke-SafeCommand "Verify AWS CLI" {
    $awsVersion = aws --version
    Write-Host "AWS CLI Version: $awsVersion"
}

# CRITICAL SECTION 1: User Creation
Write-Host "`n=== CRITICAL: User Account Creation ===" -ForegroundColor Magenta

# Get configuration from template parameters
$WorkstationKey = "${workstation_key}"
$AssignedUser = "${assigned_user}"
$ProjectPrefix = "${project_prefix}"
$Region = "${region}"

Write-Host "Configuration from template:" -ForegroundColor Yellow
Write-Host "  WorkstationKey: $WorkstationKey" -ForegroundColor Yellow
Write-Host "  AssignedUser: $AssignedUser" -ForegroundColor Yellow
Write-Host "  ProjectPrefix: $ProjectPrefix" -ForegroundColor Yellow
Write-Host "  Region: $Region" -ForegroundColor Yellow

# Create VDIAdmin user and store password in Secrets Manager
Invoke-SafeCommand "Create VDIAdmin User" {
    Write-Host "Generating VDIAdmin password and storing in Secrets Manager..."
    
    # Generate a random password for VDIAdmin (16 characters, complex)
    $VDIAdminPasswordPlain = -join ((65..90) + (97..122) + (48..57) + (33,35,36,37,38,42,43,45,61,63,64) | Get-Random -Count 16 | ForEach-Object {[char]$_})
    $VDIAdminPassword = ConvertTo-SecureString $VDIAdminPasswordPlain -AsPlainText -Force
    
    Write-Host "Generated VDIAdmin password: $VDIAdminPasswordPlain" -ForegroundColor Yellow
    
    # Store password in Secrets Manager FIRST
    $VDIAdminSecretName = "$ProjectPrefix/$WorkstationKey/users/vdiadmin"
    $VDIAdminSecretValue = @{
        username = "VDIAdmin"
        password = $VDIAdminPasswordPlain
        account_type = "admin"
        workstation = $WorkstationKey
    } | ConvertTo-Json
    
    # Try to create the secret first
    Write-Host "Attempting to create VDIAdmin secret..."
    $createOutput = aws secretsmanager create-secret --name $VDIAdminSecretName --description "VDIAdmin password for $WorkstationKey" --secret-string $VDIAdminSecretValue --region $Region 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Created new VDIAdmin secret in Secrets Manager"
    } else {
        # If creation failed, try to update existing secret
        Write-Host "Secret may exist, attempting to update..."
        $updateOutput = aws secretsmanager update-secret --secret-id $VDIAdminSecretName --secret-string $VDIAdminSecretValue --region $Region 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Updated existing VDIAdmin secret in Secrets Manager"
        } else {
            Write-Warning "Failed to create or update VDIAdmin secret: $updateOutput"
            throw "Could not manage VDIAdmin secret"
        }
    }
    
    # Create or update VDIAdmin user
    try {
        New-LocalUser -Name 'VDIAdmin' -Password $VDIAdminPassword -FullName 'VDI Administrator' -Description 'VDI Management Account' -ErrorAction Stop
        Write-Host "Created new VDIAdmin user"
    } catch {
        if ($_.Exception.Message -like '*already exists*') {
            Write-Host "VDIAdmin user already exists, updating password"
            Set-LocalUser -Name 'VDIAdmin' -Password $VDIAdminPassword
        } else {
            throw $_
        }
    }
    
    # Add to groups
    Add-LocalGroupMember -Group 'Administrators' -Member 'VDIAdmin' -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group 'Remote Desktop Users' -Member 'VDIAdmin' -ErrorAction SilentlyContinue
    
    Write-Host "VDIAdmin user configured successfully and password stored in Secrets Manager"
}

# Create assigned user
Invoke-SafeCommand "Create Assigned User ($AssignedUser)" {
    Write-Host "Retrieving $AssignedUser password from Secrets Manager..."
    $UserSecretName = "$ProjectPrefix/$WorkstationKey/users/$AssignedUser"
    $UserSecretJson = aws secretsmanager get-secret-value --secret-id $UserSecretName --region $Region --query SecretString --output text
    
    if ($UserSecretJson) {
        $UserData = $UserSecretJson | ConvertFrom-Json
        $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force
        
        # Create or update user
        try {
            New-LocalUser -Name $AssignedUser -Password $UserPassword -FullName "$($UserData.given_name) $($UserData.family_name)" -Description "VDI User" -ErrorAction Stop
            Write-Host "Created new user: $AssignedUser"
        } catch {
            if ($_.Exception.Message -like '*already exists*') {
                Write-Host "User $AssignedUser already exists, updating password"
                Set-LocalUser -Name $AssignedUser -Password $UserPassword
            } else {
                throw $_
            }
        }
        
        # Add to Remote Desktop Users group
        Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $AssignedUser -ErrorAction SilentlyContinue
        
        Write-Host "User $AssignedUser configured successfully"
    } else {
        throw "Could not retrieve user secret for $AssignedUser"
    }
}

# Verify users were created
Invoke-SafeCommand "Verify User Creation" {
    $Users = Get-LocalUser | Select-Object Name, Enabled
    Write-Host "Current local users:"
    $Users | ForEach-Object { Write-Host "  - $($_.Name) (Enabled: $($_.Enabled))" }
    
    # Check if our users exist
    $VDIAdminExists = $Users | Where-Object { $_.Name -eq 'VDIAdmin' }
    $AssignedUserExists = $Users | Where-Object { $_.Name -eq $AssignedUser }
    
    if (-not $VDIAdminExists) { throw "VDIAdmin user not found" }
    if (-not $AssignedUserExists) { throw "Assigned user $AssignedUser not found" }
    
    Write-Host "✅ Both VDIAdmin and $AssignedUser users verified"
}

# CRITICAL SECTION 2: DCV Setup
Write-Host "`n=== CRITICAL: DCV Session Setup ===" -ForegroundColor Magenta

# Ensure DCV service is running
Invoke-SafeCommand "Start DCV Service" {
    Write-Host "Starting DCV service..."
    Start-Service -Name dcvserver -ErrorAction SilentlyContinue
    Set-Service -Name dcvserver -StartupType Automatic
    Start-Sleep -Seconds 10
    
    $dcvService = Get-Service -Name dcvserver
    Write-Host "DCV Service Status: $($dcvService.Status)"
    
    if ($dcvService.Status -ne 'Running') {
        throw "DCV service is not running"
    }
}

# Create DCV session for assigned user
Invoke-SafeCommand "Create DCV Session" {
    $dcvPath = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'
    
    # Close any existing sessions first
    Write-Host "Closing any existing DCV sessions..."
    $existingSessions = & $dcvPath list-sessions 2>$null | Select-String "Session:" | ForEach-Object { ($_ -split "'")[1] }
    foreach ($session in $existingSessions) {
        Write-Host "Closing session: $session"
        & $dcvPath close-session $session 2>$null
    }
    Start-Sleep -Seconds 5
    
    # Create new session for assigned user
    Write-Host "Creating DCV session for $AssignedUser..."
    $sessionName = "$AssignedUser-session"
    & $dcvPath create-session --owner $AssignedUser $sessionName 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Created DCV session: $sessionName"
    } else {
        throw "Failed to create DCV session for $AssignedUser"
    }
    
    # Share session with VDIAdmin for admin access
    Write-Host "Sharing session with VDIAdmin..."
    & $dcvPath share-session $sessionName VDIAdmin 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Shared session with VDIAdmin"
    } else {
        Write-Warning "Failed to share session with VDIAdmin"
    }
    
    # Share session with Administrator for emergency access
    Write-Host "Sharing session with Administrator..."
    & $dcvPath share-session $sessionName Administrator 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Shared session with Administrator"
    } else {
        Write-Warning "Failed to share session with Administrator"
    }
    
    # List sessions to verify
    Write-Host "Current DCV sessions:"
    & $dcvPath list-sessions
}

# IMPORTANT SECTION 3: Trigger SSM Associations Immediately
Write-Host "`n=== IMPORTANT: Trigger SSM Setup ===" -ForegroundColor Magenta

# Trigger the DCV setup SSM association immediately instead of waiting
Invoke-SafeCommand "Trigger SSM DCV Setup" {
    Write-Host "Finding and triggering SSM associations for this instance..."
    
    # Get associations for this instance
    $associations = aws ssm describe-instance-associations-status --instance-id $InstanceId --query 'InstanceAssociationStatusInfos[?contains(Name, `setup-dcv-users-sessions`)].AssociationId' --output text
    
    if ($associations) {
        Write-Host "Found DCV setup association: $associations"
        aws ssm start-associations-once --association-ids $associations
        Write-Host "Triggered SSM association execution"
    } else {
        Write-Host "No DCV setup association found - will rely on user data setup"
    }
}

# IMPORTANT SECTION 4: Software Installation
Write-Host "`n=== IMPORTANT: Software Installation ===" -ForegroundColor Magenta

# Install Chocolatey (package manager)
Invoke-SafeCommand "Install Chocolatey" {
    Write-Host "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Verify installation
    $chocoVersion = choco --version 2>$null
    if ($chocoVersion) {
        Write-Host "Chocolatey installed successfully: $chocoVersion"
    } else {
        throw "Chocolatey installation failed"
    }
}

# Install Git
Invoke-SafeCommand "Install Git" {
    Write-Host "Installing Git via Chocolatey..."
    choco install git -y --no-progress
    
    # Verify installation
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "Git installed successfully: $gitVersion"
    } else {
        throw "Git installation failed"
    }
}

# Install hello-world test package (for vdi-001 only)
if ($WorkstationKey -eq "vdi-001") {
    Invoke-SafeCommand "Install Hello-World Test Package" {
        Write-Host "Installing hello-world test package..."
        # Create a simple test file to verify this workstation got the additional package
        $testContent = @"
Hello World Test Package
Installed on: $(Get-Date)
Workstation: $WorkstationKey
User: $AssignedUser
This file proves that software_packages_additions worked correctly.
"@
        $testContent | Out-File -FilePath "C:\temp\hello-world-test.txt" -Encoding UTF8
        Write-Host "Hello-world test package installed (test file created)"
    }
}

# FINAL SECTION: Verification and Cleanup
Write-Host "`n=== FINAL: Verification ===" -ForegroundColor Magenta

Invoke-SafeCommand "Final System Verification" {
    Write-Host "`n--- User Verification ---"
    Get-LocalUser | Where-Object { $_.Name -in @('VDIAdmin', $AssignedUser) } | ForEach-Object {
        Write-Host "✅ User: $($_.Name) - Enabled: $($_.Enabled)"
    }
    
    Write-Host "`n--- DCV Session Verification ---"
    $dcvPath = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'
    & $dcvPath list-sessions
    
    Write-Host "`n--- Software Verification ---"
    $chocoVersion = choco --version 2>$null
    if ($chocoVersion) { Write-Host "✅ Chocolatey: $chocoVersion" }
    
    $gitVersion = git --version 2>$null
    if ($gitVersion) { Write-Host "✅ Git: $gitVersion" }
    
    if ($WorkstationKey -eq "vdi-001" -and (Test-Path "C:\temp\hello-world-test.txt")) {
        Write-Host "✅ Hello-world test package: Installed"
    }
    
    Write-Host "`n--- Service Status ---"
    $dcvService = Get-Service -Name dcvserver
    Write-Host "✅ DCV Service: $($dcvService.Status)"
}

Write-Host "`n=== VDI Comprehensive Setup Completed ===" -ForegroundColor Green
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Yellow
Write-Host "Log file: $LogFile" -ForegroundColor Yellow

Stop-Transcript

# Signal completion by creating a marker file
"VDI Setup Completed: $(Get-Date)" | Out-File -FilePath "C:\temp\vdi-setup-complete.txt" -Encoding UTF8