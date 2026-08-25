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
    "  - clusterName \"default\" references the Perforce connection the module renders in server.json",
    "    (local.server_json -> Horde.plugins.build.perforce[{ id: \"default\", serverAndPort, credentials }]).",
    "    Do NOT redefine perforceClusters/credentials here — the module owns that.",
    "  - agentTypes keys \"SyncAgent\" / \"BuildAgent\" MUST match the <Agent Name=\"...\"> attributes in the",
    "    BuildGraph XML files (Phase 4). The JTBD plan uses SyncAgent (type=SyncPool) and BuildAgent",
    "    (type=BuildPool).",
    "  - pool \"name\" fields \"SyncPool\" / \"BuildPool\" MUST match the Horde module agents map's",
    "    horde_pool_name values (main.tf: sync-agent -> \"SyncPool\", build-agent -> \"BuildPool\").",
    "    pool \"id\" fields (sync-pool/build-pool) are internal to this file only.",
    "  - ${perforce_stream} is injected from var.perforce_stream by templatefile().",
    "",
    "UNCERTAINTIES to validate against a LIVE Horde server in Phase 6:",
    "  1. Pool condition casing/expression syntax (\"OSFamily == 'Linux'\" vs 'OSFamily == \"Windows\"').",
    "  2. Legacy top-level schema vs newer nested schema for this Horde server version.",
    "  3. -Script= paths (Build/HydratePipeline.xml, Build/BuildPipeline.xml) resolving correctly",
    "     against the stream root once the buildgraph/ files are submitted to depot.",
    "  4. -Target node names (\"Sync And Snapshot\", \"Compile\") matching the actual node/aggregate",
    "     names defined in the BuildGraph XML."
  ],
  "version": 1,
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
              "arguments": [
                "-Script=Build/HydratePipeline.xml",
                "-Target=Sync And Snapshot"
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
                "-Target=Compile"
              ]
            }
          ]
        }
      ]
    }
  ]
}
