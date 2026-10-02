<#
    reap-orphans.ps1 - OFF-AGENT reaper for leaked per-job Perforce clients and
    their backing FlexClone volumes.

    WHY THIS EXISTS (the leak the on-agent paths cannot close): the guaranteed
    teardown is a Horde UE_HORDE_CLEANUP lease hook, and the fast path is the
    "Cleanup Clone" graph node. BOTH run ON THE BUILD AGENT. A HARD SPOT RECLAIM
    kills the agent instance without running either, so the per-job clone volume
    (which PINS its parent snapshot and eventually breaks snapshot rotation) and
    the per-job p4 client (which accumulates as dead have-list metadata) leak.

    WHERE IT RUNS: on the idle SINGLE-WRITER SyncPool (the hydrator). That pool
    is min=max=1 Windows, already has ONTAP REST reachability and the OntapSan
    module, and is not in the hot build path, so a periodic sweep there is free.
    Scheduled from globals.json (a "reap" template on the same SyncPool stream).

    THE SAFETY CONTRACT - READ IT. Deleting the wrong client or volume corrupts a
    LIVE build. So a p4 client is deleted ONLY when ALL THREE gates pass:
        GATE 1  NAME:          the client name matches ^hordeclone_  (ours)
        GATE 2  CLONE GONE:    its backing FlexClone volume no longer exists in ONTAP
        GATE 3  JOB NOT LIVE:  the owning Horde job is not in a running/pending state
    ANY uncertainty - ONTAP unreachable, Horde API down/ambiguous, a name we do
    not understand, a volume that still exists - means DO NOT DELETE. The cost of
    a missed sweep is one more leaked object collected next run; the cost of a
    wrong delete is a corrupted in-flight build. The asymmetry decides every
    ambiguous case in favor of keeping.

    Orphaned clone VOLUMES (hordeclone name derives from them, build_* pattern)
    whose Horde job is dead are also removed - but only through the SAME
    three-gate logic, and only after any client is gone, mirroring the on-agent
    teardown order (client outlives data by at most one step, never the reverse).

    COORDINATION: this reaper deletes ONLY clone volumes and
    the p4 clients rooted on them. It does NOT touch cl-N SOURCE snapshots
    nor igroup membership.
    Deleting a clone volume does NOT synchronously release its hold on the parent
    snapshot: ONTAP recovery-queues the deleted clone as a DEL volume and the
    parent's has_flexclone stays TRUE until that entry is purged (observed
    >4 min). Snapshot pruning stays out of this reaper so the two do not race;
    the snapshot-prune guard stays safe (it skips a still-busy parent) but prune
    convergence lags by the recovery-queue retention window, not the next hydrate.

    NO EXECUTION SIDE EFFECTS WITHOUT -Execute: default is a DRY RUN that logs
    what it WOULD reap. Pass -Execute to actually delete.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $P4Port,
    [Parameter(Mandatory)] [string] $P4User,
    # Stream sanitized to [a-z0-9_], same value the build pipeline uses to build
    # client names (Terraform local fsxn_client_stream_safe). Used to recover the
    # backing clone-volume name from a client name and to scope the sweep to this
    # stream's clients.
    [Parameter(Mandatory)] [string] $StreamSafe,
    # ONTAP / FSxN REST access (same shape as the other scripts).
    [Parameter(Mandatory)] [string] $SvmName,
    [Parameter(Mandatory)] [string] $FsxAdminIp,
    [Parameter(Mandatory)] [string] $OntapPasswordSecretName,
    [Parameter(Mandatory)] [string] $AwsRegion,
    # Horde server for the job-liveness gate. Base URL, e.g.
    # https://horde.example.com . If empty or unreachable, GATE 3 cannot be
    # satisfied and NOTHING is deleted (fail-safe).
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $HordeServerUrl,
    [string] $OntapUser  = 'fsxadmin',
    [string] $ClonePrefix = 'build_',   # per-job clone volume name prefix
    # LUN leaf inside each clone volume, i.e. the {LunName} in
    # /vol/<CloneVolumeName>/<LunName>. MUST match the LunName the build pipeline
    # maps (Terraform local.fsxn_lun_name -> globals.json -set:LunName ->
    # BuildPipeline.xml/attach-clone-lun.ps1/teardown-clone-lun.ps1). Threaded in
    # from globals.json so the reaper's PASS-2 unmap and the build pipeline stay
    # in lockstep - a hardcoded leaf here would silently unmap the wrong path if
    # the pipeline's LunName ever changes.
    [string] $LunName = 'workspace',
    [switch] $Execute
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'OntapSan.psm1') -Force

function Write-Reap($m) { Write-Host "[reap-orphans] $m" }

$mode = if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' }
Write-Reap "starting sweep ($mode) - clients ^hordeclone_${StreamSafe}_ , clone volumes ^${ClonePrefix}"

