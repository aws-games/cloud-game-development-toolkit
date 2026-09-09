# Unreal Horde Build Pipeline

This sample deploys an [Unreal Engine Horde](https://dev.epicgames.com/documentation/en-us/unreal-engine/horde) build farm that compiles from a Perforce stream using [Amazon FSx for NetApp ONTAP](https://aws.amazon.com/fsx/netapp-ontap/) with a thin-clone workspace pattern. Instead of every build agent running a full `p4 sync` from scratch, the pipeline keeps one persistent source workspace warm and hands each build an instant, copy-on-write clone of it.

The core idea has two moving parts. A **Hydrator** (Sync) agent periodically syncs a persistent FSxN **LUN** from a Perforce stream and snapshots it as `cl-<changelist>`. When a build is requested, a **Build Agent** creates an instant [FlexClone](https://docs.netapp.com/us-en/ontap/concepts/flexclone-volumes-files-luns-concept.html) of that snapshot, presents the clone's LUN to itself over **iSCSI as real NTFS**, transplants the Perforce have-list with `p4 flush` (metadata-only), syncs only the delta, compiles, and tears the clone down. The result is per-build workspaces in ~10 s instead of a multi-minute full sync, with UBA enabled.

The pipeline compiles `UnrealEditor` from source off the FlexClone LUN with **UBA (Unreal Build Accelerator) enabled**. The end-to-end path is: hydrate a Perforce stream → ONTAP snapshot `cl-<N>` → FlexClone → iSCSI mount as `W:` (real NTFS) → `p4 flush` (metadata-only) → **compile `UnrealEditor` from source off the clone LUN**. It targets a source-available UE project such as Epic's **Lyra** sample (a real C++ project with `Source/` and `Modules[]`).

**The data path is iSCSI/NTFS, not NFS.** Both agent pools are Windows because Windows NFSv3 cannot run a UBA build; see the [operational deep-dive appendix](#appendix-operational-deep-dive-why-the-pipeline-is-built-this-way) for the full reasoning.

## Big picture / what you're signing up for

This is a **Terraform sample plus several manual operator steps** — it is **not** a one-shot `terraform apply`. Terraform stands up the infrastructure, but seeding the depot, configuring the Perforce service user, and approving agent enrollment are manual operations the sample deliberately does not automate. Budget for both phases:

- **Phase 1 — stand up the infrastructure.** Build the Windows build-agent AMI with Packer, then `terraform apply`.
- **Phase 2 — seed the depot and run your first build.** Configure the Perforce `svc-horde` user, seed the depot with a source-available project + engine, submit the BuildGraph scripts, approve Horde agent enrollment, then trigger the hydration and build pipelines.

### Checklist (mirrors the [end-to-end runbook](#end-to-end-runbook))

| # | Step | Type | Time hint |
|---|---|---|---|
| 1 | [Build the Windows build-agent AMI](#1-build-the-windows-build-agent-ami) | [Manual] | ~30–45 min (Packer build) |
| 2 | [Deploy with Terraform](#2-deploy-with-terraform) | [Terraform] | ~20–30 min (first apply; FSxN + ALBs are slowest) |
| 3 | [Configure the `svc-horde` P4 user](#3-configure-the-svc-horde-p4-user) | [Manual] | minutes |
| 4 | [Seed the Perforce depot (project + engine)](#4-seed-the-perforce-depot-project--engine) | [Manual] | large/slow — depot seed of engine + project |
| 5 | [Submit the BuildGraph scripts under `Build/`](#5-submit-the-buildgraph-scripts-to-the-depot-under-build) | [Manual] | minutes |
| 6 | [Make Horde aware of the stream / project](#6-make-horde-aware-of-the-stream--project) | [Manual] | minutes |
| 7 | [Approve agent enrollment in the Horde UI](#7-approve-agent-enrollment-in-the-horde-ui) | [Manual] | minutes |
| 8 | [Trigger the Hydration Pipeline (first snapshot)](#8-trigger-the-hydration-pipeline-to-create-the-first-snapshot) | [Manual] | one hydrate cycle |
| 9 | [Trigger the Build Pipeline (per-job arguments)](#9-trigger-the-build-pipeline-per-job-arguments) | [Manual] | one build |

Steps 1–2 are Phase 1; steps 3–9 are Phase 2. The [runbook](#end-to-end-runbook) is the authoritative "what to do" path; the [appendix](#appendix-operational-deep-dive-why-the-pipeline-is-built-this-way) explains "why the pipeline is built this way".

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

Two BuildGraph pipelines drive the workflow, and their agent/node names are coupled to `config/horde/globals.json.tpl`:

- `buildgraph/HydratePipeline.xml` — agent `SyncAgent`, node `Sync And Snapshot`, run by the `hydrate` template on `SyncPool`.
- `buildgraph/BuildPipeline.xml` — agent `BuildAgent`, a single merged `Compile` node (clone → iSCSI mount `W:` → per-build P4 client → `p4 flush` → clear read-only → `Build.bat`), run by the `build` template on `BuildPool`. The clone/mount/flush/compile steps are deliberately **one node** — see [appendix §9](#9-clone--mount--flush--compile-must-be-one-buildgraph-node). Guaranteed teardown is a Horde `UE_HORDE_CLEANUP` lease hook — see [appendix §4](#4-clone-teardown-must-not-rely-on-a-buildgraph-node).

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
   single "Compile" node            --> p4 flush @<N>   (have-list, no transfer)
   (clone+mount+flush+compile       --> p4 sync         (delta only)
    in ONE process)                 --> clear read-only, Build.bat with UBA ENABLED
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
- **A pre-created Secrets Manager secret for the Horde P4 user (required when deploying the bundled Perforce).** Create a Secrets Manager secret shaped `{"username":"svc-horde","password":"..."}` and pass its ARN via the `horde_p4_credentials_secret_arn` variable. This sample does **not** create this secret for you. A pre-created secret keeps the ARN a known value at plan time — the Horde module gates its Secrets Manager read policy on a `count` that cannot resolve against an ARN that is only known after apply. (If you set `existing_perforce_server_endpoint` to use your own Perforce server, provide the secret for that server's Horde service account instead.) The password value stored here must match the password set on the P4 user in [runbook step 3](#3-configure-the-svc-horde-p4-user); see [appendix §10](#10-the-svc-horde-password-must-match-on-both-sides).
- **No custom BuildGraph task compilation is required.** The SAN pipelines drive ONTAP and the Windows iSCSI initiator from PowerShell (`buildgraph/OntapSan.psm1` plus three scripts), so you do **not** need to compile the C# tasks in `assets/buildgraph/tasks` into your `AutomationTool`. This is deliberate: LUN mapping/unmapping does not exist in those tasks, and teardown ordering (offline disk → unmap → delete volume) is a correctness requirement they cannot express. It also means the pipeline can be tested without a UAT build.
- **BuildGraph scripts submitted to the depot.** The `buildgraph/*.xml` files **and** the supporting `*.ps1` scripts must be submitted to your Perforce depot under `Build/` so the `-Script=Build/...` paths in `globals.json` resolve against the stream root. See [runbook step 5](#5-submit-the-buildgraph-scripts-to-the-depot-under-build).

---

# Phase 1 — stand up the infrastructure

## Build the Windows build-agent AMI (manual prerequisite)

This is a **one-time operator step you run before `terraform apply`.** The Horde Windows agents compile Unreal Engine from source and mount their workspace over iSCSI, and the stock Amazon `Windows_Server-2022` AMI has **neither** the C++ build toolchain **nor** the iSCSI initiator. Baking them into an image once (~30–45 minutes) is far cheaper than re-installing on every agent boot, so the sample does not automate it.

The Packer template at [`assets/packer/build-agents/windows-horde`](../../assets/packer/build-agents/windows-horde) bakes in the VS2022/MSVC toolchain, the .NET runtimes, `p4`/`awscli`, and the MSiSCSI initiator + MPIO, and an in-build `validate_image.ps1` **fails the build** if the toolchain, iSCSI initiator, or MPIO are missing — so a published AMI is never half-baked. See that template's README and [`example.pkrvars.hcl`](../../assets/packer/build-agents/windows-horde/example.pkrvars.hcl) for the exhaustive component list and variable reference.

### Build command

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

`region` must match where you deploy the sample; `vpc_id`/`subnet_id` need outbound internet (a **private** subnet with NAT egress is recommended, since the build uses Chocolatey to install the toolchain); `public_key` is the SSH public key baked into the AMI so the Horde orchestration service can reach the agent. On success Packer prints the new AMI ID, registered as `windows-horde-build-agent-<timestamp>`.

> **WinRM reachability gotcha.** The template is **private by default** (`associate_public_ip_address = false`, `ssh_interface = "private_ip"`), so **Packer must run from a host that can route to the build instance's private IP** — i.e. from inside the same VPC (a bastion/CI runner), or a peered/VPN-connected network. Run it from a workstation that cannot reach that private IP (e.g. a corporate laptop whose egress blocks WinRM) and the build stalls at "Waiting for WinRM". If you must build over the public internet, add `-var 'associate_public_ip_address=true' -var 'ssh_interface=public_ip' -var 'security_group_id=sg-xxxxxxxx'` where the SG scopes WinRM (5986) to **your own /32** — never `0.0.0.0/0`.

### How this sample consumes the AMI

The AMI is wired up automatically in [`main.tf`](main.tf) via `data.aws_ami.horde_build_agent`:

- **Auto-lookup (default, keeps the sample generic).** Leave `build_agent_ami_id` unset (`null`). The sample looks up the newest **self-owned** AMI whose name matches `build_agent_ami_name_prefix` (default `windows-horde-build-agent-*`, which matches the Packer template's `ami_prefix`). No hardcoded AMI ID ends up in your config.
- **Pin an explicit AMI.** Set `build_agent_ami_id = "ami-xxxxxxxx"` in `terraform.tfvars` to pin a specific image; it takes precedence over the name-prefix lookup.

**Build the AMI first**, then `terraform apply` — if no matching AMI exists and `build_agent_ami_id` is unset, the `data.aws_ami` lookup fails at plan time.

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
- `fsxn_iscsi_portals` — comma-separated SVM iSCSI portal addresses (pass as `-set:IscsiPortals`; connect exactly one unless MPIO is installed — see [appendix §3](#3-ntfs-is-not-a-shared-filesystem--hence-two-igroups)).
- `fsxn_workspace_lun_path` — ONTAP path of the workspace LUN that hosts attach over iSCSI (the LUN carries NTFS).
- `fsxn_management_endpoint` / `fsxn_svm_management_endpoint` — ONTAP REST API targets for the BuildGraph tasks.
- `sync_agent_launch_template_id` / `build_agent_launch_template_id` — launch template IDs for the two agent pools.
- `agent_instance_role_name` — the IAM role attached to agent instances (has the secrets-read policy).
- `horde_p4_credentials_secret_arn` — echoes the pre-created Horde P4 username/password secret ARN you passed in (JSON, sensitive). This sample does not create the secret.
- `fsxn_password_secret_arn` — the FSxN `fsxadmin` password secret (sensitive).

Once the stack is up, continue with the [end-to-end runbook](#end-to-end-runbook) below (Phase 2).

---

# Phase 2 — seed the depot and run your first build

## End-to-end runbook

This is the authoritative "what to do" path. Steps 3, 4, 6, 7, 8 and 9 are manual operations the sample does **not** automate. Do them in order. Each step links into the [operational deep-dive appendix](#appendix-operational-deep-dive-why-the-pipeline-is-built-this-way) for the "why".

### 1. Build the Windows build-agent AMI

One-time operator step, **before** `terraform apply`. See [Build the Windows build-agent AMI](#build-the-windows-build-agent-ami-manual-prerequisite).

### 2. Deploy with Terraform

See [Deployment](#deployment). Provisions the VPC, FSxN, ECS Horde server, Perforce, and the two agent launch templates. The external ALB is locked to the deployer `/32` — no `0.0.0.0/0` ingress anywhere.

### 3. Configure the `svc-horde` P4 user

Horde authenticates to Perforce as `svc-horde` (the `perforceClusters` credentials in `globals.json`, sourced from the pre-created secret), but **Terraform cannot provision that user inside p4d**. After the P4 server is up, complete these one-time manual steps on the server, in order, so the Horde stream poller can log in and read the stream. These commands assume a Perforce super user; on the bundled SDP server, run `p4` after sourcing `p4_vars` for the instance.

These are **manual, one-time** steps — Terraform does not perform them. They persist across normal server restarts (on SDP servers all of these edits are journaled and survive restarts); you only need to redo them if the P4 database is ever **rebuilt from scratch** without a checkpoint/journal restore.

#### 3.1 Create the `svc-horde` user

`svc-horde` must exist as a Perforce user. A `service`-type user is preferred for least privilege. Skip this step if your deployment already auto-created the user.

```bash
# Idempotent create/edit; set Type: service in the spec for least privilege
p4 -u <super> user -f -o svc-horde | \
  sed 's/^Type:.*/Type:\tservice/' | \
  p4 -u <super> user -f -i
```

#### 3.2 Set the password to match the pre-created secret

Set the user's password **on the server** to match the value already in the pre-created secret. Rotating one side without the other breaks Horde's Perforce connection — see [appendix §10](#10-the-svc-horde-password-must-match-on-both-sides).

```bash
# Confirm the password already stored in your pre-created secret
aws secretsmanager get-secret-value --secret-id <horde_p4_credentials_secret_arn>

# On the P4 server, set the svc-horde user's password to that value
p4 -u <super> passwd svc-horde
```

#### 3.3 Grant protections on the stream depot

`svc-horde` must be authorized in the protections table (`p4 protect`) to read/write the stream depot the poller monitors. Add a line matching this pattern (using your depot in place of the generic `//YourGame/...` placeholder):

```text
write user svc-horde * //YourGame/...
```

`p4 protect` is **order-sensitive**: later lines override earlier ones for overlapping paths, so place this grant where it will not be overridden by a subsequent exclusionary line (e.g. `list user * -//YourGame/...`). Without this grant the Horde poller fails and the server logs `Access for user 'svc-horde' has not been enabled by 'p4 protect'`. `super` is **not** required for the poller — the `write ... //YourGame/...` line is exactly what grants the stream access it needs. Keep it least-privilege.

#### 3.4 Add `svc-horde` to service-user groups

Add `svc-horde` to a group with an `unlimited` (or long) `Timeout` so its login ticket does not expire and interrupt polling. Group membership only affects the ticket timeout — it does **not** grant depot access; the protections line from step 3.3 does that.

```bash
# Grant an unlimited ticket timeout (create the group if it doesn't exist)
p4 -u <super> group -o unlimited_timeout | \
  sed 's/^Timeout:.*/Timeout:\tunlimited/' | \
  p4 -u <super> group -i

# Add svc-horde to the group's Users list, then re-submit
p4 -u <super> group -o unlimited_timeout | \
  awk '/^Users:/{print; print "\tsvc-horde"; next} {print}' | \
  p4 -u <super> group -i
```

### 4. Seed the Perforce depot (project + engine)

The depot must contain a **source-available** UE project **and** the matching engine before a build can compile anything. This is manual — the sample does not seed the depot.

**Run the helper instead of hand-writing P4 commands.** From the in-VPC Windows workstation (see below), run [`scripts/seed-depot.ps1`](scripts/seed-depot.ps1) — see the script header for parameters. It creates the stream depot/stream if absent, submits the project under a subfolder, submits the Build scripts, provisions the engine (branch from the depot with `p4 populate`, or submit a local tree), and verifies the layout. Supports `-WhatIf`.

**Where to run it + prerequisites.** This sample does **not** deploy a host to run the seed from — run `scripts/seed-depot.ps1` from **any host you choose**: your local workstation, a CI runner, or an EC2 instance you provision yourself. Wherever you run it, that host must have:

- The Perforce CLI `p4` on `PATH`.
- PowerShell (the script is a `.ps1`).
- **Network reachability to the Perforce server's `P4PORT`.** The bundled P4 server is in a **private subnet**, so the host must be in the VPC or on a VPN/peered network that can reach it (e.g. an in-VPC EC2 instance, or your workstation over VPN).
- The project tree + BuildGraph scripts available locally to submit.
- AWS CLI + credentials **only if** you use `-P4PasswordSecret` (which reads the P4 password from Secrets Manager). If you pass `-P4Password` directly, the AWS CLI is **not** required.

**Tearing the depot back down later.** Because `seed-depot.ps1` creates a **stream depot**, `p4 depot -d <depot>` will refuse with `location of existing streams` until the versioned stream spec is obliterated first — after deleting the stream's files/spec, run `p4 stream --obliterate -y //<depot>/<stream>` (Perforce 2019.1+), then delete the depot.

**Required stream layout.** The stream must be laid out so the project is in a subfolder (the [drive-root gotcha](#6-the-project-must-live-in-a-subfolder-not-at-the-drive-root)) and the engine tree is present ([engine-in-stream](#7-the-engine-must-be-present-in-the-stream--on-the-lun)):

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

**Use a project with C++ source.** The project **must** have `Source/` and real `Modules[]` in its `.uproject`. A concrete example is Epic's **Lyra** (from the entitled `EpicGames/UnrealEngine` repo at `Samples/Games/Lyra`, at the tag matching your engine version — e.g. `5.5.4-release`). Getting Lyra requires a GitHub account linked to and accepted into the Epic Games organization. **Do not** pick a content-only sample: Epic's Stack-O-Bot Launcher/Fab sample ships prebuilt DLLs with **no `Source/`** and **cannot be compiled from source** — a build against it fails because there is nothing to compile.

**Seeding environment.** Bring up an in-VPC Windows workstation in a **private** subnet, reachable via **SSM / Fleet Manager** with **no public ingress** (a security group with zero inbound rules — consistent with the no-`0.0.0.0/0` posture of this sample). Install `p4` on it, then run `scripts/seed-depot.ps1`. The engine tree is large (~34 GiB), so prefer the script's `-EngineDepotPath` option to branch an engine already in the depot with `p4 populate` (lazy copy, no re-upload) rather than submitting a local copy.

### 5. Submit the BuildGraph scripts to the depot under `Build/`

Submit all of these to `//YourGame/main/Build/` so the `-Script=Build/...` paths in `globals.json` resolve against the stream root. `scripts/seed-depot.ps1` does this for you via `-BuildScriptsPath`:

- `buildgraph/HydratePipeline.xml`
- `buildgraph/BuildPipeline.xml`
- `buildgraph/OntapSan.psm1`
- the pipeline `*.ps1` scripts (including `buildgraph/create-build-client.ps1`, `hydrate-source-lun.ps1`, and `teardown-clone-lun.ps1`)

### 6. Make Horde aware of the stream / project

The project, stream, and the two templates are delivered by `config/horde/globals.json.tpl`, which points the templates at `Build/HydratePipeline.xml` and `Build/BuildPipeline.xml`. Changing streams or templates means editing `config/horde/globals.json.tpl` and redeploying (or applying the config to the live server).

Confirmed `globals.json` requirements for the live Horde **5.5** server (a **flat, top-level v1** schema):

- `agentTypes` mapping `Win64 → build-pool` and `AnyAgent → sync-pool`, plus `workspaceTypes`.
- A **`storage` block** (backends + namespaces for `horde-logs` and `horde-artifacts`). Without it, agent log uploads fail with **HTTP 500 `Namespace not found`** (see [Troubleshooting](#troubleshooting)).

### 7. Approve agent enrollment in the Horde UI

Horde 5.5 does **not** auto-approve agents. New agents sit **pending** until an operator approves them — via the Horde UI, or `POST /api/v1/enrollment`. Until you approve them, `SyncPool` and `BuildPool` have **no online agents** and jobs never lease. Approve the Sync and Build agents once they enroll. Note that `enable_new_agents_by_default` does **not** auto-approve enrollment — it only controls whether an agent is enabled *once approved*. See [appendix §11](#11-horde-55-does-not-auto-approve-agent-enrollment).

### 8. Trigger the Hydration Pipeline to create the first snapshot

Run the **Hydration Pipeline** from the Horde UI (or wait for the 60-minute schedule, `patterns: [{ interval: 60 }]`). It syncs the stream onto the source FSxN volume and creates the first snapshot named `cl-<N>`. Note the `<N>` — it is the changelist you pass to the build. Keep this schedule frequent to keep incremental syncs cheap — see [appendix §1](#1-the-incremental-sync-needs-p4-flush--this-is-not-optional).

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

## Troubleshooting

Keyed to the exact error strings the pipeline can produce.

| Error / symptom | Cause | Fix |
|---|---|---|
| `Namespace 'horde-logs' not found` / HTTP 500 `StorageException` | The `storage` block is missing from `globals.json`, so agent log uploads have nowhere to go. | Add the `storage` block (backends + namespaces for `horde-logs` and `horde-artifacts`). See [runbook step 6](#6-make-horde-aware-of-the-stream--project). |
| `NullReferenceException ... SourceFileWorkingSet` (UBT) | The UE project is at the clone-LUN **drive root**; `ProjectDir.ParentDirectory` is `null`. | Put the project in a subfolder (`W:\<Project>\...`). See [appendix §6](#6-the-project-must-live-in-a-subfolder-not-at-the-drive-root). |
| Opaque **ONTAP HTTP 400** on clone create | The `CloneVolumeName` contains a hyphen, which ONTAP volume names reject. | Use `build_{jobid}`, lowercase, no hyphens. See [appendix §5](#5-ontap-volume-names-reject-hyphens). |
| `Access for user 'svc-horde' has not been enabled by 'p4 protect'` | `svc-horde` has no protections grant on the stream depot, so the poller can't read it. | Add the `write user svc-horde * //YourGame/...` line. See [runbook step 3.3](#33-grant-protections-on-the-stream-depot). |
| Agents show online but jobs never lease / pools empty | Agent enrollment is **not approved** (Horde 5.5 does not auto-approve). | Approve enrollment in the Horde UI. See [runbook step 7](#7-approve-agent-enrollment-in-the-horde-ui) / [appendix §11](#11-horde-55-does-not-auto-approve-agent-enrollment). |
| UBT `UnauthorizedAccessException` writing `Engine\Intermediate` (e.g. `VVMBytecodeOps.gen.h` denied) | Synced files are read-only because the client is `noallwrite`; UBT can't write generated headers. | Clear read-only (`attrib -R <drive>:\*.* /S /D`) or use an `allwrite` client. See [appendix §8](#8-p4-noallwrite-makes-synced-files-read-only--ubt-must-be-able-to-write). |
| `Couldn't find target rules file for target 'Editor'` | `UETarget` is set to the generic `Editor` instead of the project's real editor target. | Use the real editor target name, e.g. `LyraEditor`. See the [per-job args table](#9-trigger-the-build-pipeline-per-job-arguments). |

## Security

- **No `0.0.0.0/0` ingress anywhere.** Every ingress rule is scoped to a single-IP `/32`, a referenced security group, or a private VPC CIDR (enforced as a hard invariant in `security.tf`).
- **External ALB locked to the deployer `/32`.** Both the HTTPS listener (443) and the HTTP→HTTPS redirect (80) accept traffic only from `local.my_ip_cidr`.
- **No OIDC auth configured yet.** The Horde module's `auth_method` is intentionally left unset in this sample, so **the `/32` lock is the only access gate** on the Horde UI. Configure OIDC (or another Horde auth method) before widening ALB access beyond your own IP.
- **Internal traffic stays private.** Horde ECS tasks, Perforce, and agents run in private subnets; FSxN accepts iSCSI (3260) and ONTAP-REST only from the agent security group; P4 (1666) is reachable only from the agent SG and the deployer `/32`.

## Appendix: operational deep-dive (why the pipeline is built this way)

These are the operational requirements and constraints of the pipeline. Each is stated once here and referenced from the runbook, args table, and troubleshooting sections above.

The FlexClone premise holds up. For a **49.55 GB / 268,730-file** UE 5.7 stream: snapshot ~**80 ms**, FlexClone ~**1.2 s**, mount ~**31 ms**; two ~45 GiB workspace volumes occupy **35.3 GiB** physical. But several things must be right or the pipeline either silently loses its benefit or does not work at all.

### 1. The incremental sync needs `p4 flush` — this is not optional

`p4 sync` is incremental only relative to the **client's have-list**, and the build agent's workspace is a fresh client. The files are on the clone, but the server has no record of that, so a bare `p4 sync` **re-transfers the entire stream** — the FlexClone completes in a second and then you pay the full sync anyway.

`BuildPipeline.xml` therefore runs `p4 flush <stream>/...@$(SnapshotChangelist)` first, which writes the have-list **without transferring content** (measured: 3 s on Linux, 6 s on Windows; ~2 s for 209k files, metadata-only, no bulk transfer). This is why snapshots must be named `cl-{N}` and why `SnapshotChangelist` must be passed per job — flush is metadata-only and trusts you, so pointing it at the wrong changelist leaves the workspace silently disagreeing with the server about what is on disk.

Keep the hydrate schedule frequent: at a 10-changelist gap the following `sync` spent **26 s** walking the diff, versus ~1 s when the snapshot was at head.

### 2. The data path is iSCSI/NTFS, not NFS — and that is why UBA works

The binding constraint on the data path is Windows filesystem semantics, not throughput — which is why the data path is iSCSI/NTFS rather than NFS. On a Windows NFSv3 mount, four separate UE subsystems fail:

| Component | Failure on Windows NFSv3 |
|---|---|
| **UBA** (Unreal Build Accelerator) | Detours file I/O and calls `NtQueryInformationFile` on every input; the NFS redirector answers `0xc000000d`. **628 failures, all on `Engine/Source/*`** — i.e. exactly the files that must live on the clone. UBA cannot be enabled at all. |
| **DDC** | mmap'd cache writes fail or corrupt |
| **Shader library** | write failures during cook |
| **Stager** | `SafeCopyFile` → `SetFileTime` fails and **retries forever**, so the job *hangs* instead of erroring |

Each is only workaroundable by moving that write to local NTFS, which splits the project across three locations and still leaves UBA off — which defeats the purpose of a build-acceleration pipeline.

**A LUN presents real NTFS, so all four work and UBA stays enabled.** It is also ~40% faster to hydrate: **9m30s vs 15m33s** on a 49.55 GB seed, because block I/O skips per-file metadata round-trips.

Note what this does *not* cost: iSCSI authorises by initiator IQN (igroups), not by directory identity, so you get NTFS semantics **without** the AD/CIFS dependency that SMB would impose. No such trade-off is required.

### 3. NTFS is not a shared filesystem — hence two igroups

This is the one constraint SAN introduces, and it is a correctness boundary rather than a style preference. **A LUN has exactly one legitimate writer.**

| igroup | Members | Holds |
|---|---|---|
| `horde_san_hydrator` | **exactly one host** | the source LUN |
| `horde_san_agents` | all build agents | per-job clone LUNs |

The shared igroup is safe because each clone LUN is used by exactly one job on one agent, so build agents self-register into it at job time. The source LUN is different: `hydrate-source-lun.ps1` registers its IQN with `-SingleHost` and **fails the run** if that igroup already holds a different initiator, rather than quietly becoming a second writer on one filesystem. Mapping the source LUN to the shared igroup would let two hosts corrupt one volume.

Two consequences:

- **The hydrator is Windows, because the LUN carries NTFS** (`SyncPool` condition is `OSFamily == 'Windows'`).
- **Connect exactly ONE iSCSI portal** unless the Windows MPIO feature is installed. Two portals without MPIO make Windows enumerate a single LUN as two disks — its own corruption trap. `Connect-SanPortal` enforces this.

### 3a. Flush the NTFS write cache before every snapshot

An ONTAP snapshot captures blocks as the array sees them, so anything still in the Windows write cache is simply **absent** from the snapshot. You get a crash-consistent image that may mount and then fail `chkdsk`, or silently lose the tail of the `p4 sync`. `New-OntapSnapshot -FlushDriveLetter` issues the `Write-VolumeCache`; do not remove it.

### 4. Clone teardown must not rely on a BuildGraph node

`RunLate="true"` is **not** a BuildGraph `<Node>` attribute, and the semantics it was reaching for do not exist: a node ordered after a **failed** node is *Skipped*. So the `Cleanup Clone` node is a success-only fast path. Guaranteed teardown is registered as a **Horde lease-end hook** (`UE_HORDE_CLEANUP` → `buildgraph/teardown-clone-lun.ps1`), which runs regardless of outcome.

Neither path survives a **hard Spot reclaim**, since both run *on the agent*. If you run agents on Spot — since agents may be reclaimed — add an **off-agent reaper** on a schedule that deletes `build_*` clones whose Horde job is no longer running. A leaked clone pins its parent snapshot, which then makes snapshot rotation fail too.

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

Newly enrolled Sync and Build agents sit **pending** until an operator approves them (Horde UI or `POST /api/v1/enrollment`). Until you do, the pools have no online agents and jobs never lease. `enable_new_agents_by_default` does **not** auto-approve enrollment — it only controls whether an agent is enabled *once approved*; setting it true does not skip this manual approval step. This is done in [runbook step 7](#7-approve-agent-enrollment-in-the-horde-ui).

## Forward-looking notes

- **Narrow the orchestration workspace.** The agent that only parses the BuildGraph XML still syncs the whole stream — ~9 minutes of a ~20-minute job. A workspace-level `view` is **silently ignored** by Horde's Perforce materializer; a Perforce **virtual stream** containing just the bootstrap slice, with the workspace's `stream` pointed at it, should narrow this. Not yet exercised.
- **Off-agent clone reaper for Spot.** On-agent teardown (the `UE_HORDE_CLEANUP` lease hook) does not survive a hard Spot reclaim. If you run agents on Spot, add a scheduled off-agent reaper that deletes `build_*` clones whose Horde job is no longer running (see [appendix §4](#4-clone-teardown-must-not-rely-on-a-buildgraph-node)).

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
<!-- This block is auto-generated by the repo's `terraform-docs` pre-commit hook. Do not edit by hand; run the hook to populate the Requirements / Providers / Modules / Resources / Inputs / Outputs tables. -->
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
