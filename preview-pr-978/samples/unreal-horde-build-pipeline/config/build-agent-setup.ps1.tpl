<#
=============================================================================
 Build Agent (Windows Server 2022) — Horde Agent EXTENSION script  (JT-15)
=============================================================================

 Runs via the AWS-managed SSM document `AWS-RunPowerShellScript`, invoked by
 `aws_ssm_association.configure_build_agent` in the sample's iam.tf. iam.tf
 renders this TEMPLATE (templatefile) into the `commands` parameter at apply
 time, injecting the four NON-secret runtime values below. This mirrors the
 Linux sync-agent association, which receives the same values via the Ansible
 ExtraVariables. The script therefore does NOT scrape EC2 tags or IMDS.

 THIS SCRIPT IS ADDITIVE. The base module's Windows user_data
 (modules/unreal/horde/config/agent/agent-config.ps1) has ALREADY, at first
 boot: installed dotnet, downloaded/installed/registered the Horde agent
 (SetServer + service install), installed p4.exe via choco (when p4_port set),
 enabled NTFS long paths, opened UBA firewall ports, and written the UBT
 BuildConfiguration.xml. We DO NOT re-download the agent or re-run SetServer.

 This script ONLY ADDS what the build agent needs for the FSxN workspace:
   * the Windows NFS Client feature (Client for NFS)
   * p4.exe (Helix P4 CLI) and AWS CLI — idempotent, only if missing
   * .NET 8 SDK (UE 5.5 UAT) — idempotent, only if an 8.x SDK is missing
   * an NFSv3 mount of the FSxN source volume to drive letter W:
   * machine-level P4PORT / P4USER env vars (NON-secret values only)

 ADR notes:
   * ADR-001: Build Agents run Windows Server 2022.
   * ADR-002: NFS ONLY (never SMB/CIFS/AD). Windows NFS Client is NFSv3. This
              script does NOT bootstrap-mount the source volume (R2): each build
              job creates and mounts its OWN per-job FlexClone at drive V: inside
              BuildPipeline.xml (mount.exe -o ... \\<svm-nfs-endpoint>\<clone>).
              The NFS-Client feature is installed here so that per-job mount
              works. Drive V: for the clone avoids colliding with anything the
              base image maps; the build reads engine/Lyra from the CLONE (V:),
              never the source.
   * ADR (R1): the P4 server is SSL — this script establishes machine-wide P4
              SSL trust (p4 trust -y, idempotent) so the build job's incremental
              `p4 sync` does not fail with an SSL trust error (Windows analog of
              the Linux sync-agent trust fix).
   * Security: the mount is unauthenticated at the network layer but locked
              down by the FSxN SG + /32 rules already in security.tf. This
              script opens nothing.

 SECRETS: none embedded. P4PORT and P4USER are NON-secret connection values.
 The P4 PASSWORD is NEVER handled here — it is fetched at build time from
 Secrets Manager by the BuildGraph task.

 TEMPLATE NOTE: this file is a Terraform templatefile template. The only
 template interpolations are $${...}-free ${fsxn_nfs_endpoint},
 ${p4_workspace_junction}, ${p4_port}, and ${p4_user}. All PowerShell variables
 use $var / $($var) form so they are NOT interpreted by Terraform.

 Idempotent: safe to re-run. Logs clearly. Exits non-zero on real failure.
=============================================================================
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- Runtime configuration (NON-secret) --------------------------------------
# These values are injected by Terraform at apply time (templatefile) from the
# sample's iam.tf, mirroring the Linux sync-agent SSM association. Empty values
# cause the related step to be skipped with a warning (keeps re-runs safe).
#
#   FsxnNfsEndpoint      e.g. svm-xxxx.fs-xxxx.fsx.<region>.amazonaws.com
#   P4WorkspaceJunction  e.g. /p4-workspace
#   P4Port               e.g. ssl:10.0.10.20:1666   (NON-secret)
#   P4User               e.g. svc-horde             (NON-secret)
$FsxnNfsEndpoint      = '${fsxn_nfs_endpoint}'
$P4WorkspaceJunction  = '${p4_workspace_junction}'
$P4Port               = '${p4_port}'
$P4User               = '${p4_user}'