# The name-gate prefix for THIS stream's clients. A client name is
# hordeclone_<StreamSafe>_<CloneVolumeName>; stripping this prefix recovers the
# backing clone volume name for the CLONE-GONE gate.
$clientPrefix = "hordeclone_${StreamSafe}_"

# --------------------------------------------------------------------------
# ONTAP context. If we cannot reach ONTAP we cannot prove GATE 2 for anything,
# so we abort the whole sweep - deleting nothing - rather than guess.
# --------------------------------------------------------------------------
try {
    $ctx = Connect-Ontap -ManagementEndpoint $FsxAdminIp -PasswordSecretName $OntapPasswordSecretName `
                         -AwsRegion $AwsRegion -User $OntapUser -Svm $SvmName
    # Connect-Ontap only reads the secret and builds a context - it does NOT touch
    # the cluster, so a bad/unreachable FsxAdminIp would slip through and let the
    # sweep proceed. Probe with one cheap authenticated REST GET so an unreachable
    # ONTAP aborts HERE (deleting nothing) as the safety contract promises.
    $null = Invoke-Ontap -Ctx $ctx -Path '/cluster?fields=name'
} catch {
    Write-Reap "ONTAP unreachable ($($_.Exception.Message)) - GATE 2 unprovable, deleting NOTHING this run."
    exit 0
}

# --------------------------------------------------------------------------
# GATE 3 helper: is a Horde job still live?
#
# The job id is the {jobid} in the clone volume name build_{jobid}. We ask the
# Horde REST API for that job's state. Fail-safe: if the query cannot give us a
# CONFIDENT "this job is done", we treat the job as LIVE (return $true) so the
# owning objects are KEPT.
#   * 404            -> job truly gone            -> not live  ($false) -> reapable
#   * completed/terminal state -> not live        ($false) -> reapable
#   * any running/pending/waiting state -> live   ($true)   -> keep
#   * network error / non-404 HTTP error / unparseable -> LIVE ($true) -> keep
# --------------------------------------------------------------------------
function Test-HordeJobLive([string] $JobId) {
    if ([string]::IsNullOrWhiteSpace($HordeServerUrl)) { return $true }  # cannot check -> keep
    $base = $HordeServerUrl.TrimEnd('/')
    $uri  = "$base/api/v1/jobs/$JobId"
    try {
        $resp = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    } catch {
        $status = $null
        try { $status = [int]$_.Exception.Response.StatusCode } catch { }
        if ($status -eq 404) {
            # Job record is gone entirely -> definitively not live.
            return $false
        }
        # Anything else (500, timeout, DNS, auth) is uncertainty -> keep.
        Write-Reap "  Horde query for job '$JobId' inconclusive ($([string]$status)$($_.Exception.Message)) - treating as LIVE (keep)"
        return $true
    }

    $state = $null
    try { $state = ($resp.Content | ConvertFrom-Json).state } catch { }
    if ([string]::IsNullOrWhiteSpace($state)) {
        Write-Reap "  Horde job '$JobId' returned no parseable state - treating as LIVE (keep)"
        return $true
    }
    # Horde job states that mean the job is FINISHED. Anything not in this set
    # (running, waiting, ready, ...) is treated as live.
    $terminal = @('complete', 'completed', 'aborted', 'cancelled', 'canceled', 'skipped', 'failed')
    if ($terminal -contains $state.ToLowerInvariant()) { return $false }
    return $true
}

# Recover the job id from a clone volume name (build_{jobid} -> {jobid}).
function Get-JobIdFromClone([string] $CloneName) {
    if ($CloneName.StartsWith($ClonePrefix)) { return $CloneName.Substring($ClonePrefix.Length) }
    return $null
}

$reapedClients = 0
$reapedVolumes = 0

# ==========================================================================
# PASS 1: leaked p4 CLIENTS. Delete a client only if name-gate + clone-gone +
# job-not-live all pass.
# ==========================================================================
$clientList = @()
try {
    # -ztag is REQUIRED for -F to emit rows on p4 2025.1+ (the production windows-horde
    # AMI): plain 'clients -e' returns rows, but '-F "%client%"' WITHOUT -ztag returns
    # ZERO rows with exit 0 (silent no-op). Global flags precede the command.
    $raw = & p4.exe -p $P4Port -u $P4User -ztag -F "%client%" clients -e "hordeclone_${StreamSafe}_*" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $clientList = @($raw | Where-Object { $_ -and ($_ -is [string]) -and $_.Trim() })
    } else {
        Write-Reap "p4 clients query failed (exit $LASTEXITCODE): $($raw | Out-String) - skipping client pass."
        $clientList = @()
    }
} catch {
    Write-Reap "p4 clients query errored: $($_.Exception.Message) - skipping client pass."
    $clientList = @()
}

foreach ($client in $clientList) {
    $name = $client.Trim()

    # GATE 1: name. Defensive - the -e filter already scoped it, but never
    # delete a client whose name we do not fully understand.
    if ($name -notmatch '^hordeclone_') {
        Write-Reap "SKIP '$name' (GATE 1 name-gate: not ^hordeclone_)"
        continue
    }
    if (-not $name.StartsWith($clientPrefix)) {
        Write-Reap "SKIP '$name' (GATE 1: not this stream's prefix '$clientPrefix')"
        continue
    }

    $cloneName = $name.Substring($clientPrefix.Length)   # the build_{jobid} volume
    if ([string]::IsNullOrWhiteSpace($cloneName) -or -not $cloneName.StartsWith($ClonePrefix)) {
        Write-Reap "SKIP '$name' (cannot recover a '$ClonePrefix*' clone name -> keep)"
        continue
    }

    # GATE 2: backing clone volume gone?
    $vol = $null
    try { $vol = Get-OntapVolume -Ctx $ctx -Name $cloneName } catch {
        Write-Reap "SKIP '$name' (GATE 2 lookup errored for '$cloneName' -> keep)"
        continue
    }
    if ($vol) {
        Write-Reap "SKIP '$name' (GATE 2: backing clone '$cloneName' still exists -> keep)"
        continue
    }

    # GATE 3: owning Horde job not live?
    $jobId = Get-JobIdFromClone $cloneName
    if ([string]::IsNullOrWhiteSpace($jobId)) {
        Write-Reap "SKIP '$name' (GATE 3: no job id recoverable -> keep)"
        continue
    }
    if (Test-HordeJobLive $jobId) {
        Write-Reap "SKIP '$name' (GATE 3: Horde job '$jobId' may be live -> keep)"
        continue
    }

    # All three gates passed.
    if ($Execute) {
        try {
            $ErrorActionPreference = 'Continue'
            $out = & p4.exe -p $P4Port -u $P4User client -d $name 2>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            $text = ($out | Out-String)
            if ($code -eq 0 -or $text -match "doesn't exist|does not exist|no such client") {
                Write-Reap "REAPED client '$name' (clone '$cloneName' gone, job '$jobId' dead)"
                $reapedClients++
            } else {
                Write-Reap "FAILED to delete client '$name' (exit $code): $($text.Trim())"
            }
        } catch {
            Write-Reap "FAILED to delete client '$name': $($_.Exception.Message)"
        }
    } else {
        Write-Reap "WOULD REAP client '$name' (clone '$cloneName' gone, job '$jobId' dead)"
        $reapedClients++
    }
}

# ==========================================================================
# PASS 2: leaked clone VOLUMES whose owning job is dead. Same fail-safe gates
# (name + job-not-live; the volume existing IS the reason to consider it). This
# collects the hard-Spot-reclaim leak the on-agent teardown never ran for.
# ==========================================================================
$volList = @()
try {
    $r = Invoke-Ontap -Ctx $ctx -Path "/storage/volumes?name=${ClonePrefix}*&svm.name=$($ctx.Svm)&fields=name,state"
    if ($r.num_records -gt 0) { $volList = @($r.records) }
} catch {
    Write-Reap "clone-volume list query errored: $($_.Exception.Message) - skipping volume pass."
    $volList = @()
}

foreach ($v in $volList) {
    $cloneName = $v.name

    # GATE 1 (name): must be a per-job clone volume.
    if (-not $cloneName.StartsWith($ClonePrefix)) {
        Write-Reap "SKIP volume '$cloneName' (name-gate: not '$ClonePrefix*')"
        continue
    }

    # GATE 3 (job not live): only reap a volume whose job is definitively done.
    $jobId = Get-JobIdFromClone $cloneName
    if ([string]::IsNullOrWhiteSpace($jobId)) {
        Write-Reap "SKIP volume '$cloneName' (no job id recoverable -> keep)"
        continue
    }
    if (Test-HordeJobLive $jobId) {
        Write-Reap "SKIP volume '$cloneName' (Horde job '$jobId' may be live -> keep)"
        continue
    }

    if ($Execute) {
        try {
            # Volume may still be LUN-mapped from an agent that vanished; unmap
            # first (idempotent) so the delete is not refused, then delete.
            try { Remove-OntapLunMap -Ctx $ctx -LunPath "/vol/$cloneName/$LunName" } catch {
                Write-Reap "  unmap of '$cloneName' reported: $($_.Exception.Message) - continuing"
            }
            Remove-OntapVolume -Ctx $ctx -Name $cloneName
            Write-Reap "REAPED clone volume '$cloneName' (job '$jobId' dead)"
            $reapedVolumes++
        } catch {
            Write-Reap "FAILED to delete clone volume '$cloneName': $($_.Exception.Message)"
        }
    } else {
        Write-Reap "WOULD REAP clone volume '$cloneName' (job '$jobId' dead)"
        $reapedVolumes++
    }
}

$verb = if ($Execute) { 'reaped' } else { 'would reap' }
Write-Reap "sweep complete ($mode): $verb $reapedClients client(s), $reapedVolumes clone volume(s)."
exit 0
