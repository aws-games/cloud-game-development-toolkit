<powershell>
# Create log directory first thing
$logDir = "C:\Windows\Temp"
$logFile = "$logDir\userdata-log.txt"

function Write-Log {
    param (
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    # Write to log file
    $logMessage | Out-File -FilePath $logFile -Append

    # Write to console
    Write-Output $logMessage
}

Write-Log "Starting User Data Script"

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

# Don't set this before Set-ExecutionPolicy as it throws an error
$ErrorActionPreference = "stop"

# Create log file
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Write-Log "Created log directory: $logDir"
}

"User Data script started at $(Get-Date)" | Out-File -FilePath $logFile -Force

# Remove HTTP listener
Write-Log "Removing existing WinRM listeners"
try {
    Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse -ErrorAction SilentlyContinue
    Write-Log "Existing listeners removed"
}
catch {
    Write-Log "Error removing listeners: $_"
}

Write-Log "Configuring WinRM settings"
Set-Item WSMan:\localhost\MaxTimeoutms 1800000
Set-Item WSMan:\localhost\Service\Auth\Basic $true

Write-Log "Creating self-signed certificate for WinRM"
$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"
Write-Log "Certificate created with thumbprint: $($Cert.Thumbprint)"

Write-Log "Creating WinRM HTTPS listener"
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force

# WinRM
Write-Log "Setting up WinRM"

Write-Log "Running WinRM configuration commands"

try {
    Write-Log "Running winrm quickconfig"
    cmd.exe /c winrm quickconfig -q

    Write-Log "Setting WinRM config parameters"
    cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
    cmd.exe /c winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
    cmd.exe /c winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
    cmd.exe /c winrm set "winrm/config/client" '@{AllowUnencrypted="true"}'
    cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}'
    cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}'
    cmd.exe /c winrm set "winrm/config/service/auth" '@{CredSSP="true"}'

    Write-Log "Setting up WinRM HTTPS listener"
    cmd.exe /c winrm set "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"packer`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"

    Write-Log "Configuring Windows Firewall"
    cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
    cmd.exe /c netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow
    cmd.exe /c netsh firewall add portopening TCP 5986 "Port 5986"

    Write-Log "Restarting WinRM service"
    cmd.exe /c net stop winrm
    cmd.exe /c sc config winrm start= auto
    cmd.exe /c net start winrm

    Write-Log "WinRM configuration completed successfully"
}
catch {
    Write-Log "Error configuring WinRM: $_"
}

# Verify WinRM is running
try {
    $service = Get-Service -Name winrm
    Write-Log "WinRM service status: $($service.Status)"

    # Check listeners
    $listeners = cmd.exe /c winrm enumerate winrm/config/listener
    Write-Log "WinRM listeners: $listeners"
}
catch {
    Write-Log "Error checking WinRM status: $_"
}

Write-Log "User Data script completed at $(Get-Date)"
</powershell>
