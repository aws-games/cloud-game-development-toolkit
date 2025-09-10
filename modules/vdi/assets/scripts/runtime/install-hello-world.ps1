# Hello World Test Package - VDI Module Testing
$ErrorActionPreference = "Stop"

Write-Host "Installing Hello World test package..."

try {
    # Create test directory
    $testDir = "C:\VDI-Test"
    New-Item -ItemType Directory -Force -Path $testDir
    
    # Write test file to desktop for easy verification
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $testFile = Join-Path $desktopPath "VDI-Hello-World-Test.txt"
    
    $testContent = @"
Hello World from VDI Module!

This file was created by the SSM software installation system.
Package: hello-world
Timestamp: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME

This proves that:
✅ SSM associations are working
✅ Software package scripts execute successfully  
✅ Custom software packages can be added to the VDI module

Test completed successfully!
"@
    
    $testContent | Out-File -FilePath $testFile -Encoding UTF8
    
    # Also write to C:\VDI-Test for system verification
    $systemTestFile = Join-Path $testDir "hello-world-system-test.txt"
    $testContent | Out-File -FilePath $systemTestFile -Encoding UTF8
    
    Write-Host "Hello World test package installed successfully!"
    Write-Host "Test file created at: $testFile"
    Write-Host "System test file created at: $systemTestFile"
    
} catch {
    Write-Host "Hello World test package installation failed: $_" -ForegroundColor Red
    throw
}