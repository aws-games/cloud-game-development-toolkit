# =============================
# Active Directory Tool Install
# =============================
# Enhanced script for Windows Server 2025 - installs RSAT tools and for AD

Write-Host "Starting Active Directory and DCV preparation..." -ForegroundColor Cyan

# ===========================
# INSTALL AD MANAGEMENT TOOLS
# ===========================

Write-Host "Installing Active Directory management tools..."

try {
    # Single command to install all RSAT AD tools for Windows Server
    Install-WindowsFeature -Name RSAT-AD-PowerShell, RSAT-AD-Tools, RSAT-DNS-Server -IncludeAllSubFeature
    
    Write-Host "Active Directory management tools installed successfully" -ForegroundColor Green
    
    # Verify installation
    $adModule = Get-Module -ListAvailable -Name ActiveDirectory
    if ($adModule) {
        Write-Host "Active Directory PowerShell module is available" -ForegroundColor Green
    } else {
        Write-Host "Active Directory PowerShell module not found" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Failed to install AD tools: $_" -ForegroundColor Red
    throw
}

Write-Host "Active Directory preparation completed successfully!" -ForegroundColor Green