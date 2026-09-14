<#
.SYNOPSIS
    Seed a Perforce stream depot with a source-available Unreal Engine project,
    the matching engine tree, and the BuildGraph pipeline scripts, so the Horde
    build pipeline in this sample has something to hydrate, clone, and compile.

.DESCRIPTION
    Run this on the in-VPC Windows workstation (private subnet, reachable via
    SSM / Fleet Manager, no public ingress) that has `p4` and `aws` installed.
    It is the automation for runbook step 4 ("Seed the Perforce depot"). Instead
    of hand-writing P4 commands, run this script once.

    What it does, idempotently where possible:
      1. p4 trust -y            (accept the SSL fingerprint)
      2. p4 login               (using -P4Password or -P4PasswordSecret)
      3. Create the stream depot + mainline stream if absent
      4. Create a stream client rooted at a local workspace dir
      5. Place/reconcile the PROJECT under //Stream/<ProjectName>/
         (NEVER at the stream root -- see the drive-root caveat below)
      6. Submit the Build scripts under //Stream/Build/
      7. Provision the Engine, either by branching an engine already in the depot
         (-EngineDepotPath, via `p4 populate` -- lazy copy, NO ~34 GiB re-upload,
         strongly preferred) OR by reconciling+submitting a local tree (-EnginePath)
      8. Verify: p4 changes -m 3, and confirm //Stream/{<ProjectName>,Build,Engine}
         and <Project>.uproject exist under the subfolder

