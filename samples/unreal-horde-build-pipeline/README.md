# Unreal Horde Build Pipeline

This sample deploys an [Unreal Engine Horde](https://dev.epicgames.com/documentation/en-us/unreal-engine/horde) build farm that compiles from a Perforce stream using [Amazon FSx for NetApp ONTAP](https://aws.amazon.com/fsx/netapp-ontap/) with a thin-clone workspace pattern. Instead of every build agent running a full `p4 sync` from scratch, the pipeline keeps one persistent source workspace warm and hands each build an instant, copy-on-write clone of it.

The core idea has two moving parts. A **Hydrator** (Sync) agent periodically syncs a persistent FSxN **LUN** from a Perforce stream and snapshots it as `cl-<changelist>`. When a build is requested, a **Build Agent** creates an instant [FlexClone](https://docs.netapp.com/us-en/ontap/concepts/flexclone-volumes-concept.html) of that snapshot, presents the clone's LUN to itself over **iSCSI as real NTFS**, transplants the Perforce have-list with `p4 flush` (metadata-only), syncs only the delta, compiles, and tears the clone down. The result is per-build workspaces in ~10 s instead of a multi-minute full sync, with UBA enabled.

**The data path is iSCSI/NTFS, not NFS.** Both agent pools are Windows. See *Operational requirements* below for why — the short version is that Windows NFSv3 cannot run a UBA build at all.

## Architecture

The sample composes existing CGD Toolkit modules (`modules/perforce`, `modules/unreal/horde`) with sample-owned networking, DNS, storage, and security wiring.

- **VPC** — a 3-tier layout across 2 AZs: public subnets (ALBs / NAT), private application subnets (Horde ECS tasks, Perforce, agents), and private service subnets (FSxN).
- **FSx for NetApp ONTAP** — an iSCSI/SAN SVM (no CIFS/AD) with a persistent source volume `p4_workspace` acting as a **container for a thin LUN** (`/vol/p4_workspace/workspace`). Terraform creates the file system, SVM and container volume; the LUN, igroups, LUN maps, snapshots and per-build FlexClones are all runtime operations via the ONTAP REST API, because the AWS provider cannot create them.
- **Horde server** — runs on ECS behind an external HTTPS ALB (browser access) and an internal ALB (agent enrollment / in-VPC traffic). Config is rendered from `config/horde/globals.json.tpl` and passed inline to the module.
- **Hydrator (Sync) Agent pool** — **Windows Server 2022** in the Horde pool `SyncPool`, `min = max = 1`. Windows because the source LUN carries NTFS, and exactly one because NTFS has exactly one legitimate writer (enforced by a single-host igroup, not merely documented).
- **Build Agent pool** — Windows Server 2022 agents in the Horde pool `BuildPool`. Scales from 0 to `build_agent_max_count`. Each job gets its own clone LUN, so these agents share one igroup safely.
- **Perforce** — the bundled `modules/perforce` P4 Server (private subnet, commit server) is deployed by default. Set `existing_perforce_server_endpoint` to wire the agents to a server you already run and skip the bundled module.
- **Route53** — a private hosted zone (created by this sample) for internal service discovery, plus records in your existing public hosted zone for the Horde HTTPS endpoint.
- **ACM certificate** — DNS-validated against your public hosted zone for the Horde external ALB HTTPS listener.

Two BuildGraph pipelines drive the workflow, and their agent/node names are coupled to `config/horde/globals.json.tpl`:

- `buildgraph/HydratePipeline.xml` — agent `SyncAgent`, node `Sync And Snapshot`, run by the `hydrate` template on `SyncPool`.
- `buildgraph/BuildPipeline.xml` — agent `BuildAgent`, nodes `Clone And Mount` / `Compile` / `Cleanup Clone`, run by the `build` template on `BuildPool`. Guaranteed teardown is a Horde `UE_HORDE_CLEANUP` lease hook, **not** the cleanup node — see below.

```text
                         Perforce stream (//YourGame/main)
                                     |
                          p4 sync (full, scheduled hourly)
                                     v
   Hydrator (Windows, SyncPool) --> source LUN over iSCSI (S:, NTFS)
   HydratePipeline.xml               /vol/p4_workspace/workspace
   node "Sync And Snapshot"          igroup: horde_san_hydrator (ONE host)
                                            |
                                     flush NTFS cache, then snapshot cl-<N>
                                            |
                                   instant FlexClone (per build)
                                            v
   Build Agent (Windows, BuildPool) --> map clone LUN -> igroup horde_san_agents
   BuildPipeline.xml                --> iSCSI attach as W: (real NTFS)
   "Clone And Mount"                --> p4 flush @<N>   (have-list, no transfer)
   "Compile"                        --> p4 sync         (delta only)
   "Cleanup Clone"                  --> compile with UBA ENABLED
   + UE_HORDE_CLEANUP lease hook    --> offline disk, unmap LUN, delete clone

   Horde server (ECS) -- external HTTPS ALB (deployer /32) --> browser UI
                      -- internal ALB --------------------> agent enrollment
```


## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) and valid AWS credentials for the target account.
- An **existing Route53 public hosted zone** (required). The ACM certificate DNS validation records and the public Horde record are created in this zone. This sample does not create the public zone for you.
- **Epic Games GitHub organization access.** The default Horde server image `ghcr.io/epicgames/horde-server:latest-bundled` is pulled from the GitHub Container Registry and requires membership in the Epic Games GitHub organization. Either:
  - provide `github_credentials_secret_arn` — a Secrets Manager secret with GitHub credentials that can read the private image; or
  - override `horde_server_image` with an image you can pull without authentication.
- **A pre-created Secrets Manager secret for the Horde P4 user (required when deploying the bundled Perforce).** Create a Secrets Manager secret shaped `{"username":"svc-horde","password":"..."}` and pass its ARN via the `horde_p4_credentials_secret_arn` variable. This sample does **not** create this secret for you. A pre-created secret keeps the ARN a known value at plan time — the Horde module gates its Secrets Manager read policy on a `count` that cannot resolve against an ARN that is only known after apply. (If you set `existing_perforce_server_endpoint` to use your own Perforce server, provide the secret for that server's Horde service account instead.)
- **No custom BuildGraph task compilation is required.** The SAN pipelines drive ONTAP and the Windows iSCSI initiator from PowerShell (`buildgraph/OntapSan.psm1` plus three scripts), so you do **not** need to compile the C# tasks in `assets/buildgraph/tasks` into your `AutomationTool`. This is deliberate: LUN mapping/unmapping does not exist in those tasks, and teardown ordering (offline disk → unmap → delete volume) is a correctness requirement they cannot express. It also means the pipeline can be tested without a UAT build. The C# tasks remain in the repo for the NAS path.
- **BuildGraph scripts submitted to the depot.** The `buildgraph/*.xml` files must be submitted to your Perforce depot under `Build/` so that the `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` paths in `globals.json` resolve against the stream root.

## Build the Windows build-agent AMI (manual prerequisite)

This is a **one-time operator step you run before `terraform apply`.** It is intentionally **not** automated by this sample — building a Windows image with the full Unreal C++ toolchain takes ~30-45 minutes, and baking it once is far cheaper than re-installing the toolchain on every agent boot.

### Why it's needed

The Horde Windows agents compile Unreal Engine from source and mount their workspace over iSCSI. The stock Amazon `Windows_Server-2022` AMI has **neither** the C++ build toolchain **nor** the iSCSI initiator. The Packer template at [`assets/packer/build-agents/windows-horde`](../../assets/packer/build-agents/windows-horde) bakes them in:

- **VS2022 Build Tools + MSVC VC 14.38 + WDK/PDBCOPY** (Unreal from-source builds)
- **.NET 6 runtime** (matches the Horde module's `agent_dotnet_runtime_version` default so the module's first-boot install is a no-op) **and .NET 8 SDK** (UE 5.5 `AutomationTool`)
- **p4** (Perforce CLI) and **awscli**
- **MSiSCSI initiator (Automatic) + MPIO + MSDSM iSCSI claim** for the iSCSI/NTFS thin-clone workspace pipeline

An in-build `validate_image.ps1` **fails the build** unless `cl.exe`/MSVC VC14.38 + `vcvars`, `MSiSCSI` (Automatic), and MPIO are all present, so a published AMI is never half-baked.

### Prerequisites for the build

- [Packer](https://developer.hashicorp.com/packer/install) installed on the machine that runs the build.
- AWS credentials for the target account/region.
- A **VPC + subnet with outbound internet** (an Internet Gateway for a public subnet, or a NAT Gateway for a private subnet). The temporary Windows build instance uses Chocolatey to install the toolchain, so it must be able to reach the internet **outbound**.
- **A host/network that can reach the temporary build instance over WinRM (5986).** The template is **private by default** (`associate_public_ip_address = false`, `ssh_interface = "private_ip"`), which means **Packer must run from a host that can route to the build instance's private IP** — i.e. run Packer from inside the same VPC (a bastion/CI runner in the VPC), or from a network peered/VPN-connected to it.

  > **WinRM reachability caveat.** If you run Packer from a workstation that is *not* on the build instance's network (e.g. a corporate laptop whose egress blocks WinRM, or any host outside the VPC), the private-IP build cannot connect and will stall at "Waiting for WinRM". In that case either run Packer from inside the VPC, or flip to a public-IP build (`associate_public_ip_address = true`, `ssh_interface = "public_ip"`) **and** supply a `security_group_id` whose WinRM (5986) ingress is scoped to **your own /32** — never `0.0.0.0/0`.

### Build command

From the template directory, initialize the plugins and run the build with the required variables:

```bash
cd assets/packer/build-agents/windows-horde

packer init .

packer build \
  -var 'region=us-east-1' \
  -var 'vpc_id=vpc-xxxxxxxx' \
  -var 'subnet_id=subnet-xxxxxxxx' \
  -var 'public_key=ssh-ed25519 AAAA...your-agent-public-key' \
  .
```

- `region` — the build region (must match where you deploy this sample).
- `vpc_id` / `subnet_id` — a VPC and subnet with outbound internet (see prerequisites). Use a **private** subnet with NAT egress to keep the build instance off the public internet (recommended).
- `public_key` — the SSH **public** key that is baked into the AMI's `authorized_keys` so the Horde orchestration service can reach the agent. Generate a keypair (`ssh-keygen -t ed25519 -f horde_agent_key`) and pass the contents of `horde_agent_key.pub`.

The template defaults to a private-by-default build (`associate_public_ip_address = false`, `ssh_interface = "private_ip"`). If you must build over the public internet, add `-var 'associate_public_ip_address=true' -var 'ssh_interface=public_ip' -var 'security_group_id=sg-xxxxxxxx'` where the SG scopes WinRM (5986) to your `/32`. See [`example.pkrvars.hcl`](../../assets/packer/build-agents/windows-horde/example.pkrvars.hcl) to drive these from a `-var-file` instead of `-var` flags.

On success Packer prints the new AMI ID and registers it named `windows-horde-build-agent-<timestamp>`.

### How this sample consumes the AMI

The AMI is wired up automatically in [`main.tf`](main.tf) via `data.aws_ami.horde_build_agent`. You have two options:

- **Auto-lookup (default, keeps the sample generic).** Leave `build_agent_ami_id` unset (`null`). The sample looks up the newest **self-owned** AMI whose name matches `build_agent_ami_name_prefix` (default `windows-horde-build-agent-*`, which matches the Packer template's `ami_prefix`). No hardcoded AMI ID ends up in your config.
- **Pin an explicit AMI.** Set `build_agent_ami_id = "ami-xxxxxxxx"` in `terraform.tfvars` to pin a specific image; it takes precedence over the name-prefix lookup.

Because this is a prerequisite, **build the AMI first**, then run `terraform apply`. If no matching AMI exists and `build_agent_ami_id` is unset, the `data.aws_ami` lookup fails at plan time.

## Deployment

1. Copy the example variables file and fill in the required values:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Set the required variables in `terraform.tfvars`:

   - `route53_private_zone_name` — private hosted zone for internal service discovery (e.g. `studio.internal`).
   - `route53_public_hosted_zone_name` — your existing public hosted zone (e.g. `example.com`).
   - `certificate_domain` — the public FQDN for the Horde HTTPS endpoint, under the public zone (e.g. `horde.example.com`).
   - `perforce_stream` — the Perforce stream to sync into the FSxN source volume (e.g. `//YourGame/main`).
   - `horde_p4_credentials_secret_arn` — ARN of the pre-created Secrets Manager secret (`{"username":"svc-horde","password":"..."}`) for the Horde P4 user (required when deploying the bundled Perforce; see Prerequisites).

   Optional variables (Perforce endpoint, FSxN sizing, agent instance types and counts, Horde image) are documented with defaults in `terraform.tfvars.example`.

3. Initialize, review, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

Deployment provisions a VPC, FSxN file system, ECS-based Horde server, Perforce server, and agent launch templates, so allow roughly 20–30 minutes for the first apply (FSxN and the load balancers are the slowest resources).

The Horde external ALB ingress is locked to the **deployer's public IP as a `/32`** (discovered at plan time via `https://checkip.amazonaws.com`). There is no public or unauthenticated access, and there are no `0.0.0.0/0` ingress rules anywhere in this sample.

## Postdeployment

Terraform emits the following outputs (see `outputs.tf`):

- `horde_server_url` — the browser URL for the Horde UI (HTTPS, external ALB). Reachable only from the deployer `/32`.
- `perforce_endpoint` — the `P4PORT` (`ssl:<host>:1666`) for P4 client configuration.
- `fsxn_iscsi_portals` — comma-separated SVM iSCSI portal addresses (pass as `-set:IscsiPortals`; connect exactly one unless MPIO is installed).
- `fsxn_workspace_lun_path` — ONTAP path of the workspace LUN that hosts attach over iSCSI (the LUN carries NTFS).
- `fsxn_management_endpoint` / `fsxn_svm_management_endpoint` — ONTAP REST API targets for the BuildGraph tasks.
- `sync_agent_launch_template_id` / `build_agent_launch_template_id` — launch template IDs for the two agent pools.
- `agent_instance_role_name` — the IAM role attached to agent instances (has the secrets-read policy).
- `horde_p4_credentials_secret_arn` — echoes the pre-created Horde P4 username/password secret ARN you passed in via `horde_p4_credentials_secret_arn` (JSON, sensitive). This sample does not create the secret.
- `fsxn_password_secret_arn` — the FSxN `fsxadmin` password secret (sensitive).

### Configure the Perforce `svc-horde` user (required)

Horde authenticates to Perforce as `svc-horde` (the `perforceClusters` credentials in
`globals.json`, sourced from the pre-created secret), but **Terraform cannot provision that user
inside p4d**. After the P4 server is up you must complete the following one-time manual steps on
the server, in order, so the Horde stream poller can log in and read the stream. These commands
assume a Perforce super user; on the bundled SDP server, run `p4` after sourcing `p4_vars` for the
instance.

#### 1. Create the `svc-horde` user

`svc-horde` must exist as a Perforce user. It can be a standard user, but a `service`-type user is
preferred for least privilege. Skip this step if your deployment already auto-created the user.

```bash
# Idempotent create/edit; set Type: service in the spec for least privilege
p4 -u <super> user -f -o svc-horde | \
  sed 's/^Type:.*/Type:\tservice/' | \
  p4 -u <super> user -f -i
```

#### 2. Set the password to match the pre-created secret

The secret you pre-created (and passed via `horde_p4_credentials_secret_arn`) holds the **real
password you chose** for `svc-horde`. Terraform cannot set that password on the P4 user itself.
Set the user's password **on the server** to match the value already in the secret, or Horde will
not be able to authenticate to Perforce:

```bash
# Confirm the password already stored in your pre-created secret
aws secretsmanager get-secret-value --secret-id <horde_p4_credentials_secret_arn>

# On the P4 server, set the svc-horde user's password to that value
p4 -u <super> passwd svc-horde
```

Rotating one side without the other breaks Horde's Perforce connection.

#### 3. Grant protections on the stream depot

`svc-horde` must be authorized in the protections table (`p4 protect`) to read/write the stream
depot the poller monitors. Add a line matching this pattern (using your depot in place of the
generic `//YourGame/...` placeholder):

```
write user svc-horde * //YourGame/...
```

`p4 protect` is **order-sensitive**: later lines override earlier ones for overlapping paths, so
place this grant where it will not be overridden by a subsequent exclusionary line (e.g.
`list user * -//YourGame/...`). Without this grant the Horde poller fails and the server logs:

```
Access for user 'svc-horde' has not been enabled by 'p4 protect'
```

`super` is **not** required for the poller — the `write ... //YourGame/...` line is exactly what
grants the stream access it needs. Keep it least-privilege.

#### 4. Add `svc-horde` to service-user groups

Add `svc-horde` to a group with an `unlimited` (or long) `Timeout` so its login ticket does not
expire and interrupt polling. Perforce service accounts are also commonly added to a dedicated
service-users group. Use the idempotent `p4 group -o` / `p4 group -i` edit pattern:

```bash
# Grant an unlimited ticket timeout (create the group if it doesn't exist)
p4 -u <super> group -o unlimited_timeout | \
  sed 's/^Timeout:.*/Timeout:\tunlimited/' | \
  p4 -u <super> group -i

# Add svc-horde to the group's Users list, then re-submit
p4 -u <super> group -o unlimited_timeout   # add "\tsvc-horde" under Users:, save
# ...or scripted:
p4 -u <super> group -o unlimited_timeout | \
  awk '/^Users:/{print; print "\tsvc-horde"; next} {print}' | \
  p4 -u <super> group -i
```

Group membership only affects the ticket timeout — it does **not** grant depot access; the
protections line from step 3 does that.

#### These are manual, one-time steps

Like the Packer AMI build, these are **manual, one-time** steps — Terraform does not perform them.
They persist across normal server restarts, and on SDP servers all of these edits (user, protect,
group specs) are journaled and survive restarts. You only need to redo them if the P4 database is
ever **rebuilt from scratch** without a checkpoint/journal restore.

### Run the pipelines from the Horde UI

Open `horde_server_url` in a browser (from the deployer machine). The `globals.json` config defines a project (`Game Project`) with a stream and two templates:

- **Hydration Pipeline** — runs on a 60-minute schedule (`patterns: [{ interval: 60 }]`). It syncs the stream onto the source FSxN volume and snapshots it. You can also trigger it manually to seed the first snapshot.
- **Build Pipeline** — on-demand. Trigger it from the Horde UI once a snapshot exists; it clones the latest snapshot, syncs incrementally, compiles, and cleans up.

## Security

- **No `0.0.0.0/0` ingress anywhere.** Every ingress rule is scoped to a single-IP `/32`, a referenced security group, or a private VPC CIDR (enforced as a hard invariant in `security.tf`).
- **External ALB locked to the deployer `/32`.** Both the HTTPS listener (443) and the HTTP→HTTPS redirect (80) accept traffic only from `local.my_ip_cidr`.
- **No OIDC auth configured yet.** The Horde module's `auth_method` is intentionally left unset in this sample, so **the `/32` lock is the only access gate** on the Horde UI. Configure OIDC (or another Horde auth method) before widening ALB access beyond your own IP.
- **Internal traffic stays private.** Horde ECS tasks, Perforce, and agents run in private subnets; FSxN accepts iSCSI (3260) and ONTAP-REST only from the agent security group; P4 (1666) is reachable only from the agent SG and the deployer `/32`.

## Operational requirements learned from running this live

The FlexClone premise holds up: measured against a **49.55 GB / 268,730-file** UE 5.7
stream, snapshot took **80 ms**, the FlexClone **1.2 s**, and the mount **31 ms**, with two
~45 GiB workspace volumes occupying **35.3 GiB** physical. But several things must be
right or the pipeline either silently loses its benefit or does not work at all.

### 1. The incremental sync needs `p4 flush` — this is not optional

`p4 sync` is incremental only relative to the **client's have-list**, and the build
agent's workspace is a fresh client. The files are on the clone, but the server has no
record of that, so a bare `p4 sync` **re-transfers the entire stream** — the FlexClone
completes in a second and then you pay the full sync anyway.

`BuildPipeline.xml` therefore runs `p4 flush <stream>/...@$(SnapshotChangelist)` first,
which writes the have-list **without transferring content** (measured: 3 s on Linux, 6 s
on Windows). This is why snapshots must be named `cl-{N}` per ADR-003 and why
`SnapshotChangelist` must be passed per job — flush is metadata-only and trusts you, so
pointing it at the wrong changelist leaves the workspace silently disagreeing with the
server about what is on disk.

Keep the hydrate schedule frequent: at a 10-changelist gap the following `sync` spent
**26 s** walking the diff, versus ~1 s when the snapshot was at head.

### 2. The data path is iSCSI/NTFS, not NFS — and that is why UBA works

ADR-002 chose NFSv3 and rejected iSCSI on throughput grounds. Running the pipeline
showed that reasoning was incomplete: **throughput was never the binding
constraint — Windows filesystem semantics were.** On a Windows NFSv3 mount, four
separate UE subsystems fail:

| Component | Failure on Windows NFSv3 |
|---|---|
| **UBA** (Unreal Build Accelerator) | Detours file I/O and calls `NtQueryInformationFile` on every input; the NFS redirector answers `0xc000000d`. Measured **628 failures, all on `Engine/Source/*`** — i.e. exactly the files that must live on the clone. UBA cannot be enabled at all. |
| **DDC** | mmap'd cache writes fail or corrupt |
| **Shader library** | write failures during cook |
| **Stager** | `SafeCopyFile` → `SetFileTime` fails and **retries forever**, so the job *hangs* instead of erroring |

Each was only workaroundable by moving that write to local NTFS, which split the
project across three locations and still left UBA off — and a build farm without a
build accelerator is not the thing being demonstrated.

**A LUN presents real NTFS, so all four work and UBA stays enabled.** It is also
~40% faster to hydrate (measured on a 49.55 GB seed: **9m30s vs 15m33s**) because
block I/O skips per-file metadata round-trips.

Note what this does *not* cost: iSCSI authorises by initiator IQN (igroups), not
by directory identity, so you get NTFS semantics **without** the AD/CIFS
dependency that SMB would impose. That is the trade-off ADR-002 assumed it had to
make, and it does not exist.

### 3. NTFS is not a shared filesystem — hence two igroups

This is the one constraint SAN introduces, and it is a correctness boundary rather
than a style preference. **A LUN has exactly one legitimate writer.**

| igroup | Members | Holds |
|---|---|---|
| `horde_san_hydrator` | **exactly one host** | the source LUN |
| `horde_san_agents` | all build agents | per-job clone LUNs |

The shared igroup is safe because each clone LUN is used by exactly one job on one
agent, so build agents self-register into it at job time. The source LUN is
different: `hydrate-source-lun.ps1` registers its IQN with `-SingleHost` and
**fails the run** if that igroup already holds a different initiator, rather than
quietly becoming a second writer on one filesystem. Mapping the source LUN to the
shared igroup would let two hosts corrupt one volume.

Two consequences worth internalising:

- **The hydrator is Windows now** (`SyncPool` condition changed from
  `OSFamily == 'Linux'` to `'Windows'`), because the LUN carries NTFS. The Linux
  Ansible playbook that fstab-mounted the NFS volume is gone.
- **Connect exactly ONE iSCSI portal** unless the Windows MPIO feature is
  installed. Two portals without MPIO make Windows enumerate a single LUN as two
  disks — its own corruption trap. `Connect-SanPortal` enforces this.

### 3a. Flush the NTFS write cache before every snapshot

An ONTAP snapshot captures blocks as the array sees them, so anything still in the
Windows write cache is simply **absent** from the snapshot. You get a
crash-consistent image that may mount and then fail `chkdsk`, or silently lose the
tail of the `p4 sync`. `New-OntapSnapshot -FlushDriveLetter` issues the
`Write-VolumeCache`; do not remove it.

### 4. Clone teardown must not rely on a BuildGraph node

`RunLate="true"` is **not** a BuildGraph `<Node>` attribute, and the semantics it was
reaching for do not exist: a node ordered after a **failed** node is *Skipped*. So the
`Cleanup Clone` node is a success-only fast path. Guaranteed teardown is registered as a
**Horde lease-end hook** (`UE_HORDE_CLEANUP` → `buildgraph/teardown-clone.ps1`), which
runs regardless of outcome.

Neither path survives a **hard Spot reclaim**, since both run *on the agent*. If you run
agents on Spot — which is the point of making hydration cheap — add an **off-agent
reaper** on a schedule that deletes `build_*` clones whose Horde job is no longer
running. A leaked clone pins its parent snapshot, which then makes snapshot rotation
fail too.

### 5. ONTAP volume names reject hyphens

`build-{jobId}` fails with an opaque HTTP 400. Use `build_{jobid}`, lowercased. (ONTAP:
start with a letter or `_`, then letters/digits/`_`, ≤203 chars.)

## Still to confirm when you deploy

1. **Unreal compile arguments.** The `Compile` node calls `<drive>:\Engine\Build\BatchFiles\Build.bat` with `UETarget`/`UEPlatform`/`UEConfiguration`/`UEProject`. For a real project build set `UEProject` to the `.uproject` path on the mounted clone and confirm the BatchFiles path and target names against your engine. Note that Horde invokes BuildGraph via `<workspace>/Engine/Build/BatchFiles/RunUAT.bat`, so **the engine must be present in the stream**.
2. **Horde `globals.json` schema.** The pool conditions (`OSFamily == 'Linux'` / `'Windows'`) casing and the legacy top-level (version 1) vs. newer nested schema may need adjustment for your deployed Horde server version.
3. **`-Script` depot paths.** `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` resolve against the stream root only once the `buildgraph/` files are submitted to the depot under `Build/`. Confirm the paths resolve after submitting.
4. **Narrow the orchestration workspace.** The agent that only parses the BuildGraph XML still syncs the whole stream — 9 minutes of a 20-minute job in our runs. A workspace-level `view` is **silently ignored** by Horde's Perforce materializer; use a Perforce **virtual stream** containing just the bootstrap slice and point the workspace's `stream` at it.

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
<!-- This block is auto-generated by the repo's `terraform-docs` pre-commit hook. Do not edit by hand; run the hook to populate the Requirements / Providers / Modules / Resources / Inputs / Outputs tables. -->
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
