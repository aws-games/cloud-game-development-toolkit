<#
    hydrate-source-lun.ps1 - the periodic hydrator ("builder persona").

    Attach the persistent SOURCE LUN, p4 sync it to head, then snapshot it as
    cl-<changelist>. Every per-build FlexClone is taken from one of those
    snapshots. Called from HydratePipeline.xml.

    THE HYDRATOR IS NOW WINDOWS, NOT LINUX. That is the substantive consequence
    of moving to SAN: the LUN carries NTFS, so the host that writes it must be
    Windows and must be the ONLY writer. A Linux host cannot safely mount it, and
    two Windows hosts cannot mount it at once.

    TWO NON-OBVIOUS REQUIREMENTS, both of which silently corrupt the demo if
    skipped:

    1. THE SNAPSHOT NAME MUST ENCODE THE CHANGELIST. The build agent transplants
       the have-list with `p4 flush @<CL>`, which is metadata-only and simply
       trusts the CL it is given. Name a snapshot after the wrong changelist and
       every clone from it has a workspace that silently disagrees with the server
       about what is on disk. ADR-003 specifies cl-{N}; this script derives N
       itself from the sync rather than accepting a caller-supplied string.

    2. THE NTFS WRITE CACHE MUST BE FLUSHED BEFORE THE SNAPSHOT. An ONTAP
       snapshot captures blocks as the array sees them, so anything still in the
       Windows cache is absent from it. New-OntapSnapshot -FlushDriveLetter does
       the Write-VolumeCache; do not remove it.

    THE CLIENT MUST BE HOST-LESS. The build agents `p4 flush` against this same
    client to inherit its have-list. A client with Host: set can only be used from
    that machine, which makes the whole hand-off impossible. LineEnd is pinned to
    'win' rather than 'local' for the same reason - the consuming agents are
    Windows, and a mismatch makes every text file look stale and re-transfer.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Stream,
    [Parameter(Mandatory)] [string] $SourceVolume,
    [Parameter(Mandatory)] [string] $LunName,
    [Parameter(Mandatory)] [string] $HydratorIgroup,
    [Parameter(Mandatory)] [string] $SvmName,
    [Parameter(Mandatory)] [string] $FsxAdminIp,
    [Parameter(Mandatory)] [string] $OntapPasswordSecretName,
    [Parameter(Mandatory)] [string] $AwsRegion,
    [Parameter(Mandatory)] [string] $IscsiPortals,           # comma-separated
    [Parameter(Mandatory)] [string] $P4Port,
    [string] $P4User            = 'perforce',
    [string] $P4PasswordSecret  = '',
    [string] $WorkspaceName     = 'fsxn-hydrator',
    [string] $OntapUser         = 'fsxadmin',
    [string] $MountDrive        = 'S',
    [string] $LunSize           = '250g',
    # Only for first-ever provisioning of a brand-new RAW LUN. Refuses to touch
    # an already-initialised disk even when passed.
    [switch] $FormatIfRaw
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'OntapSan.psm1') -Force

function Phase([string] $Name, [scriptblock] $Body) {
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    $r = & $Body
    $t.Stop()
    Write-Host ("HYDRATE_TIMING {0}_ms={1}" -f $Name, [int]$t.Elapsed.TotalMilliseconds)
    return $r
}

$ctx     = Connect-Ontap -ManagementEndpoint $FsxAdminIp -PasswordSecretName $OntapPasswordSecretName `
                         -AwsRegion $AwsRegion -User $OntapUser -Svm $SvmName
$lunPath = "/vol/$SourceVolume/$LunName"

Write-Host '=== 1. provision (create-if-absent) and attach the source LUN ==='
New-OntapLun -Ctx $ctx -LunPath $lunPath -Size $LunSize

$iqn = Get-LocalIqn
Write-Host "  hydrator IQN: $iqn"
# -SingleHost is the guard that keeps this safe: if the igroup already holds a
# DIFFERENT initiator, another host believes it owns this NTFS volume, and we
# refuse rather than becoming a second writer.
Add-OntapIgroupInitiator -Ctx $ctx -Igroup $HydratorIgroup -Iqn $iqn -SingleHost

New-OntapLunMap -Ctx $ctx -LunPath $lunPath -Igroup $HydratorIgroup
Connect-SanPortal -PortalAddresses ($IscsiPortals -split '\s*,\s*' | Where-Object { $_ })

$drive = Phase 'attach' {
    if ($FormatIfRaw) { Mount-SanLun -Ctx $ctx -LunPath $lunPath -DriveLetter $MountDrive -Format }
    else              { Mount-SanLun -Ctx $ctx -LunPath $lunPath -DriveLetter $MountDrive }
}
Write-Host "  source workspace at $drive"

Write-Host '=== 2. p4 sync the source LUN to head ==='
$env:P4PORT   = $P4Port
$env:P4USER   = $P4User
$env:P4TRUST  = Join-Path $env:TEMP 'hydrator.p4trust'
$env:P4TICKETS = Join-Path $env:TEMP 'hydrator.p4tickets'
& p4 trust -y *> $null

if ($P4PasswordSecret) {
    $pw = & aws secretsmanager get-secret-value --secret-id $P4PasswordSecret --region $AwsRegion --query SecretString --output text
    if ($LASTEXITCODE -eq 0 -and $pw) { $pw | & p4 login *> $null }
    else { Write-Warning "could not read P4 password secret '$P4PasswordSecret' - relying on an existing ticket" }
}

# Host-less, LineEnd=win. See the header for why both matter.
$spec = @"
Client: $WorkspaceName
Owner: $P4User
Root: $drive\
Options: noallwrite noclobber nocompress unlocked nomodtime normdir
SubmitOptions: submitunchanged
LineEnd: win
Stream: $Stream
"@
$spec | & p4 client -i | Write-Host

$cl = Phase 'p4_head_changelist' {
    $out = & cmd.exe /c "p4 changes -m1 $Stream/... 2>&1"
    ($out -split '\s+')[1]
}
if (-not ($cl -match '^\d+$')) { throw "Could not determine head changelist for ${Stream} (got '$cl')." }
Write-Host "  head changelist: $cl"

$syncLog = Join-Path $env:TEMP "hydrate-sync-$cl.log"
Phase 'p4_sync' { & cmd.exe /c "p4 -c $WorkspaceName sync $Stream/...@$cl > `"$syncLog`" 2>&1" } | Out-Null
$rc = $LASTEXITCODE
$lines = @(Get-Content $syncLog -ErrorAction SilentlyContinue).Count
Write-Host "  sync touched $lines file(s); rc=$rc"
if ($rc -ne 0) {
    Get-Content $syncLog -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
    # "up-to-date" is reported as a non-zero rc by some p4 builds; only fail on a
    # log that actually shows an error.
    if (Select-String -Path $syncLog -Pattern 'error|failed|cannot' -Quiet -ErrorAction SilentlyContinue) {
        throw "p4 sync failed - see $syncLog"
    }
}

Write-Host '=== 3. snapshot as cl-<changelist> ==='
# The flush is what makes the snapshot usable. Do not remove it.
New-OntapSnapshot -Ctx $ctx -VolumeName $SourceVolume -SnapshotName "cl-$cl" -FlushDriveLetter $MountDrive

Write-Host "HYDRATE_OK volume=$SourceVolume snapshot=cl-$cl changelist=$cl"
Write-Host ''
Write-Host "Build agents cloning this snapshot MUST run: p4 flush $Stream/...@$cl"
Write-Host 'Pass that changelist to BuildPipeline.xml as -set:SnapshotChangelist=<N>.'
