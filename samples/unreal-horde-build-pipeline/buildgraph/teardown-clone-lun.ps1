<#
    teardown-clone-lun.ps1 - guaranteed teardown of a per-build FlexClone LUN.

    ORDER MATTERS AND IS NOT ARBITRARY:
        1. offline the Windows disk   (flush + release the NTFS volume)
        2. remove the LUN map          (ONTAP refuses to delete a mapped LUN)
        3. delete the clone volume     (releases the parent snapshot)
        4. delete the per-job p4 client (AFTER its data is gone; idempotent)
    Skip step 1 and you yank a mapped LUN from under a live filesystem. Skip
    step 2 and step 3 fails, leaving the clone alive and PINNING its parent
    snapshot - after which snapshot rotation starts failing too, which is how one
    leaked clone becomes a broken pipeline. Step 4 is last so the client (pure
    have-list metadata) never outlives its backing clone in the wrong direction;
    a missing client is treated as success.

    WHY A LEASE HOOK, NOT A GRAPH NODE: BuildPipeline.xml used to rely on
    RunLate="true", which is not a BuildGraph <Node> attribute (UE 5.7), and the
    semantics it wanted do not exist either - a node ordered after a FAILED node
    is *Skipped*, not run. So cleanup did not happen on precisely the path it was
    written for. Horde runs the script named by %UE_HORDE_CLEANUP% when the lease
    ends regardless of outcome; that is the correct hook. This script both
    REGISTERS itself into it (-Register) and performs the work (-Execute).

    IDEMPOTENT BY REQUIREMENT: on success the graph's own cleanup node has usually
    already run, so this executes second and must tolerate everything being gone -
    and must exit 0 when it is, or a green lease gets marked bad.

    NOT COVERED: a hard Spot reclaim can kill the agent without running any
    on-agent path. That leak needs an off-agent reaper on a schedule; see README.
#>

[CmdletBinding()]
param(
    [switch] $Register,
    [switch] $Execute,
    [Parameter(Mandatory)] [string] $CloneVolumeName,
    [Parameter(Mandatory)] [string] $LunName,
    [Parameter(Mandatory)] [string] $AgentIgroup,
    [Parameter(Mandatory)] [string] $SvmName,
    [Parameter(Mandatory)] [string] $FsxAdminIp,
    [Parameter(Mandatory)] [string] $OntapPasswordSecretName,
    [Parameter(Mandatory)] [string] $AwsRegion,
    [string] $OntapUser = 'fsxadmin',
    # Per-job Perforce client to delete AFTER the clone volume is gone. Optional:
    # empty skips the p4 step (single-build / no-client callers). Idempotent -
    # a missing client is treated as success.
    [string] $P4Port   = '',
    [string] $P4User   = '',
    [string] $P4Client = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Write-Step($m) { Write-Host "[teardown-clone-lun] $m" }

# --------------------------------------------------------------------------
# -Register: append an invocation of ourselves to Horde's lease-cleanup script.
# --------------------------------------------------------------------------
if ($Register) {
    $hook = $env:UE_HORDE_CLEANUP
    if ([string]::IsNullOrWhiteSpace($hook)) {
        Write-Warning 'UE_HORDE_CLEANUP is not set - not running under a Horde lease, so GUARANTEED teardown is NOT registered. The graph cleanup node is the only teardown in this run.'
        exit 0
    }
    $line = ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -Execute ' +
             '-CloneVolumeName "{1}" -LunName "{2}" -AgentIgroup "{3}" -SvmName "{4}" ' +
             '-FsxAdminIp "{5}" -OntapUser "{6}" -OntapPasswordSecretName "{7}" -AwsRegion "{8}" ' +
             '-P4Port "{9}" -P4User "{10}" -P4Client "{11}"') -f `
             $PSCommandPath, $CloneVolumeName, $LunName, $AgentIgroup, $SvmName,
             $FsxAdminIp, $OntapUser, $OntapPasswordSecretName, $AwsRegion,
             $P4Port, $P4User, $P4Client
    Add-Content -Path $hook -Value $line
    Write-Step "registered teardown of '$CloneVolumeName' in $hook"
    exit 0
}

if (-not $Execute) {
    Write-Error 'Pass either -Register (from the graph) or -Execute (from the Horde lease hook).'
    exit 2
}

Import-Module (Join-Path $PSScriptRoot 'OntapSan.psm1') -Force

$failed  = $false
$lunPath = "/vol/$CloneVolumeName/$LunName"

try {
    $ctx = Connect-Ontap -ManagementEndpoint $FsxAdminIp -PasswordSecretName $OntapPasswordSecretName `
                         -AwsRegion $AwsRegion -User $OntapUser -Svm $SvmName
} catch {
    Write-Warning "[teardown-clone-lun] cannot reach ONTAP: $($_.Exception.Message)"
    Write-Warning "[teardown-clone-lun] clone '$CloneVolumeName' is ORPHANED - the off-agent reaper must collect it."
    exit 0
}

# 1. Offline the disk first.
try { Dismount-SanLun -Ctx $ctx -LunPath $lunPath }
catch { Write-Step "offline step: $($_.Exception.Message) - continuing" }

# 2. Then the LUN map, or the volume delete is refused.
try { Remove-OntapLunMap -Ctx $ctx -LunPath $lunPath -Igroup $AgentIgroup }
catch { Write-Warning "[teardown-clone-lun] could not remove LUN map: $($_.Exception.Message)"; $failed = $true }

# 3. Finally the clone volume, which releases the parent snapshot.
try { Remove-OntapVolume -Ctx $ctx -Name $CloneVolumeName }
catch { Write-Warning "[teardown-clone-lun] could not delete clone: $($_.Exception.Message)"; $failed = $true }

# 4. Delete the per-job Perforce client LAST - after its backing clone volume is
#    gone, so a client only outlives its data by the width of this step, never
#    the reverse. A p4 client is pure have-list metadata (no file content), so
#    deleting it is safe and just frees the name. IDEMPOTENT by requirement: on
#    the success path the graph's Cleanup node usually deleted it already, so a
#    "client doesn't exist" here is SUCCESS, not failure. p4 client -d prints
#    "Client '<name>' doesn't exist." to stderr and exits non-zero in that case,
#    so we tolerate it explicitly rather than tripping $failed. Skipped when no
#    client name was passed (single-build / no-client callers).
if (-not [string]::IsNullOrWhiteSpace($P4Client)) {
    try {
        # Do not let a non-zero p4 exit abort the lease hook; inspect it instead.
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $out = & p4.exe -p $P4Port -u $P4User client -d $P4Client 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP
        $text = ($out | Out-String)
        if ($code -eq 0 -or $text -match "doesn't exist|does not exist|no such client") {
            Write-Step "p4 client '$P4Client' deleted (or already gone)"
        } else {
            Write-Warning "[teardown-clone-lun] p4 client -d '$P4Client' exit=$code : $($text.Trim())"
            $failed = $true
        }
    } catch {
        Write-Warning "[teardown-clone-lun] p4 client -d '$P4Client' errored: $($_.Exception.Message)"
        $failed = $true
    }
}

if ($failed) {
    # Report loudly, but do not fail the lease: a cleanup failure is an
    # operational signal, not a reason to retroactively fail a green build.
    Write-Warning "[teardown-clone-lun] '$CloneVolumeName' may still exist and PIN its parent snapshot. Check the reaper."
} else {
    Write-Step 'teardown complete'
}
exit 0
