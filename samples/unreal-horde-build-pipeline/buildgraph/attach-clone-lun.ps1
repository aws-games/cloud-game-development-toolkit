<#
    attach-clone-lun.ps1 - per-build hydration over iSCSI.

    Clone the source volume's snapshot, map the clone's LUN to this agent, bring
    it online as a drive letter, and register the teardown hook. Replaces the
    NFS mount the sample used to do, because Windows NFSv3 cannot run a UBA
    build at all (see OntapSan.psm1 for the evidence).

    Called from BuildPipeline.xml's "Clone And Mount" node. Emits
    FLEXCLONE_TIMING lines so each phase is measurable in the Horde step log -
    that instrumentation is the demo.

    Reference timings on a 49.55 GB / 268,730-file UE 5.7 workspace:
        clone_create   ~1.2 s
        lun_map        ~0.1 s
        iscsi_attach   ~1.7 s
        disk_online    ~2.5 s
        total          ~9.7 s   (vs 8m23s for a cold p4 sync)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SourceVolume,
    [Parameter(Mandatory)] [string] $SnapshotName,
    [Parameter(Mandatory)] [string] $CloneVolumeName,
    [Parameter(Mandatory)] [string] $LunName,
    [Parameter(Mandatory)] [string] $AgentIgroup,
    [Parameter(Mandatory)] [string] $SvmName,
    [Parameter(Mandatory)] [string] $FsxAdminIp,
    [Parameter(Mandatory)] [string] $OntapPasswordSecretName,
    [Parameter(Mandatory)] [string] $AwsRegion,
    [Parameter(Mandatory)] [string] $IscsiPortals,      # comma-separated
    [string] $OntapUser  = 'fsxadmin',
    [string] $MountDrive = 'W'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'OntapSan.psm1') -Force

$sw = [System.Diagnostics.Stopwatch]::StartNew()
function Phase([string] $Name, [scriptblock] $Body) {
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & $Body
    $t.Stop()
    Write-Host ("FLEXCLONE_TIMING {0}_ms={1}" -f $Name, [int]$t.Elapsed.TotalMilliseconds)
    return $result
}

$ctx     = Connect-Ontap -ManagementEndpoint $FsxAdminIp -PasswordSecretName $OntapPasswordSecretName `
                         -AwsRegion $AwsRegion -User $OntapUser -Svm $SvmName
$lunPath = "/vol/$CloneVolumeName/$LunName"

# Register teardown BEFORE creating anything, so a failure anywhere below is
# still cleaned up. Horde runs UE_HORDE_CLEANUP when the lease ends whatever the
# outcome; a graph node ordered after a FAILED node is Skipped and never runs.
& (Join-Path $PSScriptRoot 'teardown-clone-lun.ps1') -Register `
    -CloneVolumeName $CloneVolumeName -LunName $LunName -AgentIgroup $AgentIgroup `
    -SvmName $SvmName -FsxAdminIp $FsxAdminIp -OntapUser $OntapUser `
    -OntapPasswordSecretName $OntapPasswordSecretName -AwsRegion $AwsRegion

Write-Host "=== hydrating $CloneVolumeName from ${SourceVolume}@${SnapshotName} ==="

# This agent's IQN must be in the shared clone igroup or the LUN map grants it
# nothing. Self-registering is safe HERE (and only here): every clone LUN is used
# by exactly one job on one agent, so a multi-host igroup cannot produce two
# writers on one LUN. The SOURCE LUN's igroup is single-host and is handled by
# hydrate-source-lun.ps1 with -SingleHost.
$iqn = Get-LocalIqn
Write-Host "  this agent: $iqn"
Add-OntapIgroupInitiator -Ctx $ctx -Igroup $AgentIgroup -Iqn $iqn

Phase 'clone_create' { New-OntapFlexClone -Ctx $ctx -ParentVolume $SourceVolume `
                        -SnapshotName $SnapshotName -CloneName $CloneVolumeName | Out-Null }

Phase 'lun_map'      { New-OntapLunMap -Ctx $ctx -LunPath $lunPath -Igroup $AgentIgroup }

Phase 'iscsi_attach' { Connect-SanPortal -PortalAddresses ($IscsiPortals -split '\s*,\s*' | Where-Object { $_ }) }

$drive = Phase 'disk_online' { Mount-SanLun -Ctx $ctx -LunPath $lunPath -DriveLetter $MountDrive }

$sw.Stop()
Write-Host ("FLEXCLONE_TIMING total_hydration_ms={0}" -f [int]$sw.Elapsed.TotalMilliseconds)

if (-not (Test-Path "${drive}\")) { throw "Clone attached but ${drive}\ is not readable." }
Write-Host "=== workspace ready at $drive ==="
Get-Volume -DriveLetter $MountDrive.TrimEnd(':') -ErrorAction SilentlyContinue |
    Format-Table DriveLetter, FileSystemLabel, FileSystem,
                 @{N = 'SizeGB'; E = { [int]($_.Size / 1GB) }},
                 @{N = 'FreeGB'; E = { [int]($_.SizeRemaining / 1GB) }} -AutoSize |
    Out-String | Write-Host
