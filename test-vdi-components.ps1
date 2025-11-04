# Quick test script to validate VDI critical components
# Run this on a Windows Server 2025 instance to test without full Packer build

$ErrorActionPreference = "Stop"

Write-Host "=== VDI Component Test Script ===" -ForegroundColor Cyan
Write-Host "Testing AWS CLI and SSM Agent installation..." -ForegroundColor Cyan

# Create temp directory
New-Item -ItemType Directory -Force -Path "C:\temp" | Out-Null

# Test 1: Install SSM Agent
Write-Host "`n1. Testing SSM Agent installation..." -ForegroundColor Yellow
try {
    $ssmAgentUrl = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe"
    $ssmAgentPath = "C:\temp\AmazonSSMAgentSetup.exe"

    Write-Host "Downloading SSM Agent..."
    Invoke-WebRequest -Uri $ssmAgentUrl -OutFile $ssmAgentPath -TimeoutSec 300
    
    Write-Host "Installing SSM Agent..."
    Start-Process -FilePath $ssmAgentPath -ArgumentList "/S" -Wait

    Write-Host "Configuring SSM Agent service..."
    Set-Service -Name AmazonSSMAgent -StartupType Automatic
    Start-Service -Name AmazonSSMAgent

    $ssmService = Get-Service -Name "AmazonSSMAgent"
    Write-Host "SSM Agent Status: $($ssmService.Status)" -ForegroundColor Green
} catch {
    Write-Host "SSM Agent test FAILED: $_" -ForegroundColor Red
}

# Test 2: Install AWS CLI
Write-Host "`n2. Testing AWS CLI installation..." -ForegroundColor Yellow
try {
    $awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $awsCliPath = "C:\temp\AWSCLIV2.msi"

    Write-Host "Downloading AWS CLI..."
    Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliPath -TimeoutSec 300
    
    Write-Host "Installing AWS CLI..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $awsCliPath, "/quiet", "/norestart" -Wait

    Write-Host "Verifying AWS CLI installation..."
    Start-Sleep -Seconds 10  # Wait for installation to complete
    
    # Check if AWS CLI executable exists
    $awsExePath = "${env:ProgramFiles}\Amazon\AWSCLIV2\aws.exe"
    if (Test-Path $awsExePath) {
        Write-Host "AWS CLI executable found at: $awsExePath" -ForegroundColor Green
        
        # Test AWS CLI functionality
        $awsVersion = & $awsExePath --version 2>&1
        Write-Host "AWS CLI version: $awsVersion" -ForegroundColor Green
    } else {
        Write-Host "AWS CLI executable NOT found at expected location" -ForegroundColor Red
        
        # Check alternate locations
        $altPaths = @(
            "${env:ProgramFiles(x86)}\Amazon\AWSCLIV2\aws.exe",
            "C:\Program Files\Amazon\AWSCLIV2\aws.exe",
            "C:\Program Files (x86)\Amazon\AWSCLIV2\aws.exe"
        )
        foreach ($altPath in $altPaths) {
            if (Test-Path $altPath) {
                Write-Host "Found AWS CLI at: $altPath" -ForegroundColor Yellow
                break
            }
        }
    }
} catch {
    Write-Host "AWS CLI test FAILED: $_" -ForegroundColor Red
}

# Test 3: Test PATH availability (simulates reboot)
Write-Host "`n3. Testing PATH availability..." -ForegroundColor Yellow
try {
    # Refresh PATH environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # Test if 'aws' command works from PATH
    $awsFromPath = aws --version 2>&1
    Write-Host "AWS CLI from PATH: $awsFromPath" -ForegroundColor Green
} catch {
    Write-Host "AWS CLI not available in PATH: $_" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "Run this script on a fresh Windows Server 2025 instance to see what fails"