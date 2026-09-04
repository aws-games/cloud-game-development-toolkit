function Write($message) {
    Write-Output $message
}

# iSCSI initiator + MPIO baking for Horde build agents.
#
# WHAT IS SAFELY BAKED HERE (image-time, machine-independent):
#   - MSiSCSI service set to Automatic start (so the initiator is running on
#     first boot without a per-boot enable step).
#   - Multipath I/O (MPIO) Windows feature enabled.
#   - MSDSM configured to auto-claim iSCSI-attached devices.
#
# WHAT IS *NOT* BAKED AS A FIXED VALUE HERE (materialized per-instance every boot):
#   - The initiator IQN VALUE. On Windows the IQN lives in
#     HKLM\SYSTEM\CurrentControlSet\Control\Class\{iSCSI}\...\NodeName and is
#     generated from the machine name / a per-install GUID. If we froze a
#     concrete IQN into the AMI, EVERY agent launched from it would present the
#     SAME IQN to the FSxN/ONTAP SAN. That breaks the per-agent igroup model
#     (each agent needs its own igroup membership so clone LUNs map to exactly
#     one host).
#
#     The IQN UNIQUENESS IS handled by a BAKED ONSTART Scheduled Task that runs
#     set_unique_iqn.ps1 (dropped at C:\ProgramData\horde\set_unique_iqn.ps1)
#     on every boot. That script derives a deterministic, per-instance IQN from
#     the EC2 instance-id (iqn.1991-05.com.microsoft:<instance-id>) via IMDSv2,
#     input-free (no ONTAP, no Perforce, no Terraform values). So the MECHANISM
#     is baked into the AMI; only the VALUE is per-instance. See
#     set_unique_iqn.ps1 and register_iqn_task.ps1.
#   - Target portal discovery + LUN login (target addresses are only known at
#     job time from Terraform/ONTAP output) - that is pipeline/job-time work
#     handled by buildgraph/attach-clone-lun.ps1 + hydrate-source-lun.ps1.
#
# See validate_image.ps1 and the SPIKE section of the README for the resulting
# recommendation.

try {
    Write "Setting MSiSCSI initiator service to Automatic"
    Set-Service -Name MSiSCSI -StartupType Automatic
    # Start it now so the provisioner/validation can query it; on real agents
    # EC2 sysprep will restart it at boot per the Automatic start type.
    Start-Service -Name MSiSCSI -ErrorAction SilentlyContinue
}
catch {
    Write "Failed to configure MSiSCSI service"
}

try {
    Write "Enabling Multipath I/O (MPIO) feature"
    # Server SKU: Add-WindowsFeature is the supported path. Enable-WindowsOptionalFeature
    # is the client-equivalent; try the optional-feature form as a fallback.
    $mpio = Install-WindowsFeature -Name Multipath-IO -ErrorAction SilentlyContinue
    if (-not $mpio -or -not $mpio.Success) {
        Enable-WindowsOptionalFeature -Online -FeatureName MultiPathIO -NoRestart -ErrorAction SilentlyContinue
    }
}
catch {
    Write "Failed to enable MPIO feature"
}

try {
    Write "Configuring MSDSM to claim iSCSI devices"
    # Auto-claim all iSCSI-attached devices for MPIO. This is a machine-level
    # policy and is safe to bake. Requires the MPIO feature (above) to be present.
    Enable-MSDSMAutomaticClaim -BusType iSCSI -ErrorAction SilentlyContinue
    # Set a sensible default load-balance policy for claimed devices.
    Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR -ErrorAction SilentlyContinue
}
catch {
    Write "Failed to configure MSDSM iSCSI claim (MPIO may require a reboot before MSDSM cmdlets are available)"
}

Write "iSCSI / MPIO baking step complete."
