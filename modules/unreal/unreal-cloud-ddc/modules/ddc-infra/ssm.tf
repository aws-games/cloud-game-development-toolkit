################################################################################
# SSM Document for Multi-Region ScyllaDB Keyspace Configuration
################################################################################

# SSM Document for Multi-Region Keyspace Configuration
# Created by SECONDARY region when connecting to existing primary
resource "aws_ssm_document" "scylla_keyspace_update" {
  count           = !var.create_seed_node ? 1 : 0
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
            cqlsh ${var.existing_scylla_seed} --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.scylla_source_region, "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.scylla_source_region, "-1", "")}': 2, '${replace(var.region, "-1", "")}': 0};" || true
            # Configure secondary region keyspace  
            cqlsh ${var.existing_scylla_seed} --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.region, "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.region, "-1", "")}': 2, '${replace(var.scylla_source_region, "-1", "")}': 0};" || true
DOC
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-keyspace-update"
  })
}

################################################################################
# SSM Document for Keyspace Replication Fix (Multi-Region)
################################################################################

# Fix keyspace replication after DDC creates keyspaces with wrong datacenter names
resource "aws_ssm_document" "scylla_keyspace_replication_fix" {
  count           = !var.create_seed_node ? 1 : 0  # Only create on secondary regions
  name            = "${local.name_prefix}-scylla-keyspace-replication-fix"
  document_format = "YAML"
  document_type   = "Command"
  
  content = <<DOC
schemaVersion: '1.2'
description: Fix keyspace replication for multi-region ScyllaDB after DDC deployment.
runtimeConfig:
  aws:runShellScript:
    properties:
      - id: 0.aws:runShellScript
        runCommand:
          - |
            # Wait for DDC to create keyspaces
            sleep 30
            
            # Get datacenter names using EC2Snitch format (strip AZ numbers)
            PRIMARY_DC="${var.scylla_source_region != null ? regex("^([^-]+-[^-]+)", var.scylla_source_region)[0] : ""}"
            SECONDARY_DC="${regex("^([^-]+-[^-]+)", var.region)[0]}"
            
            # Fix primary region keyspace replication
            if [ -n "$PRIMARY_DC" ]; then
              cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.scylla_source_region, "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '$PRIMARY_DC': 2, '$SECONDARY_DC': 0};" || true
            fi
            
            # Fix secondary region keyspace replication
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.region, "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '$SECONDARY_DC': 2, '$PRIMARY_DC': 0};" || true
DOC
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-keyspace-replication-fix"
  })
}

