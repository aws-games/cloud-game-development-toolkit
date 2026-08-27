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
- **Epic Games GitHub organization access.** The default Horde server image `ghcr.io/epicgames/horde-server:latest-bundled` is pulled from the GitHub Container Registry and requires membership in the Epic Games GitHub organization. Either:
  - provide `github_credentials_secret_arn` — a Secrets Manager secret with GitHub credentials that can read the private image; or
  - override `horde_server_image` with an image you can pull without authentication.
- **A pre-created Secrets Manager secret for the Horde P4 user (required when deploying the bundled Perforce).** Create a Secrets Manager secret shaped `{"username":"svc-horde","password":"..."}` and pass its ARN via the `horde_p4_credentials_secret_arn` variable. This sample does **not** create this secret for you. A pre-created secret keeps the ARN a known value at plan time — the Horde module gates its Secrets Manager read policy on a `count` that cannot resolve against an ARN that is only known after apply. (If you set `existing_perforce_server_endpoint` to use your own Perforce server, provide the secret for that server's Horde service account instead.)
- **Custom BuildGraph tasks compiled into your Unreal build tooling.** The pipelines use custom tasks (`SyncAndSnapshot`, `CloneVolume`, `DeleteVolume`, `DeleteSnapshot`) whose C# sources live in `assets/buildgraph/tasks`. These must be compiled into your Unreal `AutomationTool`/`UnrealBuildTool` so BuildGraph recognizes them.
- **BuildGraph scripts submitted to the depot.** The `buildgraph/*.xml` files must be submitted to your Perforce depot under `Build/` so that the `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` paths in `globals.json` resolve against the stream root.

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
2. **Unreal compile arguments.** The `Compile` node calls `W:\Engine\Build\BatchFiles\Build.bat` with `UETarget`/`UEPlatform`/`UEConfiguration`/`UEProject`. For a real project build (for example, Lyra) set `UEProject` to the `.uproject` path on the mounted clone and confirm the BatchFiles path and target names against your checked-out engine.
3. **Horde `globals.json` schema.** The pool conditions (`OSFamily == 'Linux'` / `'Windows'`) casing and the legacy top-level (version 1) vs. newer nested schema may need adjustment for your deployed Horde server version.
4. **`-Script` depot paths.** `-Script=Build/HydratePipeline.xml` and `-Script=Build/BuildPipeline.xml` resolve against the stream root only once the `buildgraph/` files are submitted to the depot under `Build/`. Confirm the paths resolve after submitting.

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
<!-- This block is auto-generated by the repo's `terraform-docs` pre-commit hook. Do not edit by hand; run the hook to populate the Requirements / Providers / Modules / Resources / Inputs / Outputs tables. -->
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
