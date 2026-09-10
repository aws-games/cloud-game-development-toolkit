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
    [Parameter()] [string] $ClientName
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
    Write-Step "Submitting local engine tree under //$DepotName/$StreamLeaf/Engine/ (large/slow)"
    Write-Host "    NOTE: prefer -EngineDepotPath to branch an existing engine and avoid re-uploading ~34 GiB." -ForegroundColor Yellow
    Submit-Tree -SourcePath $EnginePath -DepotSubfolder 'Engine' -Description "Seed UE engine tree"
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
if ($allOk) {
    Write-Host "Depot seeded successfully. You can now trigger the Hydration Pipeline (runbook step 8)." -ForegroundColor Green
}
elseif ($WhatIfPreference) {
    Write-Host "WhatIf run complete -- no changes were made. Verification MISS lines are expected in -WhatIf." -ForegroundColor Yellow
}
else {
    throw "Verification found missing depot paths -- review the [MISS] lines above."
}
