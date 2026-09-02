# Packer Template — Unreal Engine Horde Windows Build Agent

This template builds a Windows Server 2022 AMI for the **Unreal Engine Horde**
build/sync agent pools (the `samples/unreal-horde-build-pipeline` iSCSI/NTFS
thin-clone pipeline). It is a **fork** of the Jenkins-oriented template in
`../windows`, adapted for Horde and iSCSI-backed workspaces.

## Usage

Build in a **private / ingress-limited** subnet (defaults keep the temporary
build instance off the public internet):

```bash
packer init .
packer build \
  -var "region=us-east-1" \
  -var "vpc_id=vpc-xxxxxxxx" \
  -var "subnet_id=subnet-xxxxxxxx" \
  -var "public_key=<include public ssh key here>" \
  windows-horde.pkr.hcl
```

Or use the provided `example.pkrvars.hcl` as a starting point:

```bash
packer build -var-file="example.pkrvars.hcl" windows-horde.pkr.hcl
```

The resulting AMI name is prefixed `windows-horde-build-agent-<timestamp>`. The
Terraform sample looks it up by that prefix via `data.aws_ami`, so no AMI ID is
hardcoded.

### Security

- `associate_public_ip_address` defaults to **false** and `ssh_interface` to
  **`private_ip`** — run Packer from inside the VPC (CodeBuild/bastion).
- The build **never opens WinRM (5986) to `0.0.0.0/0`**. When no
  `security_group_id` is supplied, Packer scopes the temporary SG's ingress to
  the builder's own IP. If you enable a public IP, you must supply a
  CIDR-scoped `security_group_id`.

## Installed Tooling (what this AMI bakes)

- Chocolatey package manager
- Git
- OpenSSH Server
- Python 3 + botocore + boto3
- Windows Development Kit / Debugging Tools (PDBCOPY)
- Visual Studio 2022 Build Tools
  - VCTools workload (include recommended)
  - ManagedDesktopBuildTools workload (include recommended)
  - MSVC v143 — VC 14.38.17.8 x86/x64 build tools
  - Microsoft.Net.Component.4.6.2.TargetingPack
- **.NET 6.0 runtime** (matches the Horde module `agent_dotnet_runtime_version`
  default = `6.0`, so the module's first-boot `choco install dotnet-6.0-runtime`
  is a no-op)
- **.NET 8 SDK** (Unreal Engine 5.5 UnrealAutomationTool)
- **Perforce `p4` client** (matches the module's first-boot install)
- **AWS CLI** (used by the iSCSI/SAN pipeline scripts)
- **MSiSCSI initiator** service set to **Automatic**
- **Multipath I/O (MPIO)** feature enabled + **MSDSM** set to auto-claim iSCSI

## Diff vs. the Jenkins template (`../windows`)

| Area | Jenkins template | This (Horde) template |
|------|------------------|-----------------------|
| Jenkins local user | created (`setup_jenkins_agent.ps1`) | **dropped** |
| OpenJDK | installed (Jenkins agent) | **dropped** |
| NFS-Client | `Install-WindowsFeature NFS-Client` | **removed** (iSCSI instead) |
| .NET 6 runtime | — | **added** |
| .NET 8 SDK | — | **added** |
| p4 client | — | **added** (baked; module no-op) |
| AWS CLI | — | **added** |
| MSiSCSI initiator | — | **added** (Automatic) |
| MPIO + MSDSM claim | — | **added** |
| VS2022 Build Tools + WDK | kept | **kept** (identical recipe) |
| choco / git / OpenSSH / Python | kept | **kept** |
| WinRM userdata bootstrap | kept | **kept** |
| Public IP / interface | public by default | **private by default** |
| In-build validation | — | **added** (`validate_image.ps1`) |

## iSCSI baking — the SPIKE

**Question:** can MSiSCSI enablement + initiator IQN materialization be fully
baked into the AMI, or is a per-boot step unavoidable?

**What is baked (image-time, machine-independent):**

- MSiSCSI service → **Automatic** start (initiator running on first boot, no
  per-boot enable).
- MPIO feature enabled.
- MSDSM set to auto-claim iSCSI devices.

**What CANNOT be baked (must be per-instance):**

- **The initiator IQN.** On Windows the IQN is stored under
  `HKLM\SYSTEM\CurrentControlSet\Control\Class\{iSCSI}\...\NodeName` and is
  derived per install. **Baking a fixed IQN into the AMI would give every agent
  the same IQN**, which breaks the per-agent igroup model on FSxN/ONTAP: each
  agent must present a unique IQN so its clone LUN maps to exactly one host. So
  the IQN must be materialized per-instance (a fresh, unique IQN, or a
  deterministic per-instance IQN derived from the instance-id), and target
  portal discovery + LUN login happen at job time (targets are only known then).

**Recommendation → (b): keep a SLIM per-boot iSCSI step.** The bulk (service
state, MPIO, MSDSM claim) is baked; only the per-instance IQN materialization +
target login remain per-boot. That is a thin, machine-specific step that cannot
correctly live in an AMI. Full SSM deletion **(a) is not viable**. A module
user_data hook **(c) is not required** — the sample-side SSM association can
carry the slim per-boot step, so no `modules/` change is needed for Phase 2.

## Files

| File | Purpose |
|------|---------|
| `windows-horde.pkr.hcl` | Packer template (source + build + provisioners) |
| `userdata.ps1` | WinRM bootstrap for the Packer communicator |
| `base_setup.ps1` | choco, git, OpenSSH, Python (NFS-Client removed) |
| `install_vs_tools.ps1` | VS2022 Build Tools + VC 14.38 + WDK/PDBCOPY |
| `install_horde_agent_tools.ps1` | .NET 6 runtime, .NET 8 SDK, p4, awscli |
| `install_iscsi.ps1` | MSiSCSI Automatic + MPIO + MSDSM iSCSI claim |
| `validate_image.ps1` | in-build assertion of toolchain + iSCSI + MPIO |
| `example.pkrvars.hcl` | example variables (generic, no account values) |
