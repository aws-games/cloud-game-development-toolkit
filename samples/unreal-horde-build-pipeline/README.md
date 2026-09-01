# Unreal Horde Build Pipeline

This sample deploys an [Unreal Engine Horde](https://dev.epicgames.com/documentation/en-us/unreal-engine/horde) build farm that compiles from a Perforce stream using [Amazon FSx for NetApp ONTAP](https://aws.amazon.com/fsx/netapp-ontap/) with a thin-clone workspace pattern. Instead of every build agent running a full `p4 sync` from scratch, the pipeline keeps one persistent source workspace warm and hands each build an instant, copy-on-write clone of it.

The core idea has two moving parts. A Linux **Sync Agent** periodically hydrates a persistent source FSxN volume from a Perforce stream and takes an ONTAP snapshot of it. When a build is requested, a Windows **Build Agent** creates an instant [FlexClone](https://docs.netapp.com/us-en/ontap/concepts/flexclone-volumes-concept.html) from the latest snapshot, mounts it, runs an incremental `p4 sync` to catch up any changes since the snapshot, compiles, and then always deletes the clone when it finishes. The result is fast per-build workspaces without repeated full re-syncs, and clones that never leak because cleanup runs even when a build fails.

## Architecture

The sample composes existing CGD Toolkit modules (`modules/perforce`, `modules/unreal/horde`) with sample-owned networking, DNS, storage, and security wiring.

- **VPC** — a 3-tier layout across 2 AZs: public subnets (ALBs / NAT), private application subnets (Horde ECS tasks, Perforce, agents), and private service subnets (FSxN).
- **FSx for NetApp ONTAP** — an NFS-only SVM with a persistent source volume (`p4_workspace`, junction `/p4-workspace`). The source volume is created by Terraform; snapshots and per-build FlexClones are created and destroyed at runtime via the ONTAP REST API from the BuildGraph tasks, not by Terraform.
- **Horde server** — runs on ECS behind an external HTTPS ALB (browser access) and an internal ALB (agent enrollment / in-VPC traffic). Config is rendered from `config/horde/globals.json.tpl` and passed inline to the module.
- **Sync Agent pool** — Linux (Amazon Linux 2023) agents in the Horde pool `SyncPool`. Always-on single instance. Network-optimized instance type.
- **Build Agent pool** — Windows Server 2022 agents in the Horde pool `BuildPool`. Scales from 0 to `build_agent_max_count`. Compute-optimized instance type.
- **Perforce** — the bundled `modules/perforce` P4 Server (private subnet, commit server) is deployed by default. Set `existing_perforce_server_endpoint` to wire the agents to a server you already run and skip the bundled module.
- **Route53** — a private hosted zone (created by this sample) for internal service discovery, plus records in your existing public hosted zone for the Horde HTTPS endpoint.
- **ACM certificate** — DNS-validated against your public hosted zone for the Horde external ALB HTTPS listener.

Two BuildGraph pipelines drive the workflow, and their agent/node names are coupled to `config/horde/globals.json.tpl`:

- `buildgraph/HydratePipeline.xml` — agent `SyncAgent`, node `Sync And Snapshot`, run by the `hydrate` template on `SyncPool`.
- `buildgraph/BuildPipeline.xml` — agent `BuildAgent`, node `Compile` (with `Clone And Mount` and a `RunLate` `Cleanup Clone` node), run by the `build` template on `BuildPool`.

```text
                         Perforce stream (//YourGame/main)
                                     |
                       p4 sync (full, scheduled)
                                     v
     Sync Agent (Linux, SyncPool)  --->  FSxN source volume  --->  ONTAP snapshot
     HydratePipeline.xml                 (/p4-workspace)           (latest)
     node "Sync And Snapshot"                                          |
                                                          instant FlexClone (per build)
                                                                       v
     Build Agent (Windows, BuildPool) --> mount clone (W:) --> incremental p4 sync
     BuildPipeline.xml                                              --> compile UE
     nodes "Clone And Mount" / "Compile" / "Cleanup Clone"          --> delete clone

     Horde server (ECS) -- external HTTPS ALB (deployer /32) --> browser UI
                        -- internal ALB --------------------> agent enrollment
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) and valid AWS credentials for the target account.
- An **existing Route53 public hosted zone** (required). The ACM certificate DNS validation records and the public Horde record are created in this zone. This sample does not create the public zone for you.
- **Epic Games GitHub organization access.** The Horde server image is **pinned by digest to Horde/UE 5.5.0-32559309** for reproducibility (`ghcr.io/epicgames/horde-server@sha256:2a3a3009c05d1dcf4ecbed640d2eb4b5eb9ce974df056e011f476aba4cf5c12d`) so the server version cannot drift. It is pulled from the GitHub Container Registry and requires membership in the Epic Games GitHub organization. Either:
  - provide `github_credentials_secret_arn` — a Secrets Manager secret with GitHub credentials that can read the private image; or
  - override `horde_server_image` with an image you can pull.

  **Why the pin matters:** the custom BuildGraph tasks and the Unreal engine source you sync from Perforce must be the **same UE 5.5 lineage** as the Horde server. If you override `horde_server_image`, use a matching Horde/UE version and keep the tasks and engine source aligned, or builds will break.
- **A pre-created Secrets Manager secret for the Horde P4 user (required when deploying the bundled Perforce).** Create a Secrets Manager secret shaped `{"username":"svc-horde","password":"..."}` and pass its ARN via the `horde_p4_credentials_secret_arn` variable. This sample does **not** create this secret for you. A pre-created secret keeps the ARN a known value at plan time — the Horde module gates its Secrets Manager read policy on a `count` that cannot resolve against an ARN that is only known after apply. (If you set `existing_perforce_server_endpoint` to use your own Perforce server, provide the secret for that server's Horde service account instead.)
- **Custom BuildGraph tasks available to your Unreal build tooling.** The pipelines use custom tasks (`SyncAndSnapshot`, `CloneVolume`, `DeleteVolume`, `DeleteSnapshot`) whose C# sources live in `assets/buildgraph`. You do **not** pre-compile these: when placed in-tree they self-compile in `RunUAT` at job time. See [Seeding Perforce](#seeding-perforce-required-before-first-run) step 3.
- **BuildGraph scripts submitted to the depot.** The `buildgraph/*.xml` files must be submitted to your Perforce depot under `Build/` at the stream root so that the `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` paths in `globals.json` resolve. See [Seeding Perforce](#seeding-perforce-required-before-first-run) step 4.

## Seeding Perforce (required before first run)

This sample deploys the Perforce **server** (or wires the agents to your existing one via `existing_perforce_server_endpoint`) but it does **not** populate the depot. Seeding your Perforce with the Unreal engine source, your game, the custom BuildGraph tasks, and the BuildGraph scripts is your responsibility, and it must be done **before** the pipelines can run. Work through the steps below in order.

### 1. GitHub / Epic access (the #1 gotcha)

To clone the Unreal Engine source you need an Epic Games account with your GitHub account **linked** and the Unreal Engine EULA **accepted** at <https://www.unrealengine.com/en-US/ue-on-github>, and you must authenticate with **that same linked GitHub account's** credentials.

Being a **member** of the `EpicGames` GitHub org is **not** sufficient by itself. Access to the private `EpicGames/UnrealEngine` repo is granted specifically by accepting the UE-on-GitHub agreement with your linked account. A token from an org member who has **not** accepted the agreement returns a bare `404` on the repo (not a permission error), which is easy to misdiagnose.

Use a **classic Personal Access Token** with the `repo` scope, and authorize SSO for the `EpicGames` org on the token if prompted. Verify access before doing anything else:

```bash
git ls-remote https://github.com/EpicGames/UnrealEngine.git
```

If that lists refs, you're good. If it 404s, revisit the EULA acceptance and SSO authorization above.

### 2. Obtain a buildable engine + game tree

Clone `EpicGames/UnrealEngine` at the tag that **matches your Horde server version**. This sample pins Horde to a specific UE 5.5 release (see Prerequisites), so clone the matching engine tag (e.g. a `5.5.x-release` tag) to keep the engine source lineage aligned with the Horde/UAT version. Then run the setup script to fetch the binary GitDependencies — the tree is **not** buildable until this completes (on the order of ~100 GB):

```bash
git clone -b <5.5.x-release-tag> https://github.com/EpicGames/UnrealEngine.git
cd UnrealEngine
./Setup.sh          # Linux/macOS
# Setup.bat         # Windows
```

A sample game (for example, Lyra) ships **in-tree** under `Samples/Games/`, so a single clone yields both the engine and the sample game — you don't need a separate game repo to try the pipeline.

### 3. Place the custom BuildGraph tasks in-tree (UAT auto-compiles them)

Copy the custom tasks, utils, and project file into the engine's AutomationTool directory as their own module, beside the engine's own automation modules (AutomationUtils, BuildGraph, Gauntlet, ...):

```bash
# From the repo root of this sample, into your engine clone:
mkdir -p <engine>/Engine/Source/Programs/AutomationTool/Ontap
cp -r assets/buildgraph/tasks  <engine>/Engine/Source/Programs/AutomationTool/Ontap/
cp -r assets/buildgraph/utils  <engine>/Engine/Source/Programs/AutomationTool/Ontap/
cp assets/buildgraph/CGDT.Ontap.Automation.csproj \
   <engine>/Engine/Source/Programs/AutomationTool/Ontap/
```

The layout should be the `CGDT.Ontap.Automation.csproj` at `.../AutomationTool/Ontap/` with `tasks/` and `utils/` subfolders beside it.

> **Important — place `Ontap/` beside `Scripts/`, NOT inside it.** The engine's
> `AutomationTool/Scripts/AutomationScripts.Automation.csproj` is an SDK-style
> project that compiles **every** `*.cs` under `Scripts/` recursively (it leaves
> `EnableDefaultCompileItems` at its default of `true`). If our task files lived
> under `Scripts/Ontap/`, AutomationScripts would sweep them into its own
> compile — and since AutomationScripts does not reference the BuildGraph
> assembly (and treats warnings as errors), our BuildGraph task types
> (`CustomTask`, `[TaskElement]`, `[TaskParameter]`, `JobContext`) would fail
> with `CS0246`. Every other automation module lives as a sibling directory
> directly under `AutomationTool/`, so `Ontap/` follows that same convention.
> This keeps our sources out of the AutomationScripts glob and requires no
> edits to any Epic-owned file.

You do **not** pre-compile these tasks. `RunUAT` auto-discovers and compiles any `*.Automation.csproj` found under the engine's AutomationTool directory at job time, so the custom tasks self-compile the first time a pipeline runs.

The csproj is SDK-style and targets **`net8.0`**, and it uses **relative `ProjectReference`s** to the engine's `EpicGames.Core`, `EpicGames.Build`, `UnrealBuildTool`, `AutomationUtils`, and `BuildGraph` projects. That is why it must live inside the engine tree at the path above — the relative references resolve against the surrounding engine source. The `BuildGraph` reference is what provides the task API (`CustomTask`, `[TaskElement]`, `[TaskParameter]`, `JobContext`) our tasks build on.

### 4. Place the BuildGraph scripts under `Build/` at the stream root

Copy the pipeline XMLs to a `Build/` directory at the **root of your stream** so the script paths referenced in `globals.json` resolve:

```bash
mkdir -p Build
cp buildgraph/HydratePipeline.xml Build/
cp buildgraph/BuildPipeline.xml   Build/
```

This makes `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` resolve against the stream root at job time.

### 5. Create the stream and submit the tree

On a fresh Perforce, create a **stream depot** and a **mainline stream** that match your `perforce_stream` variable (e.g. depot `YourGame`, stream `//YourGame/main`).

Set a sensible `p4 typemap` **before** submitting a large engine tree, so Perforce does not try to text-delta binaries. A reasonable baseline:

```text
# p4 typemap  (p4 typemap -o | edit | p4 typemap -i)
Typemap:
	binary+l //....uasset
	binary+l //....umap
	binary+F //....pak
	binary+F //....ucas
	binary+F //....utoc
	binary+F //....dll
	binary+F //....pdb
	binary+F //....so
	binary+F //....lib
	binary+F //....exe
	# artifacts / blobs / images / audio / video
	binary+F //....bin
	binary+F //....png
	binary+F //....tga
	binary+F //....wav
	binary+F //....mp4
	# GOTCHA: .rc resource scripts auto-type as text but are often non-UTF8
	# and can abort a submit. Force them (and similar) to binary.
	binary+F //....rc
	binary+F //....ico
	binary+F //....cur
```

Audit `.ico` / `.cur` / `.bin` (and any other non-UTF8 source-tree files) the same way if a submit aborts on a text-encoding error.

Then submit the tree **excluding** `.git` (use a `.p4ignore` containing `.git`). For a ~100 GB tree of hundreds of thousands of files, submit in **batches** (e.g. one top-level directory per changelist) rather than one giant changelist, to avoid client/server memory limits:

```bash
# example: add and submit per top-level directory
p4 add -f "Engine/..." && p4 submit -d "Seed: Engine"
p4 add -f "Samples/..." && p4 submit -d "Seed: Samples"
p4 add -f "Build/..." && p4 submit -d "Seed: BuildGraph scripts"
# ...repeat for remaining top-level directories
```

### 6. .NET on the agents (match your engine)

UE 5.5's UAT compiles the automation csproj at job time targeting **.NET 8**, so the build/sync agents need the **.NET 8 SDK**. This sample's agent configuration installs it. If you run a different UE version, match the .NET SDK version to what your engine's UAT expects.

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
- `fsxn_nfs_endpoint` / `fsxn_source_volume_junction` — mount the source volume as `<nfs_endpoint>:<junction>`.
- `fsxn_management_endpoint` / `fsxn_svm_management_endpoint` — ONTAP REST API targets for the BuildGraph tasks.
- `sync_agent_launch_template_id` / `build_agent_launch_template_id` — launch template IDs for the two agent pools.
- `agent_instance_role_name` — the IAM role attached to agent instances (has the secrets-read policy).
- `horde_p4_credentials_secret_arn` — echoes the pre-created Horde P4 username/password secret ARN you passed in via `horde_p4_credentials_secret_arn` (JSON, sensitive). This sample does not create the secret.
- `fsxn_password_secret_arn` — the FSxN `fsxadmin` password secret (sensitive).
- `agent_config_bucket` — the S3 bucket holding agent configuration playbooks and scripts.

### Align the Perforce `svc-horde` password (required)

The secret you pre-created (and passed via `horde_p4_credentials_secret_arn`) holds the **real
password you chose** for the Horde P4 user (`svc-horde`). Terraform cannot set that password on
the P4 user itself. After the P4 server is up, set the `svc-horde` user's password **on the
server** to match the value already in the secret, or Horde will not be able to authenticate to
Perforce:

```bash
# Confirm the password already stored in your pre-created secret
aws secretsmanager get-secret-value --secret-id <horde_p4_credentials_secret_arn>

# On the P4 server, set the svc-horde user's password to that value
p4 -u <super> passwd svc-horde
```

Rotating one side without the other breaks Horde's Perforce connection.

### Run the pipelines from the Horde UI

Open `horde_server_url` in a browser (from the deployer machine). The `globals.json` config defines a project (`Game Project`) with a stream and two templates:

- **Hydration Pipeline** — runs on a 60-minute schedule (`patterns: [{ interval: 60 }]`). It syncs the stream onto the source FSxN volume and snapshots it. You can also trigger it manually to seed the first snapshot.
- **Build Pipeline** — on-demand. Trigger it from the Horde UI once a snapshot exists; it clones the latest snapshot, syncs incrementally, compiles, and cleans up.

## Security

- **No `0.0.0.0/0` ingress anywhere.** Every ingress rule is scoped to a single-IP `/32`, a referenced security group, or a private VPC CIDR (enforced as a hard invariant in `security.tf`).
- **External ALB locked to the deployer `/32`.** Both the HTTPS listener (443) and the HTTP→HTTPS redirect (80) accept traffic only from `local.my_ip_cidr`.
- **No OIDC auth configured yet.** The Horde module's `auth_method` is intentionally left unset in this sample, so **the `/32` lock is the only access gate** on the Horde UI. Configure OIDC (or another Horde auth method) before widening ALB access beyond your own IP.
- **Internal traffic stays private.** Horde ECS tasks, Perforce, and agents run in private subnets; FSxN accepts NFS/rpcbind/ONTAP-REST only from the agent security group; P4 (1666) is reachable only from the agent SG and the deployer `/32`.

## Known limitations — not yet validated live

The Terraform in this sample validates and plans, but the **end-to-end build has not been run against a live Horde server, FSxN file system, and Unreal engine yet** (that is Phase 6). Treat the following as things to confirm when you deploy. They are also flagged inline in the source (`config/horde/globals.json.tpl` `UNCERTAINTIES` block and the `BuildPipeline.xml` comments):

1. **Windows clone mount command.** `BuildPipeline.xml` mounts the clone with `net use W: \\<Svm>\<CloneVolumeName>`. The exact UNC/NFS path depends on the real SVM export/junction path and DNS name, which are only known against a live SVM. Verify and adjust the mount command.
2. **Unreal compile arguments.** The `Compile` node calls `W:\Engine\Build\BatchFiles\Build.bat` with `UETarget`/`UEPlatform`/`UEConfiguration`/`UEProject`. For a real project build (for example, Lyra, which ships in-tree under `Samples/Games/` — see [Seeding Perforce](#seeding-perforce-required-before-first-run)) set `UEProject` to the `.uproject` path on the mounted clone and confirm the BatchFiles path and target names against your checked-out engine.
3. **Horde `globals.json` schema.** The pool conditions (`OSFamily == 'Linux'` / `'Windows'`) casing and the legacy top-level (version 1) vs. newer nested schema may need adjustment for your deployed Horde server version.
4. **`-Script` depot paths.** `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` resolve against the stream root only once the `buildgraph/` files are submitted to the depot under `Build/` (see [Seeding Perforce](#seeding-perforce-required-before-first-run) step 4). Confirm the paths resolve after submitting.
5. **P4 server `db-pt` directory ownership.** On the P4 Server the metadata directory that holds the `db.*` files (the `db-pt`/metadata path) can end up owned by `root` rather than the `perforce` user (for example after a manual restore or an out-of-band operation as root). If the P4 daemon runs as `perforce` but the metadata dir is root-owned, `p4d` fails to open/write its database files. Confirm the metadata directory and its contents are owned by the `perforce` user (recursively) and fix ownership if a P4 operation reports a permission/DB error.
6. **Agent P4 SSL trust.** The Perforce endpoint is SSL (`ssl:<host>:1666`). Before an agent can run `p4` commands against it, the agent's OS user must trust the server's SSL fingerprint (`p4 trust -y`) and then authenticate (`p4 login`). The Linux **sync agent** now establishes this trust automatically: `config/sync-agent.ansible.yml` runs `p4 trust -y` as the `Horde` agent user (writing `/home/Horde/.p4trust`) at provisioning, using the `p4_port` value passed by the sync-agent SSM association. A `p4 login` (authentication) is still performed at job time by the BuildGraph task using the Secrets Manager credentials. The **Windows build agent** trusts the fingerprint via its setup script. If you wire an external Perforce endpoint whose `P4PORT` is unknown at apply time, the sync agent skips the trust step (null-safe) and you must ensure trust is established for the agent user out of band.

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
<!-- This block is auto-generated by the repo's `terraform-docs` pre-commit hook. Do not edit by hand; run the hook to populate the Requirements / Providers / Modules / Resources / Inputs / Outputs tables. -->
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
