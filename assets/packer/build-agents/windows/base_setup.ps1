function Write($message) {
    Write-Output $message
}

try {
    # Download Chocolatey
    Write "Installing Chocolatey"
    $chocInstall = (New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1")
    Out-File -FilePath ./chocInstall.ps1 -InputObject $chocInstall
    powershell.exe -File ./chocInstall.ps1
    $env:path = "$env:path;C:\ProgramData\Chocolatey\bin"
    Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
}
catch {
    Write "Failed to install Chocolatey"
}

try {
    # Java Runtime for Jenkins
    Write "Installing Git"
    choco install -y  --no-progress git
}
catch {
    Write "Failed to install Git"
}

try {
    # Installing OpenSSH Server
    Write "Installing OpenSSH and setting service"
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Set-Service -Name sshd -StartupType 'Automatic'
}
catch {
    Write "Failed to install OpenSSH"
}

try {
    # Installing Client for NFS
    Write "Installing Client for NFS"
    Install-WindowsFeature NFS-Client
}
catch {
    Write "Failed to install Client for NFS"
}

try {
    Write Get-Disk | Where-Object partitionstyle -EQ 'raw'
    Get-Disk | Where-Object partitionstyle -EQ \"raw\" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel \"Data Drive\" -Confirm:$false
}
catch {
    Write "Failed to mount drives"
}
RefreshEnv
