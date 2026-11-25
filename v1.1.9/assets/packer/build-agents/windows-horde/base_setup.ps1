# Fail loud: any unhandled cmdlet error is terminating so a broken bake stops
# at THIS provisioner instead of limping onward to validate_image.
$ErrorActionPreference = 'Stop'

function Write($message) {
    Write-Output $message
}

# Invoke-Choco: run a Chocolatey install and THROW (naming the package) if it
# returns a non-zero exit code. choco does not throw on failure by itself, so we
# must inspect $LASTEXITCODE explicitly or a failed install would pass silently.
function Invoke-Choco {
    param([Parameter(Mandatory = $true)][string] $Package, [string[]] $ChocoArgs = @())
    Write "Installing $Package"
    choco install -y --no-progress $Package @ChocoArgs
    if ($LASTEXITCODE -ne 0) {
        throw "base_setup: choco install '$Package' failed with exit code $LASTEXITCODE"
    }
}

# Download Chocolatey
Write "Installing Chocolatey"
$chocInstall = (New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1")
Out-File -FilePath ./chocInstall.ps1 -InputObject $chocInstall
powershell.exe -File ./chocInstall.ps1
if ($LASTEXITCODE -ne 0) {
    throw "base_setup: Chocolatey bootstrap installer failed with exit code $LASTEXITCODE"
}
$env:path = "$env:path;C:\ProgramData\Chocolatey\bin"
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1

Invoke-Choco -Package git

# Installing OpenSSH Server (Horde/orchestration access to the agent)
Write "Installing OpenSSH and setting service"
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType 'Automatic'

# NOTE: NFS-Client (Install-WindowsFeature NFS-Client) intentionally REMOVED.
# The Horde iSCSI/NTFS thin-clone pipeline mounts LUNs via the MSiSCSI
# initiator (see install_iscsi.ps1), not NFS.

# Python
Invoke-Choco -Package python
refreshenv
pip install botocore boto3
if ($LASTEXITCODE -ne 0) {
    throw "base_setup: pip install of botocore/boto3 failed with exit code $LASTEXITCODE"
}

Write Get-Disk | Where-Object partitionstyle -EQ 'raw'
Get-Disk | Where-Object partitionstyle -EQ \"raw\" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel \"Data Drive\" -Confirm:$false

# Do NOT end on Chocolatey's `RefreshEnv` - it exits non-zero when dot-invoked
# from this process and would fail the Packer provisioner via `exit $LastExitCode`.
# The next provisioner runs in a fresh shell that re-reads PATH anyway.
exit 0
