<#
    agent-san-setup.ps1.tpl - boot-time configuration for BOTH Horde agent pools
    on the iSCSI/SAN data path. Rendered by templatefile() from iam.tf and
    delivered inline via an AWS-RunPowerShellScript SSM association.

    REPLACES two files from the NFS design:
      * config/sync-agent.ansible.yml  - a Linux playbook that fstab-mounted the
        source volume over NFSv3. The hydrator is Windows now (the source LUN
        carries NTFS), so a Linux playbook cannot configure it at all.
      * the NFS half of config/build-agent-setup.ps1.tpl - the NFS-Client feature
        and the mount.exe of the source volume to W:.

    WHAT IT DOES NOT DO, ON PURPOSE:
      * It does not attach any LUN. Attaching happens per job
        (attach-clone-lun.ps1 / hydrate-source-lun.ps1), because the clone does
        not exist until the job runs and the source LUN must only ever be
        attached by the single hydrator.
      * It does not add this host to an igroup. The job scripts do that, and the
        distinction matters: the shared clone igroup is self-service, the
        single-host source igroup is not.
      * It does not install MPIO. With one portal connected, MPIO is unnecessary;
        with MPIO absent, connecting a second portal would make Windows enumerate
        one LUN as two disks. Leaving MPIO out is what makes the single-portal
        rule safe.

    Terraform interpolations (all NON-secret): ${agent_role}, ${p4_port},
    ${p4_user}. Every PowerShell variable below uses bare $name - never $${name} -
    so templatefile() cannot mistake one for an interpolation.
#>

$ErrorActionPreference = 'Continue'   # a partial config must not abort the boot
$ProgressPreference    = 'SilentlyContinue'

$AgentRole = '${agent_role}'          # "hydrator" or "build"
$P4Port    = '${p4_port}'
$P4User    = '${p4_user}'

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    Write-Host ('[{0}] [{1}] [agent-san-setup/{2}] {3}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $AgentRole, $Message)
}

Write-Log "starting; role=$AgentRole"

# =============================================================================
# 1. iSCSI initiator service.
#
# This is the one thing that MUST happen at boot rather than at job time: the
# Windows IQN is derived from the hostname and is only materialised once MSiSCSI
# has run, and EC2 renames the machine on first boot. Starting the service here
# means the IQN is stable and discoverable by the time a job tries to register it
# with an igroup.
# =============================================================================
try {
    Set-Service -Name MSiSCSI -StartupType Automatic
    Start-Service -Name MSiSCSI -ErrorAction SilentlyContinue
    $svc = Get-Service -Name MSiSCSI
    Write-Log "MSiSCSI service: $($svc.Status) (startup=Automatic)"

    $iqn = (Get-InitiatorPort | Where-Object { $_.NodeAddress -like 'iqn.*' } | Select-Object -First 1).NodeAddress
    if ($iqn) {
        Write-Log "initiator IQN: $iqn"
        Write-Log 'NOTE: this IQN changes if the machine is renamed. Job scripts re-register it, so a rename is self-healing.'
    } else {
        Write-Log 'no IQN yet - it will appear once MSiSCSI finishes initialising' 'WARN'
    }
} catch {
    Write-Log "failed to configure MSiSCSI: $($_.Exception.Message)" 'ERROR'
}

# =============================================================================
# 2. Chocolatey, then p4.exe + AWS CLI, only if missing.
#
# p4 is needed on BOTH pools now: the hydrator syncs the source LUN, and the
# build agent runs `p4 flush` + `p4 sync` against the clone. The AWS CLI is how
# the scripts read the ONTAP and Perforce passwords out of Secrets Manager, so it
# is not optional either.
# =============================================================================
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    try {
        Write-Log 'installing Chocolatey...'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:PATH += ';C:\ProgramData\chocolatey\bin'
    } catch {
        Write-Log "Chocolatey install failed: $($_.Exception.Message)" 'ERROR'
    }
} else {
    Write-Log 'Chocolatey already present'
}

foreach ($pkg in @(
    @{ Cmd = 'p4.exe';  Package = 'p4' },
    @{ Cmd = 'aws.exe'; Package = 'awscli' }
)) {
    if (Get-Command $pkg.Cmd -ErrorAction SilentlyContinue) {
        Write-Log "$($pkg.Cmd) already present"
        continue
    }
    try {
        Write-Log "installing $($pkg.Package)..."
        & choco install $pkg.Package -y --no-progress --limit-output | Out-Null
        Write-Log "$($pkg.Package) install exit code: $LASTEXITCODE"
    } catch {
        Write-Log "failed to install $($pkg.Package): $($_.Exception.Message)" 'ERROR'
    }
}

# =============================================================================
# 3. Machine-wide P4PORT / P4USER (NON-secret).
#
# The PASSWORD is never injected here - it stays in Secrets Manager and is read
# at job time. Empty values mean no Perforce endpoint exists yet, so skip rather
# than write a broken setting.
# =============================================================================
if ([string]::IsNullOrWhiteSpace($P4Port)) {
    Write-Log 'P4PORT not supplied (no Perforce endpoint yet) - skipping' 'WARN'
} else {
    [Environment]::SetEnvironmentVariable('P4PORT', $P4Port, 'Machine')
    [Environment]::SetEnvironmentVariable('P4USER', $P4User, 'Machine')
    Write-Log "set machine P4PORT=$P4Port P4USER=$P4User"
}

# =============================================================================
# 4. NTFS long paths.
#
# Unreal's generated paths exceed 260 chars routinely, and the failure is an
# obscure mid-build IO error rather than anything mentioning path length.
# =============================================================================
try {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
        -Name 'LongPathsEnabled' -Value 1 -Type DWord
    Write-Log 'LongPathsEnabled=1'
} catch {
    Write-Log "could not set LongPathsEnabled: $($_.Exception.Message)" 'WARN'
}

# =============================================================================
# 5. Report leftovers from a previous lease.
#
# An iSCSI disk present at boot means a previous job's clone was never detached -
# usually a hard Spot reclaim, which runs neither on-agent teardown path. Report
# it rather than act: deleting a LUN this host does not own is worse than a leak,
# and the off-agent reaper is the right place to clean up.
# =============================================================================
try {
    $stale = @(Get-Disk | Where-Object { $_.BusType -eq 'iSCSI' })
    if ($stale.Count -gt 0) {
        Write-Log "$($stale.Count) iSCSI disk(s) already attached at boot - a previous lease may have leaked a clone:" 'WARN'
        foreach ($d in $stale) { Write-Log "  disk $($d.Number) serial=$($d.SerialNumber) offline=$($d.IsOffline)" 'WARN'}
        Write-Log 'The off-agent reaper should collect any orphaned clone volumes.' 'WARN'
    } else {
        Write-Log 'no pre-existing iSCSI disks'
    }
} catch {
    Write-Log "could not enumerate disks: $($_.Exception.Message)" 'WARN'
}

Write-Log 'complete'
