################################################################################
# SSM Document for Multi-Region ScyllaDB Keyspace Configuration
################################################################################

# SSM Document for Multi-Region Keyspace Configuration
# Created by SECONDARY region when connecting to existing primary
resource "aws_ssm_document" "scylla_keyspace_update" {
  count           = var.scylla_config != null && !var.create_seed_node ? 1 : 0
  name            = "${local.name_prefix}-scylla-keyspace-update"
  document_format = "YAML"
  document_type   = "Command"
  
  content = <<DOC
schemaVersion: '1.2'
description: Alter the keyspaces for multi-region ScyllaDB replication.
runtimeConfig:
  aws:runShellScript:
    properties:
      - id: 0.aws:runShellScript
        runCommand:
          - |
            # Wait for both regions' keyspaces to exist
            sleep 30
            # Configure primary region keyspace
            cqlsh ${var.existing_scylla_seed} --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.scylla_source_region, "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${var.scylla_source_region == "us-east-1" ? "us-east" : var.scylla_source_region}': 2, '${var.region == "us-east-1" ? "us-east" : var.region}': 0};" || true
            # Configure secondary region keyspace  
            cqlsh ${var.existing_scylla_seed} --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.region, "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${var.region == "us-east-1" ? "us-east" : var.region}': 2, '${var.scylla_source_region == "us-east-1" ? "us-east" : var.scylla_source_region}': 0};" || true
DOC
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-keyspace-update"
  })
}