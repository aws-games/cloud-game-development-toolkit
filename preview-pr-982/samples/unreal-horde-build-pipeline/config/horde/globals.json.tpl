{
  "_comment": [
    "Horde globals.json — rendered by Terraform via templatefile() and passed INLINE to the",
    "Horde module's config_globals_json variable (see main.tf, module \"horde\"). The module's",
    "init container writes the rendered JSON to /app/Data/globals.json; the app loads it because",
    "server.json sets configPath = \"globals.json\" (config_path variable).",
    "",
    "SCHEMA: legacy top-level form (version 1) for compatibility.",
    "",
    "COUPLINGS (must stay in sync with other files):",
    "  - clusterName \"default\" references the perforceClusters entry DEFINED IN THIS FILE (below).",
    "    The Horde stream POLLER authenticates from globals.json perforceClusters[].credentials — NOT",
    "    from server.json (whose plugins.build.perforce creds are only for the SERVER reading config",
    "    files). With no perforceClusters block, the poller falls back to a synthesized ambient Default",
    "    cluster with NO credentials and fails (the failure PR #981 fixed). So we DO define it here.",
    "    The password is delivered via the literal __P4_PASSWORD__ token, which the module's init",
    "    container substitutes from var.horde_p4_credentials_secret_arn at CONTAINER STARTUP (after",
    "    cat-ing the file to the [INIT] log) — so the real password never lands in Terraform state,",
    "    the ECS task definition, or CloudWatch logs. The cluster name MUST stay \"default\" so the",
    "    streams' clusterName resolves to it.",
    "  - agentTypes keys \"SyncAgent\" / \"BuildAgent\" MUST match the <Agent Name=\"...\"> attributes in the",
    "    BuildGraph XML files (Phase 4). The JTBD plan uses SyncAgent (type=SyncPool) and BuildAgent",
    "    (type=BuildPool).",
    "  - pool \"name\" fields \"SyncPool\" / \"BuildPool\" MUST match the Horde module agents map's",
    "    horde_pool_name values (main.tf: sync-agent -> \"SyncPool\", build-agent -> \"BuildPool\").",
    "    pool \"id\" fields (sync-pool/build-pool) are internal to this file only.",
    "  - BOTH POOLS ARE NOW WINDOWS. SyncPool changed from Linux with the move to iSCSI: the",
    "    source LUN carries NTFS, so its writer must be Windows AND must be the only writer.",
    "    That is enforced, not just documented - hydrate-source-lun.ps1 registers its IQN with",
    "    -SingleHost and FAILS if the source igroup already holds a different initiator.",
    "  - ${perforce_stream} is injected from var.perforce_stream by templatefile().",
    "  - The -set: arguments below inject the ONTAP/FSxN values the BuildGraph <Option>s declare.",
    "    These Options have NO DefaultValue, so omitting them fails the run at graph-parse time,",
    "    not at the ONTAP call. Every $${...} interpolation here must be supplied by templatefile() in",
    "    main.tf - adding an Option to the XML means adding it in BOTH places.",
    "",
    "  - DELIBERATELY NOT SET HERE (they are per-run, not per-deployment):",
    "      * SnapshotName        - which snapshot to clone; picked per build (ADR-003: highest",
    "                              cl-{N} <= the target changelist).",
    "      * SnapshotChangelist  - the {N} of that snapshot. REQUIRED: it is what makes the",
    "                              build agent's 'p4 flush' correct, and therefore what makes the",
    "                              incremental sync actually incremental.",
    "      * CloneVolumeName     - must be unique per build, so scope it to the job id.",
    "                              NOTE: ONTAP volume names reject hyphens, so 'build-{jobId}'",
    "                              fails with an opaque 400; use 'build_{jobid}', lowercased.",
    "    Supply these per job (template parameters / job arguments), not as static config.",
    "",
    "UNCERTAINTIES to validate against a LIVE Horde server:",
    "  1. Pool condition casing/expression syntax for \"OSFamily == 'Windows'\".",
    "  2. Legacy top-level schema vs newer nested schema for this Horde server version.",
    "  3. -Script= paths (Build/HydratePipeline.xml, Build/BuildPipeline.xml) resolving correctly",
    "     against the stream root once the buildgraph/ files are submitted to depot.",
    "  4. -Target node names (\"Sync And Snapshot\", \"Compile\") matching the actual node/aggregate",
    "     names defined in the BuildGraph XML."
  ],
  "version": 1,
  "perforceClusters": [
    {
      "name": "default",
      "serviceAccount": "${p4_user}",
      "servers": [ { "serverAndPort": "${p4_port}" } ],
      "credentials": [ { "userName": "${p4_user}", "password": "__P4_PASSWORD__" } ]
    }
  ],
  "pools": [
    { "id": "sync-pool", "name": "SyncPool", "condition": "OSFamily == 'Windows'", "enableAutoscaling": true },
    { "id": "build-pool", "name": "BuildPool", "condition": "OSFamily == 'Windows'", "enableAutoscaling": true }
  ],
  "projects": [
    {
      "id": "game-project",
      "name": "Game Project",
      "streams": [
        {
          "id": "main",
          "name": "${perforce_stream}",
          "clusterName": "default",
          "agentTypes": {
            "SyncAgent": { "pool": "sync-pool", "workspace": "SyncWorkspace" },
            "BuildAgent": { "pool": "build-pool", "workspace": "BuildWorkspace" }
          },
          "workspaceTypes": {
            "SyncWorkspace": { "cluster": "default", "incremental": true },
            "BuildWorkspace": { "cluster": "default", "incremental": true }
          },
          "templates": [
            {
              "id": "hydrate",
              "name": "Hydration Pipeline",
              "arguments": [
                "-Script=Build/HydratePipeline.xml",
                "-Target=Sync And Snapshot",
                "-set:Stream=${perforce_stream}",
                "-set:VolumeName=${fsxn_source_volume_name}",
                "-set:LunName=${fsxn_lun_name}",
                "-set:LunSize=${fsxn_lun_size}",
                "-set:HydratorIgroup=${fsxn_hydrator_igroup}",
                "-set:IscsiPortals=${fsxn_iscsi_portals}",
                "-set:SourceMountDrive=${fsxn_source_drive_letter}",
                "-set:FsxAdminIp=${fsxn_management_ip}",
                "-set:OntapPasswordSecretName=${fsxn_admin_secret_name}",
                "-set:SvmName=${fsxn_svm_name}",
                "-set:AwsRegion=${aws_region}",
                "-set:P4Port=${p4_port}",
                "-set:P4User=${p4_user}"
              ],
              "schedule": {
                "enabled": true,
                "patterns": [{ "interval": 60 }]
              }
            },
            {
              "id": "build",
              "name": "Build Pipeline",
              "arguments": [
                "-Script=Build/BuildPipeline.xml",
                "-Target=Compile",
                "-set:Stream=${perforce_stream}",
                "-set:SourceVolume=${fsxn_source_volume_name}",
                "-set:LunName=${fsxn_lun_name}",
                "-set:AgentIgroup=${fsxn_agent_igroup}",
                "-set:IscsiPortals=${fsxn_iscsi_portals}",
                "-set:CloneMountDrive=${fsxn_clone_drive_letter}",
                "-set:SvmName=${fsxn_svm_name}",
                "-set:FsxAdminIp=${fsxn_management_ip}",
                "-set:OntapPasswordSecretName=${fsxn_admin_secret_name}",
                "-set:AwsRegion=${aws_region}",
                "-set:P4Port=${p4_port}",
                "-set:P4User=${p4_user}"
              ]
            }
          ]
        }
      ]
    }
  ]
}
