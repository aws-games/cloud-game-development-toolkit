<#
    create-build-client.ps1 - create/refresh the per-build Perforce client.

    The merged Compile node mounts the clone LUN as $MountDrive: and then runs
    `p4 flush ...@N` to stamp the have-list without transferring content. flush
    needs a client whose Root is the clone drive; the Horde-managed workspace
    clients are rooted in the agent sandbox, not on the LUN, and a client named
    $WorkspaceName does not otherwise exist. This creates it, host-less (so any
    build agent can use it, mirroring fsxn-hydrator) and stream-bound so the
    View is generated automatically.

    Invoked via -File so BuildGraph/cmd quoting cannot corrupt the client spec.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $P4Port,
    [Parameter(Mandatory)] [string] $P4User,
    [Parameter(Mandatory)] [string] $WorkspaceName,
    [Parameter(Mandatory)] [string] $Stream,
    [string] $MountDrive = 'W'
)

$ErrorActionPreference = 'Stop'

$root = "${MountDrive}:\"
$spec = @(
    "Client: $WorkspaceName"
    "Owner: $P4User"
    "Root: $root"
    "Options: noallwrite noclobber nocompress unlocked nomodtime normdir"
    "SubmitOptions: submitunchanged"
    "LineEnd: win"
    "Stream: $Stream"
) -join "`n"

Write-Output "[create-build-client] creating client '$WorkspaceName' root=$root stream=$Stream (host-less)"
$spec | & p4.exe -p $P4Port -u $P4User client -i
if ($LASTEXITCODE -ne 0) { throw "p4 client -i failed with exit code $LASTEXITCODE" }
Write-Output "[create-build-client] done"
