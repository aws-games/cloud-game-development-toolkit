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
      1. Reads the EC2 instance-id from IMDSv2 (token then metadata GET), with a
         BOUNDED retry to ride out transient boot-time IMDS blips. The instance-id
         is MANDATORY: if it cannot be obtained the script THROWS and exits
         non-zero rather than materialise a non-attributable IQN. This guarantees
         the IQN always embeds the instance-id (iqn.1991-05.com.microsoft:i-<id>),
         which downstream instance-id-keyed stale-IQN cleanup relies on.
      2. Computes the desired IQN and sets it via Set-InitiatorPort, but only if
         it differs from the current NodeAddress (idempotent).
      3. Ensures MSiSCSI is Automatic + running.
      4. Logs the resulting IQN.

    All ONTAP contact (discovery, login, igroup add, LUN map, mount) is JOB-TIME
    work handled by buildgraph/attach-clone-lun.ps1 + hydrate-source-lun.ps1.
#>

$ErrorActionPreference = 'Continue'   # per-step: let recoverable/log-only steps
                                      # continue, but a FAILURE TO SET THE IQN is
                                      # fatal (we throw explicitly below) so the
                                      # collision this script prevents is never
                                      # shipped silently.
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
# 1. Derive the host identity from the EC2 instance-id via IMDSv2 (MANDATORY).
#    A bounded retry rides out transient boot-time IMDS blips; on genuine IMDS
#    absence we THROW rather than emit a non-attributable IQN.
# =============================================================================
function Get-InstanceIdViaImds {
    # Bounded retry: ride out a transient boot-time IMDS blip without ever
    # waiting unbounded. 5 attempts x (up to 5s HTTP timeout + 2s sleep) is a
    # hard ceiling of ~33s worst case - well under the ONSTART boot task's
    # tolerance - after which the caller treats IMDS as genuinely absent.
    $imds        = 'http://169.254.169.254'
    $maxAttempts = 5
    $sleepSec    = 2
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
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
            Write-Log "IMDSv2 lookup attempt $attempt/$maxAttempts failed: $($_.Exception.Message)" 'WARN'
            if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds $sleepSec }
        }
    }
    return $null
}

$instanceId = Get-InstanceIdViaImds
if ([string]::IsNullOrWhiteSpace($instanceId)) {
    # FAIL LOUD: the instance-id is mandatory. A local-* / hostname fallback would
    # emit a non-attributable IQN and break instance-id-keyed stale-IQN cleanup,
    # so refuse rather than ship a misleading identity.
    Write-Log 'could not obtain EC2 instance-id from IMDS after bounded retry; refusing to set a non-attributable IQN' 'ERROR'
    throw 'set_unique_iqn: could not obtain EC2 instance-id from IMDS; refusing to set a non-attributable IQN'
}
Write-Log "instance-id from IMDSv2: $instanceId"

# ONTAP/MS-documented Microsoft initiator IQN authority + date, instance-id suffix.
$desiredIqn = "iqn.1991-05.com.microsoft:$instanceId"

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
        # Set-InitiatorPort semantics (MS Storage module): -NodeAddress selects
        # the CURRENT port to modify; -NewNodeAddress is the value to write and is
        # MANDATORY in every parameter set. Passing only -NodeAddress $desiredIqn
        # (as an earlier revision did) throws 'missing mandatory parameters', so
        # the IQN never changed and every agent kept its hostname-derived default
        # - the exact IQN collision this script exists to prevent.
        if ($currentIqn) {
            Set-InitiatorPort -NodeAddress $currentIqn -NewNodeAddress $desiredIqn -ErrorAction Stop
        } else {
            # No current iqn.* port could be read individually; pipe the port
            # object straight into Set-InitiatorPort so -NodeAddress is bound
            # from the pipeline and -NewNodeAddress supplies the target value.
            Get-InitiatorPort -ErrorAction Stop |
                Where-Object { $_.NodeAddress -like 'iqn.*' } |
                Select-Object -First 1 |
                Set-InitiatorPort -NewNodeAddress $desiredIqn -ErrorAction Stop
        }
        Write-Log "initiator IQN set to $desiredIqn"
    }
} catch {
    # FAIL LOUD: a swallowed error here is what let the broken call ship silently.
    # Re-throw so the ONSTART task records a failure and, at bake time, the
    # validation step (which runs this script) surfaces a non-zero exit.
    Write-Log "failed to set initiator IQN to '$desiredIqn': $($_.Exception.Message)" 'ERROR'
    throw "set_unique_iqn: failed to set initiator IQN to '$desiredIqn': $($_.Exception.Message)"
}

# =============================================================================
# 4. Verify and log the resulting IQN. FAIL LOUD if it is not what we intended:
#    a mismatch means igroup registration would bind the WRONG identity.
# =============================================================================
try {
    $finalIqn = (Get-InitiatorPort -ErrorAction Stop |
        Where-Object { $_.NodeAddress -like 'iqn.*' } |
        Select-Object -First 1).NodeAddress
    if ($finalIqn -eq $desiredIqn) {
        Write-Log "resulting initiator IQN: $finalIqn"
    } else {
        Write-Log "resulting initiator IQN is '$finalIqn' but '$desiredIqn' was intended - igroup registration would use the WRONG identity" 'ERROR'
        throw "set_unique_iqn: resulting initiator IQN '$finalIqn' does not match intended '$desiredIqn'"
    }
} catch {
    Write-Log "failed to verify resulting initiator IQN: $($_.Exception.Message)" 'ERROR'
    throw
}

Write-Log 'complete'
