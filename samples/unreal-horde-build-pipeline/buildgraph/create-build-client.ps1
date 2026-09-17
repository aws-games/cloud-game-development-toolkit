<#
    create-build-client.ps1 - create/refresh the PER-JOB Perforce client.

    The merged Compile node mounts the clone LUN as $MountDrive: and then runs
    `p4 flush ...@N` to stamp the have-list without transferring content. flush
    needs a client whose Root is the clone drive; the Horde-managed workspace
    clients are rooted in the agent sandbox, not on the LUN.

    PER-JOB, NOT SHARED. Earlier this created a single fixed client named
    $WorkspaceName (default "BuildWorkspace") shared by every build. Two builds
    of the same stream running concurrently then took turns owning ONE client
    whose Root is a drive letter, so one job's `p4 flush @N` stamped the
    have-list the OTHER job's `p4 sync` then trusted - the loser silently
    compiled a stale tree and still exited 0. A p4 client is have-list state, so
    it MUST be per-job, exactly like the clone volume it is rooted on.

    NAME: hordeclone_<StreamSafe>_<CloneVolumeName>. The clone volume name is
    already unique per job (build_<jobid>), so it carries the per-execution id;
    the stream prefix makes the name greppable and multi-stream-ready, and the
    ^hordeclone_ prefix is the orphan reaper's name-gate. When -WorkspaceName is
    empty the name is DERIVED here (the graph passes the derived name in as
    -WorkspaceName; empty is a defensive fallback so this script is correct on
    its own). StreamSafe is computed the SAME way Terraform computes it in
    locals.tf (lowercase, non-alphanumeric runs -> "_", trimmed) so the derived
    name matches what the graph uses for `p4 -c` on flush/sync.

    View is auto-scoped to the ONE stream via the Stream: field of the spec, so
    the client can only touch $Stream - no manual View mapping to get wrong.

    Invoked via -File so BuildGraph/cmd quoting cannot corrupt the client spec.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $P4Port,
    [Parameter(Mandatory)] [string] $P4User,
    [Parameter(Mandatory)] [string] $Stream,
    [string] $WorkspaceName    = '',
    [string] $CloneVolumeName  = '',
    [string] $MountDrive       = 'W'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-StreamSafe([string] $s) {
    # Mirror locals.tf fsxn_client_stream_safe: lowercase, collapse every run of
    # non-alphanumeric characters to a single '_', then trim leading/trailing
    # '_'. //YourGame/main -> yourgame_main.
    ($s.ToLowerInvariant() -replace '[^a-z0-9]+', '_').Trim('_')
}

# Derive the per-job client name when the graph did not pass one. The clone
# volume name is the per-execution id; the stream is encoded for greppability.
$clientName = $WorkspaceName
if ([string]::IsNullOrWhiteSpace($clientName)) {
    if ([string]::IsNullOrWhiteSpace($CloneVolumeName)) {
        throw 'create-build-client: need -WorkspaceName or -CloneVolumeName to name the per-job client.'
    }
    $streamSafe = ConvertTo-StreamSafe $Stream
    $clientName = "hordeclone_${streamSafe}_${CloneVolumeName}"
}

$root = "${MountDrive}:\"
$spec = @(
    "Client: $clientName"
    "Owner: $P4User"
    "Root: $root"
    "Options: noallwrite noclobber nocompress unlocked nomodtime normdir"
    "SubmitOptions: submitunchanged"
    "LineEnd: win"
    "Stream: $Stream"
) -join "`n"

Write-Output "[create-build-client] creating client '$clientName' root=$root stream=$Stream (per-job, host-less)"
$spec | & p4.exe -p $P4Port -u $P4User client -i
if ($LASTEXITCODE -ne 0) { throw "p4 client -i failed with exit code $LASTEXITCODE" }
Write-Output "[create-build-client] done"
