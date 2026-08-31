{
  "_comment": [
    "Horde globals.json — rendered by Terraform via templatefile() and passed INLINE to the",
    "Horde module's config_globals_json variable (see main.tf, module \"horde\"). The module's",
    "init container writes the rendered JSON to /app/Data/globals.json; the app loads it because",
    "server.json sets configPath = \"globals.json\" (config_path variable).",
    "",
    "SCHEMA: GlobalConfig version 2 (Horde 5.5). apiVersion 2 confirmed against the live server's",
    "        published schema (GET /api/v1/schema/types/GlobalConfig.json on 5.5.0-32559309).",
    "        perforceClusters is a TOP-LEVEL array on GlobalConfig — NOT nested under plugins.build.",
    "",
    "COUPLINGS (must stay in sync with other files):",
    "  - clusterName \"default\" (and workspaceTypes.cluster \"default\") reference the perforceClusters",
    "    entry named \"default\" defined BELOW in this file.",
    "  - Horde 5.5 resolves the Perforce cluster from globals.json (the loaded GlobalConfig), so the",
    "    cluster MUST be defined here. The module's server.json init-container entry",
    "    (plugins.build.perforce[{ id: \"default\", ... }]) is server appsettings and is NOT used for",
    "    cluster resolution by the stream/workspace clusterName lookup. Previously this file wrongly",
    "    claimed \"the module owns that\" and omitted the cluster — that omission caused Horde to fall",
    "    back to the perforce:1666 default and is the bug this fixes.",
    "  - CREDENTIALS: the cluster sets a NON-SECRET serviceAccount = ${p4_service_account} (the P4",
    "    USERNAME Horde logs in as; injected from local.horde_p4_username / var.horde_p4_service_account_username).",
    "    Per the live GlobalConfig schema, serviceAccount is 'Username for Horde to log in to this server.'",
    "    The PASSWORD/ticket is a secret and is NEVER rendered into this template or into TF state — the",
    "    password is delivered via the module's server.json credentials (plugins.build.perforce). Setting the",
    "    non-null serviceAccount here makes Horde resolve a real P4 user (instead of null -> OS 'root') and",
    "    reuse the server.json password. If the tracer STILL shows a P4 auth/password failure with this user,",
    "    that proves the full credential must live in the cluster, which requires init-container placeholder",
    "    substitution in the MODULE (a module fork) — do NOT hardcode a password here.",
    "  - agentTypes keys \"SyncAgent\" / \"BuildAgent\" MUST match the <Agent Name=\"...\"> attributes in the",
    "    BuildGraph XML files (Phase 4). The JTBD plan uses SyncAgent (type=SyncPool) and BuildAgent",
    "    (type=BuildPool).",
    "  - pool \"name\" fields \"SyncPool\" / \"BuildPool\" MUST match the Horde module agents map's",
    "    horde_pool_name values (main.tf: sync-agent -> \"SyncPool\", build-agent -> \"BuildPool\").",
    "    pool \"id\" fields (sync-pool/build-pool) are internal to this file only.",
    "  - ${perforce_stream} is injected from var.perforce_stream by templatefile().",
    "  - ${perforce_endpoint} is injected from local.perforce_endpoint (ssl:<p4-host>:1666) by",
    "    templatefile() — a template variable, never a hardcoded IP.",
    "  - ${p4_service_account} is injected from local.horde_p4_username (var.horde_p4_service_account_username)",
    "    by templatefile() — a NON-SECRET P4 username, never a password.",
    "",
    "UNCERTAINTIES to validate against a LIVE Horde server in Phase 6:",
    "  1. Pool condition casing/expression syntax (\"OSFamily == 'Linux'\" vs 'OSFamily == \"Windows\"').",
    "  2. -Script= paths (Build/HydratePipeline.xml, Build/BuildPipeline.xml) resolving correctly",
    "     against the stream root once the buildgraph/ files are submitted to depot.",
    "  3. -Target node names (\"Sync And Snapshot\", \"Compile\") matching the actual node/aggregate",
    "     names defined in the BuildGraph XML."
  ],
  "version": 2,
  "perforceClusters": [
    {
      "name": "default",
      "serviceAccount": "${p4_service_account}",
      "servers": [
        { "serverAndPort": "${perforce_endpoint}" }
      ],
      "credentials": [
        { "userName": "__P4_USERNAME__", "password": "__P4_PASSWORD__" }
      ]
    }
  ],
  "storage": {
    "backends": [
      { "id": "default-backend", "type": "FileSystem", "baseDir": "/app/Data/Storage" }
    ],
    "namespaces": [
      { "id": "horde-logs", "backend": "default-backend", "gcFrequencyHrs": 1, "gcDelayHrs": 24 },
      { "id": "horde-artifacts", "backend": "default-backend", "gcFrequencyHrs": 1, "gcDelayHrs": 24 }
    ]
  },
  "pools": [
    { "id": "sync-pool", "name": "SyncPool", "condition": "OSFamily == 'Linux'", "enableAutoscaling": true },
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
              "initialAgentType": "SyncAgent",
              "arguments": [
                "-Script=Build/HydratePipeline.xml",
                "-Target=Sync And Snapshot",
                "-set:Stream=${perforce_stream}",
                "-set:P4Port=${perforce_endpoint}",
                "-set:P4User=${p4_service_account}",
                "-set:FsxAdminIp=${fsx_management_ip}",
                "-set:OntapPasswordSecretName=${ontap_password_secret_name}",
                "-set:VolumeName=${volume_name}",
                "-set:AwsRegion=${aws_region}"
              ],
              "schedule": {
                "enabled": true,
                "patterns": [{ "interval": 60 }]
              }
            },
            {
              "id": "build",
              "name": "Build Pipeline",
              "initialAgentType": "BuildAgent",
              "arguments": [
                "-Script=Build/BuildPipeline.xml",
                "-Target=Compile",
                "-set:Stream=${perforce_stream}",
                "-set:P4Port=${perforce_endpoint}",
                "-set:P4User=${p4_service_account}",
                "-set:SourceVolume=${volume_name}",
                "-set:SnapshotName=hydrate-$${Change}",
                "-set:CloneVolumeName=build-$${Change}",
                "-set:SvmName=${svm_name}",
                "-set:FsxAdminIp=${fsx_management_ip}",
                "-set:OntapPasswordSecretName=${ontap_password_secret_name}",
                "-set:AwsRegion=${aws_region}"
              ]
            }
          ]
        }
      ]
    }
  ]
}
