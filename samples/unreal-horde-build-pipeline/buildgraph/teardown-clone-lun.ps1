<#
    teardown-clone-lun.ps1 - guaranteed teardown of a per-build FlexClone LUN.

    ORDER MATTERS AND IS NOT ARBITRARY:
        1. offline the Windows disk   (flush + release the NTFS volume)
        2. remove the LUN map          (ONTAP refuses to delete a mapped LUN)
        3. delete the clone volume     (releases the parent snapshot)
    Skip step 1 and you yank a mapped LUN from under a live filesystem. Skip
    step 2 and step 3 fails, leaving the clone alive and PINNING its parent
    snapshot - after which snapshot rotation starts failing too, which is how one
    leaked clone becomes a broken pipeline.

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
    [string] $OntapUser = 'fsxadmin'
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
             '-FsxAdminIp "{5}" -OntapUser "{6}" -OntapPasswordSecretName "{7}" -AwsRegion "{8}"') -f `
             $PSCommandPath, $CloneVolumeName, $LunName, $AgentIgroup, $SvmName,
             $FsxAdminIp, $OntapUser, $OntapPasswordSecretName, $AwsRegion
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

if ($failed) {
    # Report loudly, but do not fail the lease: a cleanup failure is an
    # operational signal, not a reason to retroactively fail a green build.
    Write-Warning "[teardown-clone-lun] '$CloneVolumeName' may still exist and PIN its parent snapshot. Check the reaper."
} else {
    Write-Step 'teardown complete'
}
exit 0
