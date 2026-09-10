<#
    set_unique_iqn.ps1 - PER-BOOT, INPUT-FREE iSCSI initiator identity.

    This script is BAKED onto the AMI (dropped at C:\ProgramData\horde\set_unique_iqn.ps1
    by the Packer build) and run on EVERY boot by an ONSTART Scheduled Task
    (RunLevel Highest, SYSTEM) registered at image time. It runs BEFORE any Horde
    job. It takes NO input: no ONTAP, no Perforce, no Terraform values.

    WHY THIS EXISTS
    ---------------
    The Windows default initiator IQN is derived from the machine name and is
    generated per install. Agents cloned from one AMI can therefore end up
    presenting the SAME (or a colliding) IQN to the FSxN/ONTAP SAN. iSCSI
    authorises by initiator IQN (igroups), so a collision breaks the per-agent
    igroup isolation model: two hosts sharing one IQN can map the same clone LUN,
    which is silent NTFS corruption.

    The fix is to materialise a GUARANTEED-UNIQUE, DETERMINISTIC initiator IQN
    derived from the EC2 instance-id every boot:
        iqn.1991-05.com.microsoft:<instance-id>
    (iqn.1991-05.com.microsoft is the Microsoft iSCSI initiator IQN authority /
    date, per the MS/ONTAP-documented format; the instance-id suffix makes it
    distinct across agents and stable across reboots of the same instance.)

    WHAT IT DOES
    ------------
      1. Reads the EC2 instance-id from IMDSv2 (token then metadata GET). On IMDS
         failure it falls back to a stable local identifier (machine SID-based
         GUID, else hostname) and LOGS the fallback.
      2. Computes the desired IQN and sets it via Set-InitiatorPort, but only if
         it differs from the current NodeAddress (idempotent).
      3. Ensures MSiSCSI is Automatic + running.
      4. Logs the resulting IQN.

    All ONTAP contact (discovery, login, igroup add, LUN map, mount) is JOB-TIME
    work handled by buildgraph/attach-clone-lun.ps1 + hydrate-source-lun.ps1.
#>

$ErrorActionPreference = 'Continue'   # a partial config must not abort the boot
$ProgressPreference    = 'SilentlyContinue'

$LogDir = 'C:\ProgramData\horde'
$LogFile = Join-Path $LogDir 'set_unique_iqn.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = '[{0}] [{1}] [set-unique-iqn] {2}' -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'), $Level, $Message
    Write-Host $line
    try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch { }
}

Write-Log 'starting per-boot unique-IQN materialisation'

# =============================================================================
# 1. Derive a stable, unique identifier for this host.
#    Preferred: EC2 instance-id via IMDSv2. Fallback: local machine GUID/hostname.
# =============================================================================
function Get-InstanceIdViaImds {
    $imds = 'http://169.254.169.254'
    try {
        $token = Invoke-RestMethod -Method Put -Uri "$imds/latest/api/token" `
            -Headers @{ 'X-aws-ec2-metadata-token-ttl-seconds' = '21600' } `
            -TimeoutSec 5 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'empty IMDSv2 token' }

        $instanceId = Invoke-RestMethod -Method Get -Uri "$imds/latest/meta-data/instance-id" `
            -Headers @{ 'X-aws-ec2-metadata-token' = $token } `
            -TimeoutSec 5 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($instanceId)) { throw 'empty instance-id' }

        return $instanceId.Trim()
    } catch {
        Write-Log "IMDSv2 lookup failed: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Get-StableLocalId {
    # Fallback identifier when IMDS is unavailable (e.g. running off-EC2). Must be
    # stable across reboots of the same host so the IQN does not churn.
    try {
        $sid = (Get-CimInstance Win32_UserAccount -Filter "SID like 'S-1-5-21-%'" -ErrorAction Stop |
            Select-Object -First 1).SID
        if ($sid) {
            # Hash the machine SID prefix into a compact deterministic GUID-like tag.
            $domainSid = ($sid -split '-')[0..6] -join '-'
            $md5 = [System.Security.Cryptography.MD5]::Create()
            $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($domainSid))
            $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
            return "local-$hex"
        }
    } catch {
        Write-Log "SID-based fallback failed: $($_.Exception.Message)" 'WARN'
    }
    # Last resort: hostname (lowercased). Still stable per host.
    return ('local-{0}' -f $env:COMPUTERNAME.ToLower())
}

$instanceId = Get-InstanceIdViaImds
if ($instanceId) {
    Write-Log "instance-id from IMDSv2: $instanceId"
    $idSuffix = $instanceId
} else {
    $idSuffix = Get-StableLocalId
    Write-Log "falling back to stable local identifier: $idSuffix" 'WARN'
}

# ONTAP/MS-documented Microsoft initiator IQN authority + date, host-unique suffix.
$desiredIqn = "iqn.1991-05.com.microsoft:$idSuffix"

# =============================================================================
# 2. Ensure MSiSCSI is Automatic + running (baked Automatic in install_iscsi.ps1,
#    reasserted here so the initiator is live before we read/set the port).
# =============================================================================
try {
    Set-Service -Name MSiSCSI -StartupType Automatic -ErrorAction Stop
    $svc = Get-Service -Name MSiSCSI -ErrorAction Stop
    if ($svc.Status -ne 'Running') {
        Start-Service -Name MSiSCSI -ErrorAction SilentlyContinue
        $svc = Get-Service -Name MSiSCSI
    }
    Write-Log "MSiSCSI service: Status=$($svc.Status) StartType=$($svc.StartType)"
} catch {
    Write-Log "failed to ensure MSiSCSI running: $($_.Exception.Message)" 'ERROR'
}

# =============================================================================
# 3. Set the unique initiator IQN, idempotently.
# =============================================================================
try {
    $currentIqn = $null
    try {
        $currentIqn = (Get-InitiatorPort -ErrorAction Stop |
            Where-Object { $_.NodeAddress -like 'iqn.*' } |
            Select-Object -First 1).NodeAddress
    } catch {
        Write-Log "could not read current initiator port: $($_.Exception.Message)" 'WARN'
    }

    if ($currentIqn -eq $desiredIqn) {
        Write-Log "initiator IQN already correct: $currentIqn (no change)"
    } else {
        Write-Log "setting initiator IQN: '$currentIqn' -> '$desiredIqn'"
        Set-InitiatorPort -NodeAddress $desiredIqn -ErrorAction Stop
        Write-Log "initiator IQN set to $desiredIqn"
    }
} catch {
    Write-Log "failed to set initiator IQN to '$desiredIqn': $($_.Exception.Message)" 'ERROR'
}

# =============================================================================
# 4. Log the resulting IQN for evidence.
# =============================================================================
try {
    $finalIqn = (Get-InitiatorPort -ErrorAction Stop |
        Where-Object { $_.NodeAddress -like 'iqn.*' } |
        Select-Object -First 1).NodeAddress
    Write-Log "resulting initiator IQN: $finalIqn"
} catch {
    Write-Log "could not read resulting initiator IQN: $($_.Exception.Message)" 'WARN'
}

Write-Log 'complete'
