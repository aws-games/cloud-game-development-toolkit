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
- **Baked ONSTART Scheduled Task** (`Horde-SetUniqueIqn`) that derives a unique,
  instance-id-based initiator IQN on every boot (input-free)

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

## iSCSI baking — the SPIKE (RESOLVED)

**Question:** can MSiSCSI enablement + initiator IQN materialization be fully
baked into the AMI, or is a per-boot SSM step unavoidable?

**Answer: fully baked. No SSM association is needed.** The only true per-boot
iSCSI need is LOCAL and INPUT-FREE: (1) MSiSCSI running, and (2) a UNIQUE
initiator IQN per agent. Both are now baked into the AMI — (1) as service state,
(2) as a baked ONSTART Scheduled Task that derives the IQN from the instance-id
every boot. All ONTAP contact (discovery, login, igroup add, LUN map, mount) and
all Perforce work happen JUST-IN-TIME at JOB time in
`buildgraph/attach-clone-lun.ps1` + `buildgraph/hydrate-source-lun.ps1`, so boot
needs ZERO ONTAP config and ZERO Perforce env.

**What is baked (image-time, machine-independent):**

- MSiSCSI service → **Automatic** start (initiator running on first boot, no
  per-boot enable).
- MPIO feature enabled.
- MSDSM set to auto-claim iSCSI devices.
- **A baked ONSTART Scheduled Task** (`Horde-SetUniqueIqn`, SYSTEM, RunLevel
  Highest) that runs `C:\ProgramData\horde\set_unique_iqn.ps1` on every boot.

**The initiator IQN — mechanism baked, value per-instance:**

On Windows the IQN is stored under
`HKLM\SYSTEM\CurrentControlSet\Control\Class\{iSCSI}\...\NodeName` and is derived
per install. **Baking a fixed IQN into the AMI would give every agent the same
IQN**, which breaks the per-agent igroup model on FSxN/ONTAP: each agent must
present a unique IQN so its clone LUN maps to exactly one host, and a collision is
a silent NTFS-corruption trap.

The resolution bakes the **mechanism** (the ONSTART task + the script) while
leaving the **value** per-instance. On every boot, `set_unique_iqn.ps1`:

1. reads the EC2 instance-id from **IMDSv2** (PUT token, then GET
   `/latest/meta-data/instance-id`), falling back to a stable local
   identifier and logging it if IMDS is unavailable;
2. sets a deterministic, host-unique IQN
   `iqn.1991-05.com.microsoft:<instance-id>` via `Set-InitiatorPort`,
   idempotently (only if different);
3. ensures MSiSCSI is Automatic + running;
4. logs the resulting IQN.

This is **input-free**: no ONTAP, no Perforce, no Terraform values are needed at
boot. Target portal discovery + LUN login stay at job time (targets are only
known then).

**Recommendation → (a) full baked boot, NO SSM.** The sample-side SSM
associations that previously carried a "slim per-boot step" (machine
P4PORT/P4USER + initiator setup) are **deleted**: the job scripts authenticate to
Perforce explicitly (`hydrate-source-lun.ps1` sets its own P4PORT/P4USER from
mandatory params and mints a ticket from Secrets Manager; `BuildPipeline.xml`
passes `p4.exe -p/-u/-c` explicitly), and the unique-IQN + MSiSCSI needs are now
baked. Boot is input-free; no `modules/` change is required.

## In-build validation

`validate_image.ps1` fails the Packer build (non-zero exit) if any required
component is missing. In addition to the MSVC toolchain, MSiSCSI (Automatic), and
MPIO checks, it asserts the boot-time IQN mechanism: the
`C:\ProgramData\horde\set_unique_iqn.ps1` file exists AND the `Horde-SetUniqueIqn`
Scheduled Task is registered.

## Files

| File | Purpose |
|------|---------|
| `windows-horde.pkr.hcl` | Packer template (source + build + provisioners) |
| `userdata.ps1` | WinRM bootstrap for the Packer communicator |
| `base_setup.ps1` | choco, git, OpenSSH, Python (NFS-Client removed) |
| `install_vs_tools.ps1` | VS2022 Build Tools + VC 14.38 + WDK/PDBCOPY |
| `install_horde_agent_tools.ps1` | .NET 6 runtime, .NET 8 SDK, p4, awscli |
| `install_iscsi.ps1` | MSiSCSI Automatic + MPIO + MSDSM iSCSI claim |
| `set_unique_iqn.ps1` | baked per-boot script: derives a unique instance-id IQN (dropped at `C:\ProgramData\horde\`) |
| `register_iqn_task.ps1` | image-time step: registers the ONSTART Scheduled Task that runs `set_unique_iqn.ps1` every boot |
| `validate_image.ps1` | in-build assertion of toolchain + iSCSI + MPIO + boot-IQN task |
| `example.pkrvars.hcl` | example variables (generic, no account values) |
