<powershell>
# Minimal VDI User Data - Windows Server 2025 Compatible
# Just basic logging and service verification

$ErrorActionPreference = "Continue"

try {
    # Create log entry
    Write-EventLog -LogName Application -Source "Application" -EventId 1001 -EntryType Information -Message "VDI instance started - user data executing"
    
    # Ensure DCV service is set to automatic (should already be from AMI)
    Set-Service -Name dcvserver -StartupType Automatic -ErrorAction SilentlyContinue
    
    # Log completion
    Write-EventLog -LogName Application -Source "Application" -EventId 1002 -EntryType Information -Message "VDI user data completed - SSM will handle user creation"
    
} catch {
    Write-EventLog -LogName Application -Source "Application" -EventId 9001 -EntryType Error -Message "VDI user data failed: $_"
}
</powershell>