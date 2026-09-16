# Unreal Horde Build Pipeline

This sample deploys an [Unreal Engine Horde](https://dev.epicgames.com/documentation/en-us/unreal-engine/horde) build farm that compiles from a Perforce stream using [Amazon FSx for NetApp ONTAP](https://aws.amazon.com/fsx/netapp-ontap/) with a thin-clone workspace pattern. Instead of every build agent running a full `p4 sync` from scratch, the pipeline keeps one persistent source workspace warm and hands each build an instant, copy-on-write clone of it.

The core idea has two moving parts. A **Hydrator** (Sync) agent periodically syncs a persistent FSxN **LUN** from a Perforce stream and snapshots it as `cl-<changelist>`. When a build is requested, a **Build Agent** creates an instant [FlexClone](https://docs.netapp.com/us-en/ontap/concepts/flexclone-volumes-files-luns-concept.html) of that snapshot, presents the clone's LUN to itself over **iSCSI as real NTFS**, transplants the Perforce have-list with `p4 flush` (metadata-only), syncs only the delta, compiles, and tears the clone down. The clone + LUN map + iSCSI attach + `p4 flush` step is fast because it moves no file data — on the author's reference workspace (a ~49.55 GB / 268,730-file UE 5.7 stream) the attach script measured a ~9.7 s total versus ~8m23s for a cold `p4 sync` (see `attach-clone-lun.ps1`). Treat that as one measured example, not a guaranteed figure: it scales with workspace size, instance type, and how far the snapshot lags head. What it replaces is the per-build *workspace* hydration — the sample then **compiles `UnrealEditor` from source** off the clone (no cook, package, or upload), with UBA enabled, so any end-to-end wall-clock or cost you see quoted elsewhere reflects the author's rig and stream, not a promise of the shipped sample.

The pipeline compiles `UnrealEditor` from source off the FlexClone LUN with **UBA (Unreal Build Accelerator) enabled**. The end-to-end path is: hydrate a Perforce stream → ONTAP snapshot `cl-<N>` → FlexClone → iSCSI mount as `W:` (real NTFS) → `p4 flush` (metadata-only) → **compile `UnrealEditor` from source off the clone LUN**. It targets a source-available UE project such as Epic's **Lyra** sample (a real C++ project with `Source/` and `Modules[]`).

**Both agent pools are Windows:** the workspace is delivered to agents as an iSCSI LUN formatted NTFS, and Windows is required to read and write it. (For why iSCSI/NTFS was chosen as the data path, see the [operational deep-dive appendix](#appendix-operational-deep-dive-why-the-pipeline-is-built-this-way).)

## Big picture / what you're signing up for

This is a **Terraform sample plus several manual operator steps** — it is **not** a one-shot `terraform apply`. Terraform stands up the infrastructure, but seeding the depot, configuring the Perforce service user, and approving agent enrollment are manual operations the sample does not automate. Budget for both parts:

> **Scope: single stream.** This sample hydrates a **single** Perforce stream into one source volume/LUN. Do **not** point a second stream at the same source volume: a subsequent `p4 sync` does not remove the earlier stream's files, so they persist on the NTFS volume and get snapshotted and cloned into every build (cross-stream contamination). Running more than one stream is out of scope for this sample — see [appendix §12](#12-single-source-stream-per-stream-source-lun).

- **Part 1 — stand up the infrastructure.** Build the Windows build-agent AMI with Packer, then `terraform apply`.
- **Part 2 — seed the depot and run your first build.** Configure the Perforce `svc-horde` user, seed the depot with a source-available project + engine, submit the BuildGraph scripts, approve Horde agent enrollment, then trigger the hydration and build pipelines.

### Checklist (mirrors the [end-to-end runbook](#end-to-end-runbook))

| # | Step | Type | Time hint |
|---|---|---|---|
| 1 | [Build the Windows build-agent AMI](#1-build-the-windows-build-agent-ami) | [Manual] | ~30–45 min (Packer build) |
| 2 | [Deploy with Terraform](#2-deploy-with-terraform) | [Terraform] | ~20–30 min (first apply; FSxN + ALBs are slowest) |
| 3 | [Configure the `svc-horde` P4 user](#3-configure-the-svc-horde-p4-user) | [Manual] | minutes |
| 4a | [Acquire the engine and project](#acquire-the-engine-and-project) | [Manual] | large/slow — clone engine + project, fetch dependencies |
| 4 | [Seed the Perforce depot (project + engine)](#4-seed-the-perforce-depot-project--engine) | [Manual] | large/slow — depot seed of engine + project |
| 5 | [Submit the BuildGraph scripts under `Build/`](#5-submit-the-buildgraph-scripts-to-the-depot-under-build) | [Manual] | minutes |
| 6 | [Make Horde aware of the stream / project](#6-make-horde-aware-of-the-stream--project) | [Manual] | minutes |
| 7 | [Approve agent enrollment (one pool per agent)](#7-approve-agent-enrollment-assign-each-agent-to-exactly-one-pool) | [Manual] | minutes |
| 8 | [Trigger the Hydration Pipeline (first snapshot)](#8-trigger-the-hydration-pipeline-to-create-the-first-snapshot) | [Manual] | one hydrate cycle |
| 9 | [Trigger the Build Pipeline (per-job arguments)](#9-trigger-the-build-pipeline-per-job-arguments) | [Manual] | one build |

Steps 1–2 stand up the infrastructure; steps 3–9 seed the depot and run the first build. The [runbook](#end-to-end-runbook) is the authoritative "what to do" path; the [appendix](#appendix-operational-deep-dive-why-the-pipeline-is-built-this-way) explains "why the pipeline is built this way".

## Architecture

The sample composes existing CGD Toolkit modules (`modules/perforce`, `modules/unreal/horde`) with sample-owned networking, DNS, storage, and security wiring.

- **VPC** — a 3-tier layout across 2 AZs: public subnets (ALBs / NAT), private application subnets (Horde ECS tasks, Perforce, agents), and private service subnets (FSxN).
- **FSx for NetApp ONTAP** — an iSCSI/SAN SVM (no CIFS/AD) with a persistent source volume `p4_workspace` acting as a **container for a thin LUN** (`/vol/p4_workspace/workspace`). Terraform creates the file system, SVM and container volume; the LUN, igroups, LUN maps, snapshots and per-build FlexClones are all runtime operations via the ONTAP REST API, because the AWS provider cannot create them.
- **Horde server** — runs on ECS behind an external HTTPS ALB (browser access) and an internal ALB (agent enrollment / in-VPC traffic). Config is rendered from `config/horde/globals.json.tpl` and passed inline to the module.
- **Hydrator (Sync) Agent pool** — **Windows Server 2022** in the Horde pool `SyncPool`, `min = max = 1`. Windows because the source LUN carries NTFS, and exactly one because NTFS has exactly one legitimate writer (enforced by a single-host igroup, not merely documented — see [appendix §3](#3-ntfs-is-not-a-shared-filesystem--hence-two-igroups)).
- **Build Agent pool** — Windows Server 2022 agents in the Horde pool `BuildPool`. Scales from 0 to `build_agent_max_count`. Each job gets its own clone LUN, so these agents share one igroup safely.
- **Perforce** — the bundled `modules/perforce` P4 Server (private subnet, commit server) is deployed by default. Set `existing_perforce_server_endpoint` to wire the agents to a server you already run and skip the bundled module.
- **Route53** — a private hosted zone (created by this sample) for internal service discovery, plus records in your existing public hosted zone for the Horde HTTPS endpoint.
- **ACM certificate** — DNS-validated against your public hosted zone for the Horde external ALB HTTPS listener.

Three BuildGraph pipelines drive the workflow, and their agent/node names are coupled to `config/horde/globals.json.tpl`:

- `buildgraph/HydratePipeline.xml` — agent `SyncAgent`, node `Sync And Snapshot`, run by the `hydrate` template on `SyncPool`. After each snapshot it prunes `cl-<N>` snapshots beyond `fsxn_snapshot_retention` — see [appendix §3b](#3b-pipeline-snapshots-are-pruned-and-fsxs-default-snapshot-policy-is-off).
- `buildgraph/ReaperPipeline.xml` — agent `SyncAgent`, node `Reap Orphans`, run by the scheduled `reap` template on `SyncPool`; collects clone volumes and per-job Perforce clients that a hard Spot reclaim left behind (dry run by default) — see [appendix §4](#4-clone-teardown-must-not-rely-on-a-buildgraph-node).
- `buildgraph/BuildPipeline.xml` — agent `BuildAgent`, a single merged `Compile` node (`p4 login` → clone → iSCSI mount `W:` → per-build P4 client → `p4 flush` → clear read-only → `Build.bat`), run by the `build` template on `BuildPool`. The node logs in to Perforce first: a fresh agent has no ticket, so the login mints one that the later `p4 flush` / `p4 sync` reuse (the agent reads the JSON credentials secret supplied via `horde_p4_credentials_secret_arn` and logs in per job). The clone/mount/flush/compile steps are **one node** — see [appendix §9](#9-clone--mount--flush--compile-must-be-one-buildgraph-node). Guaranteed teardown is a Horde `UE_HORDE_CLEANUP` lease hook — see [appendix §4](#4-clone-teardown-must-not-rely-on-a-buildgraph-node).

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
   single "Compile" node            --> p4 login        (mint ticket for this job)
   (clone+mount+flush+compile       --> p4 flush @<N>   (have-list, no transfer)
    in ONE process)                 --> p4 sync         (delta only)
                                    --> clear read-only, Build.bat with UBA ENABLED
   + UE_HORDE_CLEANUP lease hook    --> offline disk, unmap LUN, delete clone

   Horde server (ECS) -- external HTTPS ALB (deployer /32) --> browser UI
                      -- internal ALB --------------------> agent enrollment
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) and valid AWS credentials for the target account.
- An **existing Route53 public hosted zone** (required). The ACM certificate DNS validation records and the public Horde record are created in this zone. This sample does not create the public zone for you.
- **Epic Games GitHub access — one PAT, two scopes (required for the defaults).** Your GitHub account must be accepted into the Epic Games organization. Create one Personal Access Token (classic) with `read:packages` (pulls the default Horde server image during `terraform apply`) and `repo` (clones `EpicGames/UnrealEngine` when you seed the depot). Store it in a Secrets Manager secret and pass it via `github_credentials_secret_arn`. The secret must be JSON of the form `{"username": "<github-username>", "password": "<PAT>"}` — the ECS `repositoryCredentials` format; a plain-text token is not accepted for the image pull. If either step fails with a 401/403, check the corresponding scope: missing `read:packages` shows up as an ECS image-pull error at apply time; missing `repo` as a clone failure later, at seed time.
- **A pre-created Secrets Manager secret for the Horde P4 user (required when deploying the bundled Perforce).** Create a Secrets Manager secret shaped `{"username":"svc-horde","password":"..."}` and pass its ARN via the `horde_p4_credentials_secret_arn` variable. This **single** secret is used both by the Horde server (to authenticate to Perforce) **and** by the sync/build agents: the agents read it at job time, parse the JSON, and pipe the password to `p4 login` to mint a **login ticket** so `p4 flush` / `p4 sync` authenticate on a fresh host (the pipeline logs in per job; leave the agent host's existing ticket in place to skip this). There is no separate plain-text password secret. This sample does **not** create the secret for you — pre-create it so its ARN is known at plan time, since the Horde module gates its Secrets Manager read policy on a `count` that cannot resolve an ARN created in the same apply. (If you set `existing_perforce_server_endpoint` to use your own Perforce server, provide the secret for that server's Horde service account instead.) The password value stored here must match the password set on the P4 user in [runbook step 3](#3-configure-the-svc-horde-p4-user); see [appendix §10](#10-the-svc-horde-password-must-match-on-both-sides).
- **No custom BuildGraph task compilation is required.** The SAN pipelines drive ONTAP and the Windows iSCSI initiator from PowerShell (`buildgraph/OntapSan.psm1` plus the `buildgraph/*.ps1` scripts), so you do **not** need to compile the C# tasks in `assets/buildgraph/tasks` into your `AutomationTool`. This is deliberate: LUN mapping/unmapping does not exist in those tasks, and teardown ordering (offline disk → unmap → delete volume) is a correctness requirement they cannot express. It also means the pipeline can be tested without a UAT build.
- **BuildGraph scripts submitted to the depot.** The `buildgraph/*.xml` files **and** the supporting `*.ps1` scripts must be submitted to your Perforce depot under `Build/` so the `-Script=Build/...` paths in `globals.json` resolve against the stream root. See [runbook step 5](#5-submit-the-buildgraph-scripts-to-the-depot-under-build).

---

# Part 1 — stand up the infrastructure

## Build the Windows build-agent AMI (manual prerequisite)

This is a **one-time operator step you run before `terraform apply`.** The Horde Windows agents compile Unreal Engine from source and mount their workspace over iSCSI, and the stock Amazon `Windows_Server-2022` AMI has **neither** the C++ build toolchain **nor** the iSCSI initiator. Baking them into an image once (~30–45 minutes) is far cheaper than re-installing on every agent boot, so the sample does not automate it.

The Packer template at [`assets/packer/build-agents/windows-horde`](../../assets/packer/build-agents/windows-horde) bakes in the VS2022/MSVC toolchain, the .NET runtimes, `p4`/`awscli`, and the MSiSCSI initiator + MPIO, and an in-build `validate_image.ps1` **fails the build** if the toolchain, iSCSI initiator or MPIO are missing, if MSDSM is not actually claiming iSCSI devices, or if the boot-time unique-IQN script does not produce an instance-id-derived IQN — so a published AMI is never half-baked. See that template's README and [`example.pkrvars.hcl`](../../assets/packer/build-agents/windows-horde/example.pkrvars.hcl) for the exhaustive component list and variable reference.

### Build command

> **Start from a clean checkout.** Run the Packer build (and the later Terraform steps) from a fresh checkout — a stale working tree can carry leftover `terraform.tfstate`, `terraform.tfvars`, or `.terraform/` that confuses a from-scratch deploy (see [Deployment](#deployment)).

At **Step 1 you do not yet have a VPC** — `terraform apply` (Step 2) is what creates it. So for a first deploy, build the AMI over the **public internet** with ingress locked to your **own workstation `/32`**, which is the default path below. The **private in-VPC build** (below) is the advanced path to switch to *once you already have a VPC with in-VPC routing* (a second AMI rebuild, a peered network, etc.).

```bash
cd assets/packer/build-agents/windows-horde

packer init .

# First-deploy default: public IP, WinRM (5986) locked to your workstation /32.
# Packer creates and deletes its own temporary security group — no pre-created SG needed.
packer build \
  -var 'region=us-east-1' \
  -var 'vpc_id=vpc-xxxxxxxx' \
  -var 'subnet_id=subnet-xxxxxxxx' \
  -var 'associate_public_ip_address=true' \
  -var 'ssh_interface=public_ip' \
  -var 'temporary_security_group_source_cidrs=["<your-public-ip>/32"]' \
  -var 'public_key=ssh-ed25519 AAAA...your-agent-public-key' \
  .
```

`region` must match where you deploy the sample; `subnet_id` must be a **public** subnet (with a route to an internet gateway) for the public-IP path, and any subnet you use needs outbound internet, since the build uses Chocolatey to install the toolchain; `public_key` is the SSH public key baked into the AMI so the Horde orchestration service can reach the agent. On success Packer prints the new AMI ID, registered as `windows-horde-build-agent-<timestamp>`.

> **Instance-type availability by AZ.** The build defaults to a large compute instance (e.g. `c6a.4xlarge`), and not every AZ carries it — `c6a.4xlarge` Windows is **not** available in `us-east-1e`, for example. If Packer fails to launch the builder with an unsupported-instance-type error, pick a supported AZ (in `us-east-1`, one of `us-east-1a/b/c/d/f`) via the `subnet_id`, or choose an instance type the AZ offers.
<!-- -->
> **Advanced: private in-VPC build.** Once you have a VPC, you can instead build on a **private** subnet with NAT egress (leave `associate_public_ip_address=false`, `ssh_interface="private_ip"` — the template's defaults). In that mode **Packer must run from a host that can route to the build instance's private IP** — i.e. from inside the same VPC (a bastion/CI runner), or a peered/VPN-connected network. Run it from a workstation that cannot reach that private IP and the build stalls at "Waiting for WinRM". The private path can use a pre-created `security_group_id` that scopes WinRM (5986) to the reachable network — never `0.0.0.0/0`.

### How this sample consumes the AMI

The AMI is wired up automatically in [`main.tf`](main.tf) via `data.aws_ami.horde_build_agent`:

- **Auto-lookup (default, keeps the sample generic).** Leave `build_agent_ami_id` unset (`null`). The sample looks up the newest **self-owned** AMI whose name matches `build_agent_ami_name_prefix` (default `windows-horde-build-agent-*`, which matches the Packer template's `ami_prefix`). No hardcoded AMI ID ends up in your config.
- **Pin an explicit AMI.** Set `build_agent_ami_id = "ami-xxxxxxxx"` in `terraform.tfvars` to pin a specific image; it takes precedence over the name-prefix lookup.

**Build the AMI first**, then `terraform apply` — if no matching AMI exists and `build_agent_ami_id` is unset, the `data.aws_ami` lookup fails at plan time.

## Deployment

> **Start from a clean checkout.** Deploy from a fresh checkout of this sample. A leftover working tree can carry stale `terraform.tfstate`, `terraform.tfvars`, or `.terraform/` from an earlier run and confuse a from-scratch deploy — wipe or re-clone before you begin.

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
   - `github_credentials_secret_arn` — ARN of the Secrets Manager secret holding your GitHub PAT (see [Prerequisites](#prerequisites)). Required for the default Horde image; omit only if you also override `horde_server_image` with an image you can pull without authentication.

   Optional variables (Perforce endpoint, FSxN sizing, agent instance types and counts, Horde image) are documented with defaults in `terraform.tfvars.example`.

3. Initialize, review, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

Deployment provisions a VPC, FSxN file system, ECS-based Horde server, Perforce server, and agent launch templates, so allow roughly 20–30 minutes for the first apply (FSxN and the load balancers are the slowest resources).

The Horde external ALB ingress is locked to the **deployer's public IP as a `/32`** (discovered at plan time via `https://checkip.amazonaws.com`). There is no public or unauthenticated access, and there are no `0.0.0.0/0` ingress rules anywhere in this sample.

> **Destroy → redeploy gotcha: the FSxN admin secret is soft-deleted.** When you `terraform destroy` and then re-apply, the re-apply collides with the FSxN `fsxadmin` password secret left over from the earlier deploy: Secrets Manager **soft-deletes** it with a recovery window, so the name is still taken and the new create fails ("scheduled for deletion"). Either force-delete the lingering secret before re-applying:
>
> ```bash
> aws secretsmanager delete-secret \
>   --secret-id <fsxn-fsxadmin-secret-name> \
>   --force-delete-without-recovery
> ```
>
> or set `recovery_window_in_days = 0` on the FSxN admin secret so a destroy purges it immediately.
<!-- -->
> **Runtime secret reads need IAM grants.** The agent login-ticket chain (in [runbook step 3.2](#32-set-the-password-to-match-the-pre-created-secret) / [appendix §1](#1-the-incremental-sync-needs-p4-flush--this-is-not-optional)) reads the P4 credentials on the host at runtime, so the **agent instance role** (`agent_instance_role_name`) must have `secretsmanager:GetSecretValue` on the Horde P4 credentials secret — `iam.tf` wires this grant from `horde_p4_credentials_secret_arn`, so verify it actually attaches. Likewise, if the P4 server instance reads a secret at runtime, its role needs the same grant. Without it the reads fail `AccessDenied` and the login-ticket chain breaks.

## Postdeployment

Terraform emits the following outputs (see `outputs.tf`):

- `horde_server_url` — the browser URL for the Horde UI (HTTPS, external ALB). Reachable only from the deployer `/32`.
- `perforce_endpoint` — the `P4PORT` (`ssl:<host>:1666`) for P4 client configuration.
- `fsxn_iscsi_portals` — comma-separated SVM iSCSI portal addresses (pass as `-set:IscsiPortals`; the scripts connect exactly one unless MPIO is installed **and** MSDSM is claiming iSCSI devices — see [appendix §3](#3-ntfs-is-not-a-shared-filesystem--hence-two-igroups)).
- `fsxn_workspace_lun_path` — ONTAP path of the workspace LUN that hosts attach over iSCSI (the LUN carries NTFS).

Obtain the two igroups with `terraform output <name>`; each feeds its pipeline as a `-set:` value (already wired via `globals.json`):

- `fsxn_hydrator_igroup` — the **single-host** igroup owning the source LUN, fed to the hydrate pipeline as `-set:HydratorIgroup`. Never add build agents to it — NTFS has exactly one legitimate writer.
- `fsxn_agent_igroup` — the shared igroup for per-job clone LUNs, fed to the build pipeline as `-set:AgentIgroup`. Safe to share because each clone is used by exactly one job on one agent.
- `fsxn_management_endpoint` / `fsxn_svm_management_endpoint` — ONTAP REST API targets for the BuildGraph tasks.
- `sync_agent_launch_template_id` / `build_agent_launch_template_id` — launch template IDs for the two agent pools.
- `agent_instance_role_name` — the IAM role attached to agent instances (has the secrets-read policy).
- `horde_p4_credentials_secret_arn` — echoes the pre-created Horde P4 username/password secret ARN you passed in (JSON, sensitive). This sample does not create the secret.
- `fsxn_password_secret_arn` — the FSxN `fsxadmin` password secret (sensitive).

Once the stack is up, continue with the [end-to-end runbook](#end-to-end-runbook) below.

---

# Part 2 — seed the depot and run your first build

## End-to-end runbook

This is the authoritative "what to do" path. Steps 3, 4, 6, 7, 8 and 9 are manual operations the sample does **not** automate. Do them in order. Each step links into the [operational deep-dive appendix](#appendix-operational-deep-dive-why-the-pipeline-is-built-this-way) for the "why".

### 1. Build the Windows build-agent AMI

One-time operator step, **before** `terraform apply`. See [Build the Windows build-agent AMI](#build-the-windows-build-agent-ami-manual-prerequisite).

### 2. Deploy with Terraform

See [Deployment](#deployment). Provisions the VPC, FSxN, ECS Horde server, Perforce, and the two agent launch templates. The external ALB is locked to the deployer `/32` — no `0.0.0.0/0` ingress anywhere.

### 3. Configure the `svc-horde` P4 user

Horde authenticates to Perforce as `svc-horde` (the `perforceClusters` credentials in `globals.json`, sourced from the pre-created secret), but **Terraform cannot provision that user inside p4d**. After the P4 server is up, complete these one-time manual steps on the server, in order, so the Horde stream poller can log in and read the stream.

These are **manual, one-time** steps — Terraform does not perform them. They persist across normal server restarts (on SDP servers all of these edits are journaled and survive restarts); you only need to redo them if the P4 database is ever **rebuilt from scratch** without a checkpoint/journal restore.

#### 3.0 Get a working super-user shell on the P4 server

Run every `p4` command in this step as a Perforce **super** user. On the bundled SDP server there are two things people get wrong here, so do exactly this:

1. **The super user is `super`, not `perforce`.** `perforce` is only the **OS account** that p4d runs as — it is not the Perforce super user. The `<super>` placeholder in the commands below is the Perforce user named `super`.
2. **Get the SDP environment and a real login shell.** SDP stores per-instance environment (P4PORT, P4USER, ticket/trust file locations) in `p4_vars`, and its ticket/trust files depend on `$HOME` being the `perforce` account's home. Use a **login shell** (`su -`), not `sudo -u`, or the ticket/trust files land in the wrong `$HOME` and login breaks:

   ```bash
   # Become the perforce OS account with a full login shell, then load the SDP env for instance 1
   sudo su - perforce
   source /p4/common/bin/p4_vars 1
   ```

3. **Get the `super` password.** The `super` password is **not** the `AdminPassword`/`cgd-p4-server-AdminPassword` secret — that value does **not** match the live super password. On SDP the real super credential is stored on the server in the base64-encoded file:

   ```bash
   # base64-encoded, no separate key — decode to get the super password
   base64 -d /p4/common/config/.p4passwd.p4_1.admin.enc
   ```

4. **Trust the SSL endpoint once.** Connecting to the explicit `ssl:<host>:1666` endpoint (rather than loopback) requires a one-time trust of the server fingerprint, or every `p4` command fails with "The authenticity of ... can't be established":

   ```bash
   p4 -p "$P4PORT" trust -y
   ```

5. **Log in as `super`:**

   ```bash
   p4 -u super login   # paste the password from step 3
   ```

Now run the sub-steps below as `super`.

#### 3.1 Create the `svc-horde` user (Type: `standard`)

`svc-horde` must exist as a Perforce user of **Type: `standard`**. Do **not** create it as a `service` user: p4d forbids service users from creating clients, opening changes, or submitting, so Horde job creation dies with HTTP 500 `Command not allowed for a service user` at `PerforceService.CreateClientAsync` — this blocks the entire pipeline.

Build the spec with an **explicit `Type:` line**. The tempting `p4 user -o | sed 's/^Type:.*/.../' | p4 user -i` one-liner is a silent trap: a brand-new user's spec has **no** `Type:` line for the `sed` to match, so it yields the default (`standard`) by accident on a new user, and p4d **refuses to change the type of an existing user** in place. So set the type explicitly, and if the user already exists as the wrong type, **delete and recreate** it:

```bash
# If svc-horde already exists as the wrong type, delete it first (p4d cannot convert type in place):
#   p4 -u super user -d -f svc-horde

# Create svc-horde as Type: standard, injecting an explicit Type: line into the spec:
p4 -u super user -f -o svc-horde | \
  awk 'BEGIN{t=0} /^Type:/{print "Type:\tstandard"; t=1; next} {print} END{if(!t) print "Type:\tstandard"}' | \
  p4 -u super user -f -i

# Verify:
p4 -u super user -o svc-horde | grep '^Type:'   # -> Type: standard
```

#### 3.2 Set the password to match the pre-created secret

Set the user's password **on the server** to match the value already in the pre-created secret. Rotating one side without the other breaks Horde's Perforce connection — see [appendix §10](#10-the-svc-horde-password-must-match-on-both-sides).

```bash
# Confirm the password already stored in your pre-created secret
aws secretsmanager get-secret-value --secret-id <horde_p4_credentials_secret_arn>

# On the P4 server, set the svc-horde user's password to that value
p4 -u super passwd svc-horde
```

> **Expired-password gotcha (`security=4`).** On a server running `security=4` with `dm.user.resetpassword=1` (the SDP default), an **admin-set** password is treated as **immediately expired**. `svc-horde` cannot authenticate until it changes its own password **once** — even changing it to the same value. Do a one-time self-change as `svc-horde` (old = new = the secret value) so the account can log in:
>
> ```bash
> # As svc-horde, change the password to itself once to clear the "expired" state.
> # p4 passwd prompts: Old password, then New password (twice) — enter the SAME value for all three.
> p4 -u svc-horde passwd
> ```
>
> Skip this and Horde's poller keeps failing to authenticate even though the password "matches".

#### 3.3 Grant protections on the stream depot

`svc-horde` must be authorized in the protections table (`p4 protect`) to read/write the stream depot the poller monitors. Add a line matching this pattern (using your depot in place of the generic `//YourGame/...` placeholder):

```text
write user svc-horde * //YourGame/...
```

`p4 protect` is **order-sensitive**: later lines override earlier ones for overlapping paths, so place this grant where it will not be overridden by a subsequent exclusionary line (e.g. `list user * -//YourGame/...`). Without this grant the Horde poller fails and the server logs `Access for user 'svc-horde' has not been enabled by 'p4 protect'`. `super` is **not** required for the poller — the `write ... //YourGame/...` line is exactly what grants the stream access it needs. Keep it least-privilege.

#### 3.4 Give `svc-horde` a long-lived login ticket

Add `svc-horde` to a group with an `unlimited` (or long) `Timeout` so its login ticket does not expire and interrupt polling. Group membership only affects the ticket timeout — it does **not** grant depot access; the protections line from step 3.3 does that.

```bash
# Grant an unlimited ticket timeout (create the group if it doesn't exist)
p4 -u super group -o unlimited_timeout | \
  sed 's/^Timeout:.*/Timeout:\tunlimited/' | \
  p4 -u super group -i

# Add svc-horde to the group's Users list, then re-submit
p4 -u super group -o unlimited_timeout | \
  awk '/^Users:/{print; print "\tsvc-horde"; next} {print}' | \
  p4 -u super group -i
```

### Acquire the engine and project

Before you can seed the depot, you need the engine and a source-available project **on a local disk**. This step is entirely manual and independent of this sample's infrastructure — do it on the same host you will seed from (see [seeding environment](#seeding-environment) below).

> **Skip this if you already have your own game and engine in Perforce.** The seed step and its helper are an **optional quick-start** for a demo/eval depot. If you already have your project and engine in Perforce (or your own seeding process), skip straight to [making Horde aware of the stream](#6-make-horde-aware-of-the-stream--project) — just make sure your depot ends in the [required layout](#required-end-state-stream-layout) below.

To assemble a demo/eval project (engine + Lyra):

1. **Clone the engine at your target tag.** Clone `EpicGames/UnrealEngine` at the engine tag you intend to build (e.g. `5.5.4-release`). This requires a GitHub account **accepted into the Epic Games organization** and a PAT with the **`repo`** scope (see [Prerequisites](#prerequisites)); a token missing `repo` (or an account not in the org) fails here with a clone **403**.

   ```bash
   git clone --branch 5.5.4-release https://github.com/EpicGames/UnrealEngine.git
   ```

2. **Fetch the engine's binary dependencies.** The Git repo does not carry the large binary dependencies — run the engine's setup script to fetch them via GitDependencies before you seed, or the engine tree is incomplete:

   ```bat
   cd UnrealEngine
   Setup.bat
   ```

3. **Get a project with C++ source.** The project **must** have a `Source/` tree and real `Modules[]` in its `.uproject` — a from-source compile has nothing to build otherwise. Epic's **Lyra** (from `EpicGames/UnrealEngine` at `Samples/Games/Lyra`, at the tag matching your engine) is a good fit. Note that **Lyra at the `5.5.x` tags is code-only** (`Source/` but no `Content/`, 0 `.uasset`) — that is **fine** for the from-source `LyraEditor` compile demo; you do not need Content. **Do not** pick a content-only sample (e.g. a prebuilt-DLL Launcher/Fab sample with no `Source/`): it cannot be compiled from source.

4. **Budget disk.** The engine tree alone is large (~34 GiB), and Setup.bat's dependencies push the checkout to ~64 GiB. Plan for **~512 GiB free** on the acquisition/seed host for the engine + project + working space + NTFS overhead (the stock agent AMI root is 256 GiB — too small; size the seed host up, see [seeding environment](#seeding-environment)).

### 4. Seed the Perforce depot (project + engine)

The depot must contain a **source-available** UE project **and** the matching engine before a build can compile anything. This is manual — the sample does not seed the depot. However you get there, the depot must end in the [required end-state layout](#required-end-state-stream-layout).

> **`scripts/seed-depot.ps1` is an OPTIONAL quick-start helper — not required.** It exists to get a demo/eval depot (engine + Lyra) set up fast. If you already have your own game and engine in Perforce, or your own seeding process, you can **skip the helper entirely** — as long as the depot ends up in the [required layout](#required-end-state-stream-layout) below (project in a stream subfolder, engine tree present, the `Build/` scripts submitted). Both paths must converge on that same end state.

**Using the helper.** From your seed host (see [seeding environment](#seeding-environment)), run [`scripts/seed-depot.ps1`](scripts/seed-depot.ps1) — see the script header for the full parameter reference. It creates the stream depot/stream if absent, submits the project under a subfolder, submits the Build scripts, provisions the engine, and verifies the layout. Supports `-WhatIf`. Key parameters and gotchas:

- **First-ever seed must use `-EnginePath` (submit a local tree).** The fast `-EngineDepotPath` option branches an engine that is **already in the depot** via `p4 populate` (lazy copy, no re-upload) — but on a truly fresh depot no engine exists yet, so the **first-ever** seed has to submit your local engine tree with `-EnginePath` (~34 GiB, slow). Use `-EngineDepotPath` only for **subsequent** streams, once an engine is present in the depot.
- **Run as a P4 user with depot-create rights.** Creating the stream depot/stream requires elevated rights — service/standard users without them cannot create depots. Run the seed as a P4 user that can create depots (e.g. the SDP `super` user), **or** pre-create the depot and stream yourself first and run the seed as a lesser user. (`svc-horde` from step 3 is a poller, not a depot creator.)
- **Large trees: `-SubmitBatchSize`.** A monolithic reconcile+submit stalls on a first-ever full engine seed (~285k files / ~64 GiB). Use `-SubmitBatchSize` to submit in chunks. The engine tree also contains files with Perforce metacharacters (`@ % # *`); the helper pre-scans and force-adds them (`p4 add -f`) and warns on any it cannot submit.

<a id="required-end-state-stream-layout"></a>
**Required end-state stream layout.** Both the helper path and a bring-your-own-depot path must converge on this layout — the project in a **subfolder** (never at the stream root — the [drive-root gotcha](#6-the-project-must-live-in-a-subfolder-not-at-the-drive-root)), the engine tree present ([engine-in-stream](#7-the-engine-must-be-present-in-the-stream--on-the-lun)), and the `Build/` scripts submitted ([step 5](#5-submit-the-buildgraph-scripts-to-the-depot-under-build)):

```text
//YourGame/main/
├── <Project>/            # the .uproject, Source/, Config/, Content/  (NEVER at the stream root)
│   ├── <Project>.uproject
│   ├── Source/           # C++ source — REQUIRED for a from-source compile
│   ├── Config/
│   └── Content/
├── Build/                # the buildgraph scripts (see step 5)
└── Engine/               # the full UE engine tree (Build.bat, BatchFiles, Source, ...)
```

**Use a project with C++ source.** The project **must** have `Source/` and real `Modules[]` in its `.uproject` — see [Acquire the engine and project](#acquire-the-engine-and-project) for how to get one (e.g. Epic's Lyra) and why content-only samples cannot be compiled from source.

<a id="seeding-environment"></a>
**Seeding environment.** This sample does **not** deploy a host to run the seed from — run the acquisition and seed from **any host you choose**: your local workstation, a CI runner, or an EC2 instance you provision yourself. Wherever you run it, that host must have:

- The Perforce CLI `p4` on `PATH`, and PowerShell (the helper is a `.ps1`).
- **Network reachability to the Perforce server's `P4PORT`.** The bundled P4 server is in a **private subnet**, so the host must be in the VPC or on a VPN/peered network that can reach it (e.g. an in-VPC EC2 instance, or your workstation over VPN).
- The engine + project tree + BuildGraph scripts available locally to submit.
- **~512 GiB of free disk** for the engine (~34 GiB) + dependencies + project + working space + NTFS overhead. The stock agent AMI root is 256 GiB — too small; if you reuse that AMI for the seed host, resize the root volume up.
- AWS CLI + credentials **only if** you pass the P4 credentials by Secrets Manager reference (the helper's `-P4CredentialsSecret`). If you pass the password directly, the AWS CLI is **not** required.

A convenient choice is an **in-VPC Windows workstation** in a **private** subnet, reachable via **SSM / Fleet Manager** with **no public ingress** (a security group with zero inbound rules — consistent with the no-`0.0.0.0/0` posture of this sample).

**Tearing the depot back down later.** If you used the helper (which creates a **stream depot**), `p4 depot -d <depot>` refuses with `location of existing streams` until the versioned stream spec is obliterated first — after deleting the stream's files/spec, run `p4 stream --obliterate -y //<depot>/<stream>` (Perforce 2019.1+), then delete the depot.

### 5. Submit the BuildGraph scripts to the depot under `Build/`

Submit all of these to `//YourGame/main/Build/` so the `-Script=Build/...` paths in `globals.json` resolve against the stream root. `scripts/seed-depot.ps1` does this for you via `-BuildScriptsPath`:

- `buildgraph/HydratePipeline.xml`
- `buildgraph/BuildPipeline.xml`
- `buildgraph/ReaperPipeline.xml`
- `buildgraph/OntapSan.psm1`
- the pipeline `*.ps1` scripts (`p4-login.ps1`, `create-build-client.ps1`, `attach-clone-lun.ps1`, `hydrate-source-lun.ps1`, `teardown-clone-lun.ps1` and `reap-orphans.ps1`)

The simplest way to stay complete is to submit the whole `buildgraph/` directory as `Build/`, which is what the helper does.

### 6. Make Horde aware of the stream / project

The project, stream, and the three templates (`hydrate`, `build`, `reap`) are delivered by `config/horde/globals.json.tpl`, which points them at `Build/HydratePipeline.xml`, `Build/BuildPipeline.xml` and `Build/ReaperPipeline.xml`. Changing streams or templates means editing `config/horde/globals.json.tpl` and redeploying (or applying the config to the live server).

Confirmed `globals.json` requirements for the live Horde **5.5** server (a **flat, top-level v1** schema):

- `agentTypes` mapping `Win64 → build-pool` and `AnyAgent → sync-pool`, plus `workspaceTypes`.
- A **`storage` block** (backends + namespaces for `horde-logs` and `horde-artifacts`). Without it, agent log uploads fail with **HTTP 500 `Namespace not found`** (see [Troubleshooting](#troubleshooting)).

### 7. Approve agent enrollment (assign each agent to exactly one pool)

Horde 5.5 does **not** auto-approve agents. New agents sit **pending** until an operator approves them — via the Horde UI, or `POST /api/v1/enrollment` (a `GET` on the same endpoint lists pending enrollments). Until you approve them, `SyncPool` and `BuildPool` have **no online agents** and jobs never lease. Note that `enable_new_agents_by_default` does **not** auto-approve enrollment — it only controls whether an agent is enabled *once approved*. See [appendix §11](#11-horde-55-does-not-auto-approve-agent-enrollment).

**Approve each agent into exactly its intended pool — do not assign an agent to both pools:**

- **Sync agent → `SyncPool` only.** The sync agent is the **single legitimate writer** of the source LUN (enforced by the single-host `horde_san_hydrator` igroup — see [appendix §3](#3-ntfs-is-not-a-shared-filesystem--hence-two-igroups)). If you also place it in (or the build agent in) the other pool, Horde can schedule a **hydrate on a build agent**, which the single-writer igroup guard refuses.
- **Build agents → `BuildPool` only.**

> **Manual step — trust the P4 SSL endpoint on each new agent host.** The Horde agent service runs as **LocalSystem**, whose P4 trust store has no fingerprint for the SSL `P4PORT`, so Horde's workspace-executor `p4 login` fails with "The authenticity of ... can't be established" **before** any pipeline script runs (`p4-login.ps1` cannot fix this — it runs too late). Run a one-time `p4 trust` **as the agent service account** on **each** new agent host. Because SSM Run Command executes as **SYSTEM** — the same account the agent runs as — you can push it via SSM Run Command:
>
> ```powershell
> p4 -p ssl:<p4d-host>:1666 trust -y
> ```
>
> Do this once per agent host after it boots and before it needs to run a job.

### 8. Trigger the Hydration Pipeline to create the first snapshot

Run the **Hydration Pipeline** from the Horde UI (or wait for the 60-minute schedule, `patterns: [{ interval: 60 }]`). It syncs the stream onto the source FSxN volume and creates the first snapshot named `cl-<N>`. Note the `<N>` — it is the changelist you pass to the build. Keep this schedule frequent to keep incremental syncs cheap — see [appendix §1](#1-the-incremental-sync-needs-p4-flush--this-is-not-optional).

> **The first hydrate formats the LUN it creates.** `hydrate-source-lun.ps1` creates the source LUN if it does not exist and, on that same run, initialises and formats it NTFS — a LUN that did not exist a moment ago cannot hold data, so this is safe and needs no flag. `-set:FormatIfRaw=true` exists only for a **raw** LUN that was provisioned **outside** the pipeline (symptom: `No usable partition on disk ...`). Never pass it in steady state; `Mount-SanLun` refuses to reformat a disk that is not RAW even if you do.
<!-- -->
> **Custom job `arguments` REPLACE the template defaults — pass the full list.** If you trigger the hydrate by posting custom `arguments` to `POST /api/v1/jobs`, those arguments **replace** the template's default argument list rather than appending to it, so omitting the defaults breaks the job with errors like `Missing -Script= parameter`. If you do pass an extra value such as `-set:FormatIfRaw=true`, include the **entire** argument list the template would otherwise supply (`-Script=Build/HydratePipeline.xml`, the target node, and the `-set:` values) **plus** your extra value. Triggering from the Horde UI keeps the defaults intact.

### 9. Trigger the Build Pipeline (per-job arguments)

Trigger the **Build Pipeline** on-demand once a snapshot exists. These arguments are **per run** and must be supplied each time — they are **not** baked into the config:

| Argument | Value | Notes |
|---|---|---|
| `SnapshotName` | `cl-<N>` | the snapshot from step 8 |
| `SnapshotChangelist` | `<N>` | the changelist number; `p4 flush` trusts this — wrong value silently desyncs the have-list ([appendix §1](#1-the-incremental-sync-needs-p4-flush--this-is-not-optional)) |
| `CloneVolumeName` | e.g. `build_1234` | lowercase alphanumeric/underscore, **no hyphens** ([appendix §5](#5-ontap-volume-names-reject-hyphens)) |
| `UEProject` | `<drive>:/<Project>/<Project>.uproject` | path on the mounted clone; **must be in a subfolder** ([appendix §6](#6-the-project-must-live-in-a-subfolder-not-at-the-drive-root)) |
| `UETarget` | the real editor target, e.g. `LyraEditor` | the actual target name — **not** just `Editor` (see [Troubleshooting](#troubleshooting)) |
| `UEPlatform` | `Win64` | |
| `UEConfiguration` | `Development` | |
| `ExtraUbtArgs` | `-UBA` | enables Unreal Build Accelerator ([appendix §2](#2-the-data-path-is-iscsintfs-not-nfs--and-that-is-why-uba-works)) |

Expect `BUILD SUCCESSFUL` compiling off the clone LUN. With `-UBA` the log shows `Using Unreal Build Accelerator executor` and a `UbaServer` listener.

> **Posting custom `arguments` replaces the template defaults.** As in the hydrate ([step 8](#8-trigger-the-hydration-pipeline-to-create-the-first-snapshot)): if you trigger the build via `POST /api/v1/jobs` with custom `arguments`, include the **full** template argument list (e.g. `-Script=Build/BuildPipeline.xml` and the target node) **plus** the per-run `-set:` values above, or the job fails with `Missing -Script=`. Triggering from the Horde UI keeps the defaults intact.
<!-- -->
> **Single-agent UBA runs local-only (by design).** With only one build agent online, UBA reports `No agents found matching requirements` and runs local-only — this is expected, not an error. Distributed UBA needs more than one eligible agent.

## Troubleshooting

Keyed to the exact error strings the pipeline can produce.

| Error / symptom | Cause | Fix |
|---|---|---|
| `Namespace 'horde-logs' not found` / HTTP 500 `StorageException` | The `storage` block is missing from `globals.json`, so agent log uploads have nowhere to go. | Add the `storage` block (backends + namespaces for `horde-logs` and `horde-artifacts`). See [runbook step 6](#6-make-horde-aware-of-the-stream--project). |
| `NullReferenceException ... SourceFileWorkingSet` (UBT) | The UE project is at the clone-LUN **drive root**; `ProjectDir.ParentDirectory` is `null`. | Put the project in a subfolder (`W:\<Project>\...`). See [appendix §6](#6-the-project-must-live-in-a-subfolder-not-at-the-drive-root). |
| Opaque **ONTAP HTTP 400** on clone create | The `CloneVolumeName` contains a hyphen, which ONTAP volume names reject. | Use `build_{jobid}`, lowercase, no hyphens. See [appendix §5](#5-ontap-volume-names-reject-hyphens). |
| `Access for user 'svc-horde' has not been enabled by 'p4 protect'` | `svc-horde` has no protections grant on the stream depot, so the poller can't read it. | Add the `write user svc-horde * //YourGame/...` line. See [runbook step 3.3](#33-grant-protections-on-the-stream-depot). |
| Agents show online but jobs never lease / pools empty | Agent enrollment is **not approved** (Horde 5.5 does not auto-approve). | Approve enrollment in the Horde UI. See [runbook step 7](#7-approve-agent-enrollment-assign-each-agent-to-exactly-one-pool) / [appendix §11](#11-horde-55-does-not-auto-approve-agent-enrollment). |
| UBT `UnauthorizedAccessException` writing `Engine\Intermediate` (e.g. `VVMBytecodeOps.gen.h` denied) | Synced files are read-only because the client is `noallwrite`; UBT can't write generated headers. | Clear read-only (`attrib -R <drive>:\*.* /S /D`) or use an `allwrite` client. See [appendix §8](#8-p4-noallwrite-makes-synced-files-read-only--ubt-must-be-able-to-write). |
| `Couldn't find target rules file for target 'Editor'` | `UETarget` is set to the generic `Editor` instead of the project's real editor target. | Use the real editor target name, e.g. `LyraEditor`. See the [per-job args table](#9-trigger-the-build-pipeline-per-job-arguments). |
| `REFUSING to add this host to igroup 'horde_san_hydrator'` | The hydrator instance was replaced (ASG, or stop/re-create) and the single-host igroup still holds the old host's IQN. | If EC2 still reports the old instance as **terminated**, the hydrate removes the stale IQN itself and proceeds. Otherwise remove it by hand: `lun igroup remove -vserver <svm> -igroup horde_san_hydrator -initiator <stale-iqn>`. Never add a second live host. See [appendix §3](#3-ntfs-is-not-a-shared-filesystem--hence-two-igroups). |
| `No usable partition on disk ... provision it with -Format` | The source LUN exists but is RAW: it was created outside the pipeline, so the hydrate did not format it. | Run the hydrate once with `-set:FormatIfRaw=true` (see [runbook step 8](#8-trigger-the-hydration-pipeline-to-create-the-first-snapshot)). |
| `iSCSI disk for LUN ... did not appear within 120s` | The LUN is mapped to an igroup this host's IQN is not in — usually the agent's IQN is not the one the scripts registered (e.g. the boot task did not run). | Compare `Get-InitiatorPort` on the agent with the igroup members (`lun igroup show`). The AMI's boot task sets `iqn.1991-05.com.microsoft:<instance-id>`; `C:\ProgramData\horde\set_unique_iqn.log` records what it did. |
| A build compiled sources older than the delta sync should have brought in | Two concurrent jobs shared one Perforce client for `p4 flush` / `p4 sync`, so one job's flush overwrote the other's have-list. | Leave `WorkspaceName` empty so each job gets its own `hordeclone_<stream>_<CloneVolumeName>` client (see [appendix §1](#1-the-incremental-sync-needs-p4-flush--this-is-not-optional)). |

## Security

- **No `0.0.0.0/0` ingress anywhere.** Every ingress rule is scoped to a single-IP `/32`, a referenced security group, or a private VPC CIDR (enforced as a hard invariant in `security.tf`).
- **External ALB locked to the deployer `/32`.** Both the HTTPS listener (443) and the HTTP→HTTPS redirect (80) accept traffic only from `local.my_ip_cidr`.
- **No OIDC auth configured yet.** The Horde module's `auth_method` is intentionally left unset in this sample, so **the `/32` lock is the only access gate** on the Horde UI. Configure OIDC (or another Horde auth method) before widening ALB access beyond your own IP.
- **Internal traffic stays private.** Horde ECS tasks, Perforce, and agents run in private subnets; FSxN accepts iSCSI (3260) and ONTAP-REST only from the agent security group; P4 (1666) is reachable only from the agent SG and the deployer `/32`.
- **The agent role reads exactly two secrets.** The agent instance role can read the FSxN `fsxadmin` secret and the Horde P4 credentials secret — not the Perforce super password. Build agents execute code from the depot, so treat every grant on that role as reachable from a build. A sensible follow-up is to replace `fsxadmin` (file-system-wide admin) with an SVM-scoped ONTAP user that can only clone, snapshot and map LUNs on the workspace SVM.
- **`ec2:DescribeInstances` is the only non-secret action the sample grants the agents.** It lets the hydrate prove that a stale igroup member belongs to a terminated instance before removing it ([appendix §3](#3-ntfs-is-not-a-shared-filesystem--hence-two-igroups)); it is read-only and cannot be resource-scoped, hence `"*"`.
- **The split-horizon zone covers one name.** In-VPC agents resolve the Horde FQDN to the internal ALB through a private hosted zone named after that FQDN, not after your apex domain — a private zone for the apex would make every other record under your domain return NXDOMAIN inside the VPC.

## Appendix: operational deep-dive (why the pipeline is built this way)

These are the operational requirements and constraints of the pipeline. Each is stated once here and referenced from the runbook, args table, and troubleshooting sections above.

The FlexClone premise is what makes per-build workspaces cheap: an ONTAP snapshot and a FlexClone of a multi-tens-of-GiB, hundreds-of-thousands-of-file UE stream each complete in well under a couple of seconds, and the iSCSI mount in tens of milliseconds — so a per-build workspace materializes in seconds instead of the cold full sync it replaces. On the author's reference workspace (a ~49.55 GB / 268,730-file UE 5.7 stream) `attach-clone-lun.ps1` measured a ~9.7 s total for clone + LUN map + iSCSI attach + disk online, versus ~8m23s for a cold `p4 sync`; that is one measured example rather than a universal guarantee, since it tracks workspace size, instance type, and how far the snapshot lags head. Because clones are copy-on-write, two workspace volumes share the parent's blocks and add only their own deltas, so total physical usage stays close to a single copy. But several things must be right or the pipeline either loses its benefit or does not work at all.

### 1. The incremental sync needs `p4 flush` — this is not optional

`p4 sync` is incremental only relative to the **client's have-list**, and the build agent's workspace is a fresh client. The files are on the clone, but the server has no record of that, so a bare `p4 sync` **re-transfers the entire stream** — the FlexClone completes in a second and then you pay the full sync anyway. `BuildPipeline.xml` therefore runs `p4 flush <stream>/...@$(SnapshotChangelist)` first: a metadata-only operation that writes the have-list without transferring content, completing in seconds even for hundreds of thousands of files. Because flush trusts the changelist you give it, snapshots must be named `cl-{N}` and `SnapshotChangelist` must be passed per job — the wrong value leaves the workspace disagreeing with the server about what is on disk.

Keep the hydrate schedule frequent: the wider the gap between the snapshot changelist and head, the more the following `sync` must walk the diff — a snapshot at or near head keeps the delta sync to about a second, while a gap of several changelists can add tens of seconds. (`flush` and `sync` need Perforce auth, minted by the node's `p4 login` first step — see the [Architecture](#architecture) pipeline notes.)

The client the flush and sync run against is **created per job** — `hordeclone_<stream>_<CloneVolumeName>`, where `<stream>` is the stream name reduced to `[a-z0-9_]` (Terraform local `fsxn_client_stream_safe`; `//YourGame/main` becomes `yourgame_main`) — host-less, rooted on the clone drive, and deleted by the teardown lease hook. Perforce keeps the have-list on the server per client, so a name shared by concurrent builds races: job A flushes @100, job B flushes @105, and A's `sync` then believes it already has 101–105 and compiles stale sources with no error. Leave `WorkspaceName` empty; set it only to force a fixed client name for a single build agent. A client leaked by a hard Spot reclaim is collected by the off-agent reaper ([§4](#4-clone-teardown-must-not-rely-on-a-buildgraph-node)).

### 2. The data path is iSCSI/NTFS, not NFS — and that is why UBA works

The binding constraint is Windows filesystem semantics, not throughput. On a Windows NFSv3 mount, four separate UE subsystems fail:

| Component | Failure on Windows NFSv3 |
|---|---|
| **UBA** (Unreal Build Accelerator) | Detours file I/O and calls `NtQueryInformationFile` on every input; the NFS redirector answers `0xc000000d` for files under `Engine/Source/*` — i.e. exactly the files that must live on the clone. UBA cannot be enabled at all. |
| **DDC** | mmap'd cache writes fail or corrupt |
| **Shader library** | write failures during cook |
| **Stager** | `SafeCopyFile` → `SetFileTime` fails and **retries forever**, so the job *hangs* instead of erroring |

Each is only workaroundable by moving that write to local NTFS, which splits the project across three locations and still leaves UBA off — defeating the purpose of a build-acceleration pipeline. A LUN presents real NTFS, so all four work and UBA stays enabled. Block I/O is also meaningfully faster to hydrate (~40%), skipping the per-file metadata round-trips NFS incurs. And iSCSI authorises by initiator IQN (igroups), not directory identity, so you get NTFS semantics without the AD/CIFS dependency SMB would impose.

### 3. NTFS is not a shared filesystem — hence two igroups

This is the one constraint SAN introduces, and it is a correctness boundary rather than a style preference. **A LUN has exactly one legitimate writer.**

| igroup | Members | Holds |
|---|---|---|
| `horde_san_hydrator` | **exactly one host** | the source LUN |
| `horde_san_agents` | all build agents | per-job clone LUNs |

The shared igroup is safe because each clone LUN is used by exactly one job on one agent, so build agents self-register into it at job time. The source LUN is different: `hydrate-source-lun.ps1` registers its IQN with `-SingleHost` and **fails the run** if that igroup already holds a different initiator, rather than quietly becoming a second writer on one filesystem. Mapping the source LUN to the shared igroup would let two hosts corrupt one volume.

When the hydrator instance is replaced (an ASG replacement, or a stop and re-create), its igroup still holds the old host's IQN. Because the AMI derives every IQN from the EC2 instance id, the hydrate checks that instance with `ec2:DescribeInstances` before refusing: if EC2 reports it **terminated**, the stale IQN is removed automatically and the run proceeds. Anything else still refuses — the instance is running, EC2 no longer lists the id (terminated instances stay visible only for a short while), or the IQN does not embed an instance id — and the run fails with `REFUSING to add this host to igroup`; remove the stale initiator by hand with `lun igroup remove -vserver <svm> -igroup horde_san_hydrator -initiator <stale-iqn>`. This is why the sample's agent policy also grants `ec2:DescribeInstances` — see [Security](#security).

Two consequences:

- **The hydrator is Windows, because the LUN carries NTFS.** Pool membership is by the `Horde_Autoscale_Pool` instance tag (`aws-tag == 'Horde_Autoscale_Pool:SyncPool'` in `globals.json.tpl`); both pools are Windows.
- **Connect exactly ONE iSCSI portal** unless MPIO is installed **and** MSDSM is actively claiming iSCSI devices. The AMI bake enables that claim after the reboot the MPIO install needs and fails if it did not stick. Two portals without an active claim make Windows enumerate a single LUN as two disks and corrupt it. `Connect-SanPortal` tests the claim state, not just the feature.

### 3a. Flush the NTFS write cache before every snapshot

An ONTAP snapshot captures blocks as the array sees them, so anything still in the Windows write cache is simply **absent** from the snapshot. You get a crash-consistent image that may mount and then fail `chkdsk`, or silently lose the tail of the `p4 sync`. `New-OntapSnapshot -FlushDriveLetter` issues the `Write-VolumeCache` with `-ErrorAction Stop`, so a failed flush fails the hydrate instead of shipping a crash-consistent snapshot; do not remove it.

### 3b. Pipeline snapshots are pruned, and FSx's default snapshot policy is off

Every `cl-<N>` snapshot costs the blocks changed since the previous one, and on an hourly hydrate they accumulate until the container volume fills — at which point the thin LUN goes offline and the hydrator itself stops working. At the end of each hydrate the hydrator deletes `cl-<N>` snapshots beyond the newest `fsxn_snapshot_retention` (a **count**, default 24, passed as `-set:SnapshotRetention`; `0` disables pruning), skipping any snapshot that still backs a live FlexClone. The source volume is also created with `snapshot_policy = "none"` so ONTAP's default hourly/daily/weekly snapshots do not consume the same headroom. Size `fsxn_san_volume_size_gb` for the retained count. Deleting a clone does not free its parent immediately: ONTAP parks the deleted clone in its recovery queue and the parent stays busy until that entry is purged (several minutes), so a snapshot can be skipped by one prune and removed by a later one.

### 4. Clone teardown must not rely on a BuildGraph node

`RunLate="true"` is **not** a BuildGraph `<Node>` attribute, and BuildGraph has no equivalent that guarantees a teardown node runs after a failure: a node ordered after a **failed** node is *Skipped*. So the `Cleanup Clone` node is a success-only fast path. Guaranteed teardown is registered as a **Horde lease-end hook** (`UE_HORDE_CLEANUP` → `buildgraph/teardown-clone-lun.ps1`), which runs regardless of outcome.

Neither path survives a **hard Spot reclaim**, since both run *on the agent*. For that, this sample now ships an **off-agent reaper** — `buildgraph/reap-orphans.ps1`, driven by `buildgraph/ReaperPipeline.xml` on a schedule on the idle single-writer `SyncPool` (`reap` template in `globals.json.tpl`). It deletes a per-job `hordeclone_*` Perforce client only when **all three** gates pass — the name matches `^hordeclone_`, its backing `build_*` clone volume no longer exists in ONTAP, and the owning Horde job is not live — and likewise reaps orphaned `build_*` clone volumes whose job is dead. Any uncertainty (ONTAP unreachable, Horde API ambiguous, a name it does not understand) means it deletes nothing. It defaults to a **dry run**; set `-set:Execute=true` on the template once you trust it. A leaked clone pins its parent snapshot, which then makes snapshot rotation fail too — the reaper is what keeps that from happening on Spot.

### 5. ONTAP volume names reject hyphens

`build-{jobId}` fails with an opaque HTTP 400. Use `build_{jobid}`, lowercased. (ONTAP: start with a letter or `_`, then letters/digits/`_`, ≤203 chars.) This is why the per-job `CloneVolumeName` argument must be lowercase alphanumeric/underscore with **no hyphens**.

### 6. The project must live in a subfolder, not at the drive root

A UE project placed at the **drive root** of the clone LUN (e.g. `W:\Project.uproject`) crashes UnrealBuildTool with a `NullReferenceException` in `SourceFileWorkingSet`: `ProjectDir.ParentDirectory` is `null` at a drive root. The project **must** live in a subfolder on the clone LUN (e.g. `W:\<Project>\<Project>.uproject`), so `ProjectDir` has a non-null parent. That maps directly to the required depot layout — the project sits under `//YourGame/main/<Project>/`, never at the stream root. See the [depot layout](#4-seed-the-perforce-depot-project--engine) in the runbook.

### 7. The engine must be present in the stream / on the LUN

The `Compile` node resolves `<drive>:\Engine\Build\BatchFiles\Build.bat` off the clone, so the UE **engine tree must be on the LUN** — i.e. in the stream under `//YourGame/main/Engine/`. This is required, not optional. Note that an **installed-engine** build (identified by the `Engine/Build/InstalledBuild.txt` sentinel) compiles **project modules only** — this is correct behavior, but a from-source editor compile needs the full engine source tree present.

### 8. `p4 noallwrite` makes synced files read-only — UBT must be able to write

With a `noallwrite` client, synced files are read-only on disk. UnrealBuildTool needs to write generated headers into `<drive>:\Engine\Intermediate`, which fails against read-only files (e.g. `UnauthorizedAccessException` on `VVMBytecodeOps.gen.h`). `BuildPipeline.xml` therefore clears the read-only attribute (`attrib -R <drive>:\*.* /S /D`) before invoking `Build.bat`. If you would rather not clear attributes, use an **`allwrite`** client for the per-build workspace instead — but do one or the other, or the compile fails writing intermediates.

### 9. Clone + mount + flush + compile must be ONE BuildGraph node

Each BuildGraph node runs as its **own process**, and a Windows drive-letter iSCSI mount does **not** persist across processes. `BuildPipeline.xml` therefore merges clone, iSCSI mount of `W:`, per-build P4 client creation rooted on `W:`, `p4 flush @SnapshotChangelist`, the read-only clear, and `Build.bat` into a **single merged `Compile` node**. Splitting these into separate nodes drops the mount between steps.

### 10. The `svc-horde` password must match on both sides

The pre-created secret (passed via `horde_p4_credentials_secret_arn`) holds the **real password you chose** for `svc-horde`. Terraform cannot set that password on the P4 user itself, so you set it on the server in [runbook step 3.2](#32-set-the-password-to-match-the-pre-created-secret). Rotating one side without the other breaks Horde's Perforce connection — Horde will not be able to authenticate to Perforce.

### 11. Horde 5.5 does not auto-approve agent enrollment

Newly enrolled Sync and Build agents sit **pending** until an operator approves them (Horde UI or `POST /api/v1/enrollment`). Until you do, the pools have no online agents and jobs never lease. `enable_new_agents_by_default` does **not** auto-approve enrollment — it only controls whether an agent is enabled *once approved*; setting it true does not skip this manual approval step. This is done in [runbook step 7](#7-approve-agent-enrollment-assign-each-agent-to-exactly-one-pool), where each agent must be approved into exactly one pool.

### 12. Single source stream (per-stream source LUN)

The source LUN (`/vol/p4_workspace/workspace`, hydrated by the `fsxn-hydrator` P4 client behind a single-host igroup and a `min = max = 1` `SyncPool`) is a **per-stream** artifact. A subsequent `p4 sync` of a *different* stream onto the same LUN does not delete the earlier stream's files — Perforce only manages files in the current client's have-list — so the earlier stream's tree persists on the NTFS volume, is captured by the next ONTAP snapshot, and is cloned into every build taken from it (cross-stream contamination). This sample is therefore scoped to one stream. This is **not** a data-path limitation: the single-writer rule (one writer per NTFS LUN, enforced by the single-host igroup and `-SingleHost`) forbids two hosts writing one LUN, but permits multiple sync agents each owning a **separate** volume/LUN. Supporting more than one stream would require a per-stream volume/LUN with a deterministic stream→agent→LUN binding and serialized single-writer enforcement; that is out of scope for this sample.

## Scaling notes and known limitations

- **Horde's own workspaces sync the whole stream.** Both the graph-parse ("Setup Build") step and the Compile step get a Horde-managed sandbox workspace (the `workspaceTypes` in `globals.json.tpl`), and Horde syncs the **entire stream** into it before the node runs — on a cold agent that is a full engine sync, which dwarfs the ten-second clone. A workspace-level `view` is **silently ignored** by Horde's Perforce materializer (the partitioned clients still get the full stream view). What works is a Perforce **virtual stream** whose share-paths hold only what `RunUAT`/BuildGraph need to start, with the `workspaceTypes` entries pointing their `stream` at it. On an installed-engine stream the slice was `Engine/Build`, `Engine/Binaries/DotNET`, `Engine/Binaries/ThirdParty/DotNet`, `Engine/Config`, `Engine/Intermediate/ScriptModules`, `Engine/Programs`, `Engine/Platforms` plus the `Build/` scripts — about 4 GB of a 50 GB stream, a ~30 s sync. A from-source engine also needs whatever `RunUAT.bat` compiles on first run (AutomationTool and UnrealBuildTool sources under `Engine/Source/Programs`), so measure the slice rather than copying that list.
- **One build job per agent at a time.** The clone drive letter is fixed (`CloneMountDrive`, default `W`), so if Horde schedules a second lease on an agent that is still running a build, the second job's attach fails when it cannot take `W:` (it does not corrupt anything). Keep one lease per agent, or derive the drive letter per job as well.
- **Off-agent clone reaper for Spot.** On-agent teardown (the `UE_HORDE_CLEANUP` lease hook) does not survive a hard Spot reclaim. This sample ships a scheduled **off-agent reaper** (`buildgraph/reap-orphans.ps1` via `ReaperPipeline.xml`, the `reap` template on `SyncPool`) that deletes `build_*` clone volumes and their `hordeclone_*` Perforce clients whose Horde job is no longer running — behind three fail-safe gates (name, backing-clone-gone, job-not-live). It defaults to a dry run; flip `-set:Execute=true` once trusted. See [appendix §4](#4-clone-teardown-must-not-rely-on-a-buildgraph-node).

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
<!-- This block is auto-generated by the repo's `terraform-docs` pre-commit hook. Do not edit by hand; run the hook to populate the Requirements / Providers / Modules / Resources / Inputs / Outputs tables. -->
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