.NOTES
    CRITICAL LAYOUT / CONTENT REQUIREMENTS (do not skip -- these are hard-won):

    * USE A SOURCE-AVAILABLE PROJECT. The .uproject MUST have a `Source/` folder
      and real `Modules[]` (e.g. Epic's Lyra). A content-only Launcher/Fab sample
      (e.g. Stack-O-Bot) ships prebuilt DLLs with NO Source/ and CANNOT be compiled
      from source -- the build fails because there is nothing to compile.

    * THE PROJECT MUST LIVE IN A SUBFOLDER, never at the stream root. A UE project
      at a clone-LUN drive root (W:\Project.uproject) crashes UnrealBuildTool with a
      NullReferenceException in SourceFileWorkingSet (ProjectDir.ParentDirectory is
      null at a drive root). The depot layout below places it under
      //Stream/<ProjectName>/ precisely so ProjectDir has a non-null parent.

    * THE ENGINE MUST BE PRESENT. The Compile node resolves
      <drive>:\Engine\Build\BatchFiles\Build.bat off the clone, so the full UE
      engine source tree must be in the stream under //Stream/Engine/. A
      from-source editor compile needs the full engine source, not an installed build.

    * NO HARDCODED SECRETS. Pass the password via -P4Password (interactive/CI var)
      or -P4PasswordSecret (read from AWS Secrets Manager via aws-cli at runtime).

    Resulting depot layout:

        //Stream/main/
        |-- <ProjectName>/          # <Project>.uproject, Source/, Config/, Content/
        |-- Build/                  # the buildgraph scripts
        \-- Engine/                 # the full UE engine tree

.PARAMETER P4Port
    P4PORT of the target server, e.g. ssl:perforce.studio.internal:1666

.PARAMETER P4User
    Perforce user to authenticate as (a super/admin user able to create depots).

.PARAMETER P4Password
    Password for -P4User. Mutually exclusive with -P4PasswordSecret.

.PARAMETER P4PasswordSecret
    AWS Secrets Manager secret id/ARN to read the password from at runtime via
    aws-cli. If the secret is JSON shaped {"username":..,"password":..}, the
    password field is extracted; otherwise the raw SecretString is used.
    Mutually exclusive with -P4Password.

.PARAMETER Stream
    The target stream, e.g. //YourGame/main. The depot name and stream name are
    derived from this.

.PARAMETER ProjectName
    Subfolder name under the stream for the project, e.g. Lyra. The project is
    placed at //<depot>/<streamleaf>/<ProjectName>/ -- NEVER at the stream root.

.PARAMETER ProjectSourcePath
    Local path to the project tree containing <Project>.uproject plus Source/,
    Config/, Content/.

.PARAMETER EnginePath
    Local path to an engine tree to reconcile+submit. Use ONLY if the engine is
    not already in the depot. Mutually exclusive with -EngineDepotPath.

.PARAMETER EngineDepotPath
    Depot path of an engine tree already in the depot to branch via `p4 populate`
    (lazy copy, no re-upload of ~34 GiB). STRONGLY PREFERRED over -EnginePath.
    e.g. //UnrealEngine/5.5/Engine/...

.PARAMETER BuildScriptsPath
    Local path to the buildgraph/ scripts (HydratePipeline.xml, BuildPipeline.xml,
    OntapSan.psm1, create-build-client.ps1, hydrate-source-lun.ps1,
    teardown-clone-lun.ps1, attach-clone-lun.ps1).

.PARAMETER WorkspaceRoot
    Local directory to root the temporary stream client at. Defaults to
    C:\p4\<clientname>.

.PARAMETER ClientName
    Name of the temporary stream client to create. Defaults to seed_<user>_<host>.

.PARAMETER SubmitBatchSize
    Only used by the local-engine (-EnginePath) path. Number of files to `p4 add`
    and `p4 submit` per changelist. The engine tree is ~285k files / ~64 GiB; a
    single monolithic reconcile+submit stalls, so the local-engine tree is added
    and submitted in fixed-size chunks (one changelist per chunk). Files whose
    names contain P4 wildcard metacharacters (@ % # *) are handled separately
    (added with `p4 add -f`, escaped); any that still fail to add/submit are
    WARNed, skipped, and reported in an end-of-run summary rather than stalling
    the whole seed. Defaults to 15000. The -EngineDepotPath (p4 populate) path is
    unaffected.

.EXAMPLE
    # Preferred: branch an engine already in the depot (no re-upload)
    .\seed-depot.ps1 -P4Port ssl:perforce.studio.internal:1666 -P4User admin `
        -P4PasswordSecret arn:aws:secretsmanager:...:secret:p4-admin `
        -Stream //YourGame/main -ProjectName Lyra `
        -ProjectSourcePath C:\src\Lyra `
        -EngineDepotPath //UnrealEngine/5.5/Engine `
        -BuildScriptsPath C:\src\cgd\buildgraph

.EXAMPLE
    # Dry run
    .\seed-depot.ps1 -P4Port ssl:... -P4User admin -P4Password 'xxx' `
        -Stream //YourGame/main -ProjectName Lyra `
        -ProjectSourcePath C:\src\Lyra -EnginePath C:\UE\5.5 `
        -BuildScriptsPath C:\src\cgd\buildgraph -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)] [string] $P4Port,
    [Parameter(Mandatory = $true)] [string] $P4User,

    [Parameter()] [string] $P4Password,
    [Parameter()] [string] $P4PasswordSecret,

    [Parameter(Mandatory = $true)] [string] $Stream,
    [Parameter(Mandatory = $true)] [string] $ProjectName,
    [Parameter(Mandatory = $true)] [string] $ProjectSourcePath,

    [Parameter()] [string] $EnginePath,
    [Parameter()] [string] $EngineDepotPath,

    [Parameter(Mandatory = $true)] [string] $BuildScriptsPath,

    [Parameter()] [string] $WorkspaceRoot,
    [Parameter()] [string] $ClientName,

    [Parameter()] [ValidateRange(1, [int]::MaxValue)] [int] $SubmitBatchSize = 15000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string] $Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-P4 {
    <#
        Run a p4 command with the resolved -p/-u/-c flags. Echoes the command.
        Honors -WhatIf for mutating operations via $ShouldProcess (passed by caller).
    #>
    param(
        [Parameter(Mandatory = $true)] [string[]] $P4Args,
        [Parameter()] [string] $StdIn
    )
    $baseArgs = @('-p', $P4Port, '-u', $P4User)
    if ($script:ClientNameResolved) { $baseArgs += @('-c', $script:ClientNameResolved) }
    $fullArgs = $baseArgs + $P4Args
    Write-Host "    p4 $($fullArgs -join ' ')" -ForegroundColor DarkGray
    if ($StdIn) {
        $StdIn | & p4 @fullArgs
    }
    else {
        & p4 @fullArgs
    }
    if ($LASTEXITCODE -ne 0) {
        throw "p4 $($P4Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

# ---------------------------------------------------------------------------
# 0. Validate parameters / preconditions
# ---------------------------------------------------------------------------
Write-Step "Validating parameters and preconditions"

if ($P4Password -and $P4PasswordSecret) {
    throw "Specify only one of -P4Password or -P4PasswordSecret, not both."
}
if (-not $P4Password -and -not $P4PasswordSecret) {
    throw "Provide the password via -P4Password or -P4PasswordSecret."
}
if ($EnginePath -and $EngineDepotPath) {
    throw "Specify only one of -EnginePath or -EngineDepotPath, not both."
}
if (-not $EnginePath -and -not $EngineDepotPath) {
    throw "Provide the engine via -EngineDepotPath (preferred, no re-upload) or -EnginePath."
}

# Stream must be //<depot>/<leaf>
if ($Stream -notmatch '^//([^/]+)/([^/]+)$') {
    throw "-Stream must look like //<depot>/<name>, e.g. //YourGame/main. Got: $Stream"
}
$DepotName  = $Matches[1]
$StreamLeaf = $Matches[2]

# Resolve the project's .uproject and enforce source-available layout.
if (-not (Test-Path -LiteralPath $ProjectSourcePath)) {
    throw "-ProjectSourcePath not found: $ProjectSourcePath"
}
$uproject = Get-ChildItem -LiteralPath $ProjectSourcePath -Filter '*.uproject' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $uproject) {
    throw "No .uproject found under $ProjectSourcePath -- point -ProjectSourcePath at the project tree root."
}
$sourceDir = Join-Path $ProjectSourcePath 'Source'
if (-not (Test-Path -LiteralPath $sourceDir)) {
    throw ("Project '$($uproject.Name)' has no Source/ folder. Use a SOURCE-AVAILABLE project " +
           "(Lyra, etc.), NOT a content-only Launcher/Fab sample -- there would be nothing to compile.")
}

if (-not (Test-Path -LiteralPath $BuildScriptsPath)) {
    throw "-BuildScriptsPath not found: $BuildScriptsPath"
}
if ($EnginePath -and -not (Test-Path -LiteralPath $EnginePath)) {
    throw "-EnginePath not found: $EnginePath"
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Join-Path 'C:\p4' $StreamLeaf
}
if (-not $ClientName) {
    $safeHost = ($env:COMPUTERNAME -replace '[^A-Za-z0-9_]', '_')
    $safeUser = ($P4User -replace '[^A-Za-z0-9_]', '_')
    $ClientName = "seed_${safeUser}_${safeHost}"
}
# Not yet passed to Invoke-P4 (depot/stream creation happen client-less first).
$script:ClientNameResolved = $null

Write-Host "    Depot        : $DepotName"
Write-Host "    Stream       : $Stream"
Write-Host "    Project      : $($uproject.Name) (source-available: OK)"
Write-Host "    Project path : //$DepotName/$StreamLeaf/$ProjectName/  (subfolder -- NOT stream root)"
Write-Host "    Engine       : $(if ($EngineDepotPath) { "branch from $EngineDepotPath (p4 populate)" } else { "submit local $EnginePath" })"
Write-Host "    Client       : $ClientName -> $WorkspaceRoot"

# ---------------------------------------------------------------------------
# 1. p4 trust -y
# ---------------------------------------------------------------------------
Write-Step "Trusting the server SSL fingerprint (p4 trust -y)"
if ($PSCmdlet.ShouldProcess($P4Port, "p4 trust -y")) {
    & p4 -p $P4Port trust -y
    if ($LASTEXITCODE -ne 0) { throw "p4 trust failed with exit code $LASTEXITCODE" }
}

# ---------------------------------------------------------------------------
# 2. p4 login
# ---------------------------------------------------------------------------
Write-Step "Resolving password and logging in (p4 login)"
$password = $P4Password
if ($P4PasswordSecret) {
    Write-Host "    Reading password from Secrets Manager: $P4PasswordSecret"
    $secretRaw = & aws secretsmanager get-secret-value --secret-id $P4PasswordSecret --query SecretString --output text
    if ($LASTEXITCODE -ne 0 -or -not $secretRaw) {
        throw "Failed to read secret '$P4PasswordSecret' from Secrets Manager."
    }
    # Accept either a JSON {"username":..,"password":..} secret or a raw string.
    try {
        $parsed = $secretRaw | ConvertFrom-Json -ErrorAction Stop
        if ($parsed.PSObject.Properties.Name -contains 'password') {
            $password = $parsed.password
        }
        else {
            $password = $secretRaw
        }
    }
    catch {
        $password = $secretRaw
    }
}
if ($PSCmdlet.ShouldProcess($P4Port, "p4 login as $P4User")) {
    $password | & p4 -p $P4Port -u $P4User login
    if ($LASTEXITCODE -ne 0) { throw "p4 login failed with exit code $LASTEXITCODE" }
}

# ---------------------------------------------------------------------------
# 3. Create the stream depot + mainline stream if absent
# ---------------------------------------------------------------------------
Write-Step "Ensuring stream depot '$DepotName' exists (p4 depot -t stream)"
# On a clean first run `p4 depots` can write a benign message to stderr; under
# $ErrorActionPreference='Stop' that native stderr is promoted to a TERMINATING
# NativeCommandError (killing the script before we create the depot) despite the
# 2>$null. Locally lower ErrorActionPreference and reset LASTEXITCODE so a
# not-yet-existing depot is treated as "absent", not as a fatal error.
$existingDepots = $null
$__eaps = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
try { $existingDepots = & p4 -p $P4Port -u $P4User depots 2>$null } catch { $existingDepots = $null }
$global:LASTEXITCODE = 0; $ErrorActionPreference = $__eaps
$depotExists = $false
if ($existingDepots) {
    $depotExists = ($existingDepots | Where-Object { $_ -match "^Depot\s+$([regex]::Escape($DepotName))\s" }) -ne $null
}
if ($depotExists) {
    Write-Host "    Depot '$DepotName' already exists -- skipping."
}
elseif ($PSCmdlet.ShouldProcess($DepotName, "create stream depot")) {
    $depotSpec = & p4 -p $P4Port -u $P4User depot -t stream -o $DepotName
    ($depotSpec -replace '^Type:.*', "Type:`tstream") | & p4 -p $P4Port -u $P4User depot -i
    if ($LASTEXITCODE -ne 0) { throw "Failed to create depot '$DepotName'." }
}

Write-Step "Ensuring mainline stream '$Stream' exists (p4 stream -t mainline)"
$streamExists = $false
# On a clean first run `p4 streams //<depot>/*` writes a benign 'no such
# stream'/'must refer to...' message to stderr; under $ErrorActionPreference='Stop'
# that native stderr is promoted to a TERMINATING NativeCommandError (killing the
# script before we create the stream) despite the 2>$null. Locally lower
# ErrorActionPreference and reset LASTEXITCODE so a not-yet-existing stream is
# treated as "absent", not as a fatal error.
$existingStreams = $null
$__eaps = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
try { $existingStreams = & p4 -p $P4Port -u $P4User streams "//$DepotName/*" 2>$null } catch { $existingStreams = $null }
$global:LASTEXITCODE = 0; $ErrorActionPreference = $__eaps
if ($existingStreams) {
    $streamExists = ($existingStreams | Where-Object { $_ -match "^Stream\s+$([regex]::Escape($Stream))\s" }) -ne $null
}
if ($streamExists) {
    Write-Host "    Stream '$Stream' already exists -- skipping."
}
elseif ($PSCmdlet.ShouldProcess($Stream, "create mainline stream")) {
    $streamSpec = & p4 -p $P4Port -u $P4User stream -t mainline -o $Stream
    $streamSpec | & p4 -p $P4Port -u $P4User stream -i
    if ($LASTEXITCODE -ne 0) { throw "Failed to create stream '$Stream'." }
}

# ---------------------------------------------------------------------------
# 4. Create a stream client rooted at the workspace dir
# ---------------------------------------------------------------------------
Write-Step "Creating stream client '$ClientName' rooted at '$WorkspaceRoot'"
if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
    if ($PSCmdlet.ShouldProcess($WorkspaceRoot, "create workspace directory")) {
        New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null
    }
}
if ($PSCmdlet.ShouldProcess($ClientName, "create/update stream client")) {
    $clientSpec = & p4 -p $P4Port -u $P4User client -o $ClientName
    $clientSpec = $clientSpec `
        -replace '^Root:.*', "Root:`t$WorkspaceRoot" `
        -replace '^Stream:.*', "Stream:`t$Stream"
    # `p4 client -o` for a new client has no Stream: line -- append one if missing.
    if ($clientSpec -notmatch '(?m)^Stream:') {
        $clientSpec += "`nStream:`t$Stream`n"
    }
    $clientSpec | & p4 -p $P4Port -u $P4User client -i
    if ($LASTEXITCODE -ne 0) { throw "Failed to create client '$ClientName'." }
}
# From here on, p4 commands use this client.
$script:ClientNameResolved = $ClientName

