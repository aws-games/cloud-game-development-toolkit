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
   * an NFSv3 mount of the FSxN source volume to drive letter W:
   * machine-level P4PORT / P4USER env vars (NON-secret values only)

 ADR notes:
   * ADR-001: Build Agents run Windows Server 2022.
   * ADR-002: NFS ONLY (never SMB/CIFS/AD). Windows NFS Client is NFSv3 — mount
              with `mount.exe -o ... \\<endpoint>\<junction> W:`. Drive letter W:
              is chosen to keep paths short (MAX_PATH headroom).
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

$WorkspaceDriveLetter = 'W:'
$NfsMountOptions       = 'mtype=hard,nolock,casesensitive=yes'  # NFSv3 client opts

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
# 3. Set P4PORT / P4USER as MACHINE-level env vars (NON-secret values only).
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
# 4. Mount the FSxN source volume to drive W: via the Windows NFS client (NFSv3).
#    Idempotent: skip if W: is already mapped. Requires the FsxnNfsEndpoint and
#    P4WorkspaceJunction values; if absent, warn and skip (do not fail the run).
# =============================================================================
try {
    if ([string]::IsNullOrWhiteSpace($FsxnNfsEndpoint) -or [string]::IsNullOrWhiteSpace($P4WorkspaceJunction)) {
        Write-Log ('FsxnNfsEndpoint/P4WorkspaceJunction value(s) missing; skipping ' +
                   'NFS mount. These are injected by Terraform at apply time.') 'WARN'
    }
    elseif (Test-Path $WorkspaceDriveLetter) {
        Write-Log "$WorkspaceDriveLetter already mounted; skipping NFS mount."
    }
    else {
        # Windows NFS uses backslashes and the junction path WITHOUT its leading
        # slash: \\<endpoint>\<junction>. e.g. \\svm-x.fs-x...\p4-workspace
        $junctionNoSlash = $P4WorkspaceJunction.TrimStart('/').Replace('/', '\')
        $unc = "\\$FsxnNfsEndpoint\$junctionNoSlash"
        Write-Log "Mounting NFS (NFSv3) $unc -> $WorkspaceDriveLetter"

        & mount.exe -o $NfsMountOptions $unc $WorkspaceDriveLetter
        if ($LASTEXITCODE -ne 0) {
            throw "mount.exe returned $LASTEXITCODE for $unc"
        }

        if (-not (Test-Path $WorkspaceDriveLetter)) {
            throw "Mount reported success but $WorkspaceDriveLetter is not accessible."
        }
        Write-Log "Mounted FSxN source volume at $WorkspaceDriveLetter (NFSv3)."
    }
}
catch {
    Write-Log "Failed to mount FSxN source volume: $($_.Exception.Message)" 'ERROR'
    exit 1
}

Write-Log 'Build agent extension setup completed successfully.'
exit 0