# Horde server URL the agent enrolls against (public HTTPS FQDN). Injected by
# iam.tf. Used by step 7/8 below to finish the Horde agent enrollment that the
# base module user_data could not complete on this AMI (see step 7 header).
$HordeServerUrl       = '${horde_server_url}'

# NOTE (R2): no $WorkspaceDriveLetter here — the build agent does NOT
# bootstrap-mount the source volume. The per-job clone is mounted at V: inside
# BuildPipeline.xml. FsxnNfsEndpoint / P4WorkspaceJunction are retained above
# for reference/logging only.

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    Write-Output "[$ts] [$Level] $Message"
}

# =============================================================================
# 1. Install the Windows NFS Client feature (idempotent).
#    On Windows Server 2022 the feature is "NFS-Client" (Client for NFS).
# =============================================================================
try {
    $nfsFeature = Get-WindowsFeature -Name 'NFS-Client'
    if ($nfsFeature -and $nfsFeature.Installed) {
        Write-Log 'NFS-Client feature already installed.'
    }
    else {
        Write-Log 'Installing NFS-Client feature...'
        $result = Install-WindowsFeature -Name 'NFS-Client'
        if (-not $result.Success) {
            throw "Install-WindowsFeature NFS-Client failed: $($result.ExitCode)"
        }
        Write-Log "NFS-Client installed. RestartNeeded=$($result.RestartNeeded)"
    }
}
catch {
    Write-Log "Failed to install NFS-Client feature: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# =============================================================================
# 2. Ensure choco is available, then install p4.exe (Helix P4 CLI) + AWS CLI
#    only if missing. The base agent-config.ps1 usually installs choco + p4;
#    these guarded installs make this script self-sufficient and idempotent.
# =============================================================================
function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

try {
    if (-not (Test-Command 'choco')) {
        Write-Log 'Chocolatey not found; installing...'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol =
            [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        # Refresh PATH for the current session so `choco` is callable.
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path', 'User')
    }
    else {
        Write-Log 'Chocolatey already present.'
    }

    if (-not (Test-Command 'p4')) {
        Write-Log 'p4.exe not found; installing p4 via choco...'
        & choco install p4 -y --no-progress
        if ($LASTEXITCODE -ne 0) { throw "choco install p4 failed ($LASTEXITCODE)" }
    }
    else {
        Write-Log 'p4.exe already installed; skipping.'
    }

    if (-not (Test-Command 'aws')) {
        Write-Log 'AWS CLI not found; installing awscli via choco...'
        & choco install awscli -y --no-progress
        if ($LASTEXITCODE -ne 0) { throw "choco install awscli failed ($LASTEXITCODE)" }
    }
    else {
        Write-Log 'AWS CLI already installed; skipping.'
    }

    # Refresh PATH so freshly installed tools are usable later in this session.
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
}
catch {
    Write-Log "Failed installing p4/AWS CLI: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# =============================================================================
# 3. Install the .NET 8 SDK (UE 5.5 UAT) via choco, only if an 8.x SDK is
#    missing. UE 5.5 RunUAT/BuildGraph targets .NET 8 and compiles the
#    automation csproj on the fly at job time, so the full SDK (not just a
#    runtime) is required. The base agent-config.ps1 installs dotnet but not
#    necessarily the .NET 8 SDK, so this guarded install makes the agent
#    self-sufficient and idempotent.
# =============================================================================
function Test-Dotnet8Sdk {
    # True if `dotnet --list-sdks` reports at least one 8.x SDK.
    if (-not (Test-Command 'dotnet')) { return $false }
    try {
        $sdks = & dotnet --list-sdks 2>$null
        return [bool]($sdks | Where-Object { $_ -match '^8\.' })
    }
    catch {
        return $false
    }
}

try {
    if (Test-Dotnet8Sdk) {
        Write-Log '.NET 8 SDK already installed; skipping.'
    }
    else {
        Write-Log '.NET 8 SDK not found; installing dotnet-8.0-sdk via choco...'
        & choco install dotnet-8.0-sdk -y --no-progress
        if ($LASTEXITCODE -ne 0) { throw "choco install dotnet-8.0-sdk failed ($LASTEXITCODE)" }

        # Refresh PATH so the freshly installed dotnet is callable in this session.
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path', 'User')

        if (-not (Test-Dotnet8Sdk)) {
            throw 'dotnet-8.0-sdk install reported success but no 8.x SDK is visible via dotnet --list-sdks.'
        }
        Write-Log '.NET 8 SDK installed and verified.'
    }
}
catch {
    Write-Log "Failed installing .NET 8 SDK: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# =============================================================================
# 4. Set P4PORT / P4USER as MACHINE-level env vars (NON-secret values only).
#    Values injected by Terraform. Never sets or handles the P4 password.
# =============================================================================
try {
    if (-not [string]::IsNullOrWhiteSpace($P4Port)) {
        [System.Environment]::SetEnvironmentVariable('P4PORT', $P4Port, 'Machine')
        Write-Log "Set machine env P4PORT=$P4Port"
    }
    else {
        Write-Log 'P4Port not provided; leaving P4PORT unset.' 'WARN'
    }

    if (-not [string]::IsNullOrWhiteSpace($P4User)) {
        [System.Environment]::SetEnvironmentVariable('P4USER', $P4User, 'Machine')
        Write-Log "Set machine env P4USER=$P4User"
    }
    else {
        Write-Log 'P4User not provided; leaving P4USER unset.' 'WARN'
    }
}
catch {
    Write-Log "Failed setting P4PORT/P4USER: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# =============================================================================
# 5. Establish P4 SSL trust for the build agent's run-as user (R1).
#    The Perforce server is SSL (ssl:<host>:1666). Before any `p4` command can
#    run against it, the run-as user must trust the server's SSL fingerprint —
#    otherwise the first `p4` call (the BuildPipeline incremental sync) fails
#    with an SSL trust error. This is the Windows analog of the Linux sync-agent
#    `p4 trust -y` fix (config/sync-agent.ansible.yml section 8).
#
#    Trust is stored per-user in %USERPROFILE%\p4trust.txt (or P4TRUST). This
#    SSM script runs as the SSM agent user (LocalSystem/SSM), and Horde build
#    jobs run as the Horde agent service account. To cover the account that
#    actually runs the build, we write trust MACHINE-wide by setting a fixed
#    machine-level P4TRUST path and running `p4 trust -y` against it; the build
#    job inherits the machine P4TRUST env var. `p4 trust -y` is idempotent — it
#    re-affirms the fingerprint on re-run.
#
#    SKIP CASE: when $P4Port is empty (operator wired an external endpoint
#    unknown at apply time) we skip trust, mirroring the null-safe P4PORT step.
# =============================================================================
try {
    if ([string]::IsNullOrWhiteSpace($P4Port)) {
        Write-Log 'P4Port not provided; skipping P4 SSL trust.' 'WARN'
    }
    elseif (-not (Test-Command 'p4')) {
        Write-Log 'p4.exe not available; cannot establish P4 SSL trust.' 'WARN'
    }
    else {
        # Machine-wide trust file so the Horde agent service account (which runs
        # the build job) uses the same trusted fingerprint we establish here.
        $P4TrustFile = 'C:\ProgramData\Perforce\p4trust.txt'
        $p4TrustDir  = Split-Path -Parent $P4TrustFile
        if (-not (Test-Path $p4TrustDir)) {
            New-Item -ItemType Directory -Path $p4TrustDir -Force | Out-Null
        }
        [System.Environment]::SetEnvironmentVariable('P4TRUST', $P4TrustFile, 'Machine')
        $env:P4TRUST = $P4TrustFile

        Write-Log "Establishing P4 SSL trust for $P4Port (P4TRUST=$P4TrustFile)..."
        # -y auto-accepts the fingerprint; idempotent (re-affirms on re-run).
        & p4 -p $P4Port trust -y 2>&1 | ForEach-Object { Write-Log "p4 trust: $_" }
        if ($LASTEXITCODE -ne 0) {
            throw "p4 trust -y returned $LASTEXITCODE for $P4Port"
        }
        Write-Log 'P4 SSL trust established/affirmed.'
    }
}
catch {
    Write-Log "Failed to establish P4 SSL trust: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# =============================================================================
# 6. NO bootstrap NFS mount of the SOURCE volume on the build agent (R2).
#
#    The build agent does NOT mount the persistent source volume. Each build job
#    creates its OWN per-job FlexClone from the hydrate snapshot and mounts THAT
#    clone (at drive V:) inside BuildPipeline.xml for the duration of the build
#    (CloneVolume -> mount.exe -> compile -> umount -> DeleteVolume).
#
#    WHY WE REMOVED THE OLD BOOTSTRAP W: SOURCE-MOUNT:
#      * Correctness: a build must read the CLONE, not the live source. Mounting
#        the source at W: at bootstrap created a W:-vs-clone collision (R2) that
#        risked the build compiling against the shared source volume.
#      * The clone is the whole point (ADR-004: per-job FlexClones): the build
#        agent has no need for the source volume mounted at all.
#      * Removing it also avoids a persistent NFS handle on the source from the
#        Windows agent (which is meant to scale 0->1->0 per build).
#    The NFS-Client feature is still installed above so BuildPipeline.xml's
#    per-job mount.exe works. FsxnNfsEndpoint / P4WorkspaceJunction remain
#    injected (they document the SVM NFS endpoint and are harmless) but are no
#    longer consumed for a bootstrap mount here.
# =============================================================================
Write-Log ('Skipping bootstrap source-volume mount by design (R2): the build ' +
           'uses a per-job FlexClone mounted at V: inside BuildPipeline.xml. ' +
           "SVM NFS endpoint (for reference): $FsxnNfsEndpoint")

# =============================================================================
# 7. Make the .NET 6 Horde AGENT runnable on this host, and (step 8) complete
#    the Horde agent enrollment.
#
#    ROOT CAUSE this fixes (live-diagnosed on the first BuildAgent bringup):
#      The base module Windows user_data (agent-config.ps1) does, at first boot:
#        `choco install -y --no-progress dotnet-6.0-runtime`
#        `HordeAgent.exe SetServer -Default -Url=<horde>`
#        `HordeAgent.exe Service Install -Start=false`
#      But on this AMI Chocolatey is NOT present when user_data runs, so the
#      `choco install dotnet-6.0-runtime` step FAILS ("'choco' is not
#      recognized"). HordeAgent.exe is a .NET 6 app (runtimeconfig tfm=net6.0,
#      Microsoft.NETCore.App 6.0.0). With no .NET 6 runtime, SetServer and
#      Service Install ALSO fail ("You must install or update .NET to run this
#      application ... framework 'Microsoft.NETCore.App' version '6.0.0'"), so
#      the agent service is never installed and the agent NEVER enrolls.
#
#    FIX (no module change, no extra download): this extension already installs
#    the .NET 8 SDK (step 3) for UE 5.5 UAT. Rather than fetch a separate .NET 6
#    runtime (the choco `aspnetcore-runtime-6.0`/`dotnet-6.0-runtime` packages
#    are unreliable/absent on the community feed), we set
#    DOTNET_ROLL_FORWARD=LatestMajor MACHINE-wide. That tells the .NET host to
#    run the net6.0 HordeAgent on the already-installed .NET 8 shared framework
#    (roll-forward across a major version). Live-verified: with this set, the
#    agent launches ("Version: 5.5.0-...", "Application started"). Machine-wide
#    so the HordeAgent Windows service (step 8) inherits it.
# =============================================================================
function Test-DotnetRuntimeAny {
    if (-not (Test-Command 'dotnet')) { return $false }
    try {
        $rts = & dotnet --list-runtimes 2>$null
        return [bool]($rts | Where-Object { $_ -match '^Microsoft\.NETCore\.App ' })
    }
    catch { return $false }
}

try {
    if (-not (Test-DotnetRuntimeAny)) {
        throw 'No Microsoft.NETCore.App runtime found; cannot run the Horde agent. Step 3 (.NET 8 SDK) should have provided one.'
    }
    # Roll-forward across major versions so the net6.0 agent runs on .NET 8.
    [System.Environment]::SetEnvironmentVariable('DOTNET_ROLL_FORWARD', 'LatestMajor', 'Machine')
    $env:DOTNET_ROLL_FORWARD = 'LatestMajor'
    Write-Log 'Set machine env DOTNET_ROLL_FORWARD=LatestMajor (net6.0 agent runs on installed .NET 8).'
}
catch {
    Write-Log "Failed to configure .NET roll-forward for the Horde agent: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# =============================================================================
# 8. Complete Horde agent enrollment: SetServer + Service Install/Start.
#    Idempotent — SetServer re-affirms the profile; Service Install is a no-op
#    if the service already exists (we then just ensure it is started).
#    Skipped (with a warning) if HordeServerUrl or HordeAgent.exe is absent.
# =============================================================================
try {
    $HordeExe = 'C:\Horde\HordeAgent.exe'
    if ([string]::IsNullOrWhiteSpace($HordeServerUrl)) {
        Write-Log 'HordeServerUrl not provided; skipping Horde agent enrollment.' 'WARN'
    }
    elseif (-not (Test-Path $HordeExe)) {
        Write-Log "HordeAgent.exe not found at $HordeExe; cannot enroll. Base user_data may not have downloaded it." 'WARN'
    }
    else {
        Write-Log "Configuring Horde server URL: $HordeServerUrl"
        & $HordeExe SetServer -Default -Url="$HordeServerUrl" 2>&1 | ForEach-Object { Write-Log "SetServer: $_" }
        if ($LASTEXITCODE -ne 0) { throw "HordeAgent SetServer returned $LASTEXITCODE" }

        $svc = Get-Service -Name 'HordeAgent' -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Log 'Installing HordeAgent service...'
            & $HordeExe Service Install -Start=true 2>&1 | ForEach-Object { Write-Log "Service Install: $_" }
            if ($LASTEXITCODE -ne 0) { throw "HordeAgent Service Install returned $LASTEXITCODE" }
        }
        else {
            Write-Log "HordeAgent service already exists (Status=$($svc.Status)); ensuring it is started."
        }

        # SCM cannot resolve the bare `dotnet` token in the service ImagePath
        # that `Service Install` registers ("dotnet \"C:\Horde\HordeAgent.dll\"
        # service run") — the service start fails with ERROR_FILE_NOT_FOUND
        # (0x2) because the SCM launch environment does not search the full PATH
        # for the image. Rewrite the ImagePath to the ABSOLUTE dotnet.exe so the
        # service can start. Live-verified fix. We set it via the registry
        # (ExpandString) to avoid sc.exe's brittle quoting of the space in
        # "C:\Program Files\dotnet".
        $dotnetExe = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
        $svcReg    = 'HKLM:\SYSTEM\CurrentControlSet\Services\HordeAgent'
        if ((Test-Path $dotnetExe) -and (Test-Path $svcReg)) {
            $curImage = (Get-ItemProperty -Path $svcReg -Name ImagePath -ErrorAction SilentlyContinue).ImagePath
            if ($curImage -notlike ('*' + $dotnetExe + '*')) {
                $newImage = '"{0}" "C:\Horde\HordeAgent.dll" service run' -f $dotnetExe
                Set-ItemProperty -Path $svcReg -Name ImagePath -Value $newImage -Type ExpandString
                Write-Log "Rewrote HordeAgent service ImagePath to absolute dotnet: $newImage"
            }
            else {
                Write-Log 'HordeAgent service ImagePath already absolute; leaving as-is.'
            }
        }

        # Ensure the service is running regardless of the install path.
        Set-Service -Name 'HordeAgent' -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name 'HordeAgent' -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        $svc = Get-Service -Name 'HordeAgent' -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Log "HordeAgent service status: $($svc.Status)"
            if ($svc.Status -ne 'Running') {
                Write-Log 'HordeAgent service not Running after start; check C:\ProgramData\Epic\Horde\Agent logs.' 'WARN'
            }
        }
        else {
            Write-Log 'HordeAgent service not present after install attempt.' 'WARN'
        }
        Write-Log ('Horde agent enrollment step completed. NOTE: a newly ' +
                   'enrolled agent waits in the Horde ENROLLMENT queue until ' +
                   'approved (GET/POST /api/v1/enrollment) or auto-approved by ' +
                   'server policy before it joins its pool.')
    }
}
catch {
    Write-Log "Failed to complete Horde agent enrollment: $($_.Exception.Message)" 'ERROR'
    exit 1
}

Write-Log 'Build agent extension setup completed successfully.'
exit 0