# Collects files skipped during the chunked local-engine submit (metachar or
# per-chunk failures) so we can report them once at the end instead of dying.
$script:SkippedFiles = New-Object System.Collections.Generic.List[string]

# Helper to add + submit a set of local files placed under the workspace.
function Submit-Tree {
    param(
        [Parameter(Mandatory = $true)] [string] $SourcePath,
        [Parameter(Mandatory = $true)] [string] $DepotSubfolder,   # relative to stream root, e.g. "Lyra" or "Build"
        [Parameter(Mandatory = $true)] [string] $Description
    )
    $dest = Join-Path $WorkspaceRoot $DepotSubfolder
    Write-Host "    Staging '$SourcePath' -> '$dest'"
    if ($PSCmdlet.ShouldProcess($dest, "copy tree into workspace")) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item -Path (Join-Path $SourcePath '*') -Destination $dest -Recurse -Force
    }
    if ($PSCmdlet.ShouldProcess("//$DepotName/$StreamLeaf/$DepotSubfolder/...", "p4 reconcile + submit")) {
        # reconcile picks up adds/edits/deletes idempotently across re-runs
        & p4 -p $P4Port -u $P4User -c $ClientName reconcile "$dest\..." 2>$null
        Invoke-P4 -P4Args @('submit', '-d', $Description, "$dest\...")
    }
}

# Add + submit a LARGE local tree in fixed-size chunks (one changelist per chunk).
# Used for the local-engine (-EnginePath) path only. A single monolithic
# reconcile+submit of the ~285k-file / ~64 GiB engine tree stalls; chunking keeps
# each submit bounded and emits per-chunk progress. Files whose names contain P4
# wildcard metacharacters (@ % # *) are added separately with `p4 add -f` (escaped);
# any file that still fails to add/submit is WARNed, skipped, and reported at the
# end instead of aborting the whole seed. Returns the list of skipped file paths.
function Submit-TreeChunked {
    param(
        [Parameter(Mandatory = $true)] [string] $SourcePath,
        [Parameter(Mandatory = $true)] [string] $DepotSubfolder,   # relative to stream root, e.g. "Engine"
        [Parameter(Mandatory = $true)] [string] $Description,
        [Parameter(Mandatory = $true)] [int]    $BatchSize
    )
    $dest = Join-Path $WorkspaceRoot $DepotSubfolder
    Write-Host "    Staging '$SourcePath' -> '$dest'"
    if ($PSCmdlet.ShouldProcess($dest, "copy tree into workspace")) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item -Path (Join-Path $SourcePath '*') -Destination $dest -Recurse -Force
    }

    # Enumerate the local files to submit. In -WhatIf the tree may not have been
    # copied, so fall back to enumerating the SOURCE tree just to size the plan.
    $enumRoot = if (Test-Path -LiteralPath $dest) { $dest } else { $SourcePath }
    $allFiles = @(Get-ChildItem -LiteralPath $enumRoot -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $totalFiles = $allFiles.Count

    # Split into normal vs metachar (@ % # *) buckets. Metachar files break plain
    # `p4 add` because P4 interprets those characters in path args, so they are
    # added individually with `p4 add -f`.
    $metaFiles   = @($allFiles | Where-Object { $_ -match '[@%#*]' })
    $normalFiles = @($allFiles | Where-Object { $_ -notmatch '[@%#*]' })

    $chunks = [math]::Ceiling($normalFiles.Count / [double]$BatchSize)
    if ($chunks -lt 1 -and $normalFiles.Count -gt 0) { $chunks = 1 }

    Write-Host "    Files to submit : $totalFiles  (normal: $($normalFiles.Count), metachar @%#*: $($metaFiles.Count))"
    Write-Host "    Batch size      : $BatchSize  ->  $chunks chunk(s) for normal files"

    $skipped = New-Object System.Collections.Generic.List[string]
    $done = 0

    # --- Normal files: add + submit in fixed-size chunks ------------------------
    # p4 emits benign per-file warnings ("can't add existing file", etc.) and
    # returns a NON-ZERO exit for the whole `p4 add` when ANY single file warns,
    # even though the rest opened fine. So we do NOT gate on the `p4 add` exit
    # code. Instead we ask the server what is actually OPEN for this chunk and
    # submit exactly that (the default changelist, scoped to the engine dest path).
    # A file that never opens is recorded as skipped rather than aborting the chunk.
    # The batch is fed to `p4 add` through a temp arg file (-x <file>) to avoid
    # command-line length limits.
    for ($i = 0; $i -lt $normalFiles.Count; $i += $BatchSize) {
        $chunkIndex = [int]($i / $BatchSize) + 1
        $batch = @($normalFiles[$i..([math]::Min($i + $BatchSize - 1, $normalFiles.Count - 1))])
        $done += $batch.Count
        Write-Host ("    [chunk {0}/{1}] adding {2} files ({3}/{4} done)" -f $chunkIndex, $chunks, $batch.Count, $done, $totalFiles) -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("chunk $chunkIndex/$chunks -> //$DepotName/$StreamLeaf/$DepotSubfolder/...", "p4 add + submit ($($batch.Count) files)")) {
            $argFile = $null
            # p4 writes benign notices ("file(s) not opened on this client", per-file
            # add warnings, etc.) to STDERR with a non-zero exit. Under
            # $ErrorActionPreference='Stop' + StrictMode those native stderr lines are
            # promoted to a TERMINATING NativeCommandError that would abort the whole
            # seed after the first chunk (despite 2>$null). Lower ErrorActionPreference
            # for the duration of the chunk and restore it in the finally block -- the
            # same defensive pattern used for `p4 depots`/`p4 streams` above.
            $__chunkEap = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
            try {
                # Write the batch to a temp arg file and feed it to `p4 -x <file> add`
                # so we avoid both command-line length limits and stdin quoting.
                # NOTE: the file MUST be written WITHOUT a BOM -- a leading UTF-8 BOM
                # gets prepended to the first path and p4 then treats it as a bad
                # relative path ("... is not under client's root"). Set-Content -Encoding
                # UTF8 emits a BOM on Windows PowerShell 5.1, so write bytes directly.
                $argFile = [System.IO.Path]::GetTempFileName()
                [System.IO.File]::WriteAllLines($argFile, [string[]]$batch, (New-Object System.Text.UTF8Encoding($false)))

                # Open the batch for add. Ignore the `p4 add` exit code on purpose:
                # p4 returns non-zero for the whole invocation when ANY single file
                # emits a benign warning ("can't add existing file", etc.) even though
                # the rest opened fine. We reconcile truth from `p4 opened` below.
                & p4 -p $P4Port -u $P4User -c $ClientName -x $argFile add 2>&1 | Out-Null
                $global:LASTEXITCODE = 0

                # Submit whatever this chunk opened as one changelist, scoped to the
                # engine dest path (this is the default changelist -- each chunk is
                # added then immediately submitted, so only this chunk's files are
                # pending). If nothing opened (e.g. a re-run over already-seeded
                # files), skip the submit -- treat it as a no-op rather than a failure.
                $openedNow = @(& p4 -p $P4Port -u $P4User -c $ClientName opened "$dest\..." 2>$null | Where-Object { $_ -match '#\d+ - ' })
                $global:LASTEXITCODE = 0
                if ($openedNow.Count -eq 0) {
                    Write-Host "        (nothing new to submit in this chunk)" -ForegroundColor DarkGray
                    continue
                }
                & p4 -p $P4Port -u $P4User -c $ClientName submit -d "$Description (chunk $chunkIndex/$chunks)" "$dest\..." 2>&1 |
                    Where-Object { $_ -match 'Submitting change|submitted\.' } | ForEach-Object { Write-Host "        $_" }
                if ($LASTEXITCODE -ne 0) { throw "p4 submit returned exit code $LASTEXITCODE for chunk $chunkIndex" }

                # Any batch file that is STILL open (never submitted) is skipped.
                $stillOpen = @(& p4 -p $P4Port -u $P4User -c $ClientName opened "$dest\..." 2>$null | Where-Object { $_ -match '#\d+ - ' })
                $global:LASTEXITCODE = 0
                if ($stillOpen.Count -gt 0) {
                    Write-Warning "chunk $chunkIndex/$chunks left $($stillOpen.Count) file(s) unsubmitted -- skipping them."
                    foreach ($f in $stillOpen) { $skipped.Add($f) }
                    & p4 -p $P4Port -u $P4User -c $ClientName revert "$dest\..." 2>$null
                    $global:LASTEXITCODE = 0
                }
            }
            catch {
                # Don't abort the whole seed on one bad chunk -- warn, record the
                # files, and continue. (A subsequent re-run reconciles the rest.)
                Write-Warning "chunk $chunkIndex/$chunks failed: $($_.Exception.Message). Skipping these $($batch.Count) file(s)."
                foreach ($f in $batch) { $skipped.Add($f) }
                # Revert whatever opened in this failed chunk so the next chunk is clean.
                & p4 -p $P4Port -u $P4User -c $ClientName revert "$dest\..." 2>$null
                $global:LASTEXITCODE = 0
            }
            finally {
                $ErrorActionPreference = $__chunkEap
                if ($argFile -and (Test-Path -LiteralPath $argFile)) { Remove-Item -LiteralPath $argFile -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    # --- Metachar files: add -f (escaped), one at a time ------------------------
    if ($metaFiles.Count -gt 0) {
        Write-Host "    [metachar] handling $($metaFiles.Count) file(s) with names containing @ % # * (p4 add -f)" -ForegroundColor Cyan
        $mDone = 0
        foreach ($mf in $metaFiles) {
            $mDone++
            Write-Host ("    [metachar {0}/{1}] {2}" -f $mDone, $metaFiles.Count, $mf) -ForegroundColor DarkCyan
            if ($PSCmdlet.ShouldProcess($mf, "p4 add -f + submit (metachar)")) {
                # Same native-stderr guard as the chunk path (see comment above).
                $__metaEap = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
                try {
                    # -f forces literal handling of wildcards in the filename so @%#*
                    # are stored escaped (%40 %25 %23 %2A) rather than interpreted.
                    # As with the chunk path, `p4 add -f` can return non-zero on a
                    # benign warning, so we confirm via `p4 opened` rather than the
                    # exit code before submitting. The metachar pass runs AFTER all
                    # chunks, so the default changelist is otherwise empty and holds
                    # only this file. (We can't path-filter `p4 opened <path>` here
                    # because the @/#/% in the local path would be parsed as revision
                    # specifiers, so we inspect the whole default changelist.)
                    & p4 -p $P4Port -u $P4User -c $ClientName revert "$dest\..." 2>$null
                    $global:LASTEXITCODE = 0
                    & p4 -p $P4Port -u $P4User -c $ClientName add -f $mf 2>&1 | ForEach-Object { Write-Host "        $_" }
                    $global:LASTEXITCODE = 0
                    $opened = @(& p4 -p $P4Port -u $P4User -c $ClientName opened -c default 2>$null | Where-Object { $_ -match '#\d+ - ' })
                    $global:LASTEXITCODE = 0
                    if ($opened.Count -eq 0) {
                        throw "file did not open for add (p4 add -f produced no pending file)"
                    }
                    & p4 -p $P4Port -u $P4User -c $ClientName submit -d "$Description (metachar)" 2>&1 | ForEach-Object { Write-Host "        $_" }
                    if ($LASTEXITCODE -ne 0) { throw "p4 submit returned exit code $LASTEXITCODE" }
                }
                catch {
                    Write-Warning "metachar file failed, skipping: $mf -- $($_.Exception.Message)"
                    $skipped.Add($mf)
                    & p4 -p $P4Port -u $P4User -c $ClientName revert "$dest\..." 2>$null
                    $global:LASTEXITCODE = 0
                }
                finally {
                    $ErrorActionPreference = $__metaEap
                }
            }
        }
    }

    return $skipped
}

# ---------------------------------------------------------------------------
# 5. Place/reconcile the PROJECT under //Stream/<ProjectName>/  (NEVER stream root)
# ---------------------------------------------------------------------------
# The project MUST live in a subfolder. A UE project at the clone-LUN drive root
# crashes UnrealBuildTool with a NullReferenceException in SourceFileWorkingSet
# (ProjectDir.ParentDirectory is null at a drive root). Placing it under
# //Stream/<ProjectName>/ guarantees ProjectDir has a non-null parent.
Write-Step "Submitting the project under //$DepotName/$StreamLeaf/$ProjectName/ (subfolder, NOT stream root)"
Submit-Tree -SourcePath $ProjectSourcePath -DepotSubfolder $ProjectName -Description "Seed project $ProjectName"

# ---------------------------------------------------------------------------
# 6. Submit the Build scripts under //Stream/Build/
# ---------------------------------------------------------------------------
Write-Step "Submitting the BuildGraph scripts under //$DepotName/$StreamLeaf/Build/"
Submit-Tree -SourcePath $BuildScriptsPath -DepotSubfolder 'Build' -Description "Seed BuildGraph scripts"

# ---------------------------------------------------------------------------
# 7. Provision the Engine
# ---------------------------------------------------------------------------
if ($EngineDepotPath) {
    # Preferred: lazy branch of an engine already in the depot -- no ~34 GiB re-upload.
    $engineDest = "//$DepotName/$StreamLeaf/Engine/..."
    $engineSrc  = $EngineDepotPath.TrimEnd('/').TrimEnd('.')  # normalize
    if ($engineSrc -notmatch '\.\.\.$') { $engineSrc = "$($engineSrc.TrimEnd('/'))/..." }
    Write-Step "Branching engine from $engineSrc -> $engineDest (p4 populate, lazy copy, no re-upload)"
    if ($PSCmdlet.ShouldProcess($engineDest, "p4 populate from $engineSrc")) {
        Invoke-P4 -P4Args @('populate', '-d', "Branch engine into $StreamLeaf", $engineSrc, $engineDest)
    }
}
else {
    Write-Step "Submitting local engine tree under //$DepotName/$StreamLeaf/Engine/ in chunks of $SubmitBatchSize (large/slow)"
    Write-Host "    NOTE: prefer -EngineDepotPath to branch an existing engine and avoid re-uploading ~34 GiB." -ForegroundColor Yellow
    $script:SkippedFiles = Submit-TreeChunked -SourcePath $EnginePath -DepotSubfolder 'Engine' -Description "Seed UE engine tree" -BatchSize $SubmitBatchSize
}

# ---------------------------------------------------------------------------
# 8. Verify
# ---------------------------------------------------------------------------
Write-Step "Verifying the seeded depot"
Write-Host "    Recent changes:"
& p4 -p $P4Port -u $P4User -c $ClientName changes -m 3 "$Stream/..."

$checks = @{
    "$Stream/$ProjectName/..."                 = "project subfolder"
    "$Stream/Build/..."                        = "Build scripts"
    "$Stream/Engine/..."                       = "engine tree"
    "$Stream/$ProjectName/$($uproject.Name)"   = "<Project>.uproject under the subfolder"
}
$allOk = $true
foreach ($path in $checks.Keys) {
    $hit = & p4 -p $P4Port -u $P4User -c $ClientName files -e $path 2>$null
    if ($hit) {
        Write-Host "    [OK]   $($checks[$path]) : $path" -ForegroundColor Green
    }
    else {
        Write-Host "    [MISS] $($checks[$path]) : $path" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host ""
if ($script:SkippedFiles -and $script:SkippedFiles.Count -gt 0) {
    Write-Host "==> Skipped files summary ($($script:SkippedFiles.Count) file(s) not submitted)" -ForegroundColor Yellow
    foreach ($sf in $script:SkippedFiles) {
        Write-Host "    [SKIP] $sf" -ForegroundColor Yellow
    }
    Write-Host "    Review the [SKIP] lines above. Re-running the seed will reconcile any missed files." -ForegroundColor Yellow
}

Write-Host ""
if ($allOk) {
    Write-Host "Depot seeded successfully. You can now trigger the Hydration Pipeline (runbook step 8)." -ForegroundColor Green
}
elseif ($WhatIfPreference) {
    Write-Host "WhatIf run complete -- no changes were made. Verification MISS lines are expected in -WhatIf." -ForegroundColor Yellow
}
else {
    throw "Verification found missing depot paths -- review the [MISS] lines above."
}
