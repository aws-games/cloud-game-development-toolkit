########################################
# SSM Document for ScyllaDB Keyspace Replication Fix
########################################

# SSM document to fix DDC keyspace replication strategy
# Follows cwwalb approach with dynamic configuration
resource "aws_ssm_document" "scylla_keyspace_replication_fix" {
  count = var.ddc_infra_config != null ? 1 : 0
  
  name          = "${local.name_prefix}-scylla-keyspace-fix"
  document_type = "Command"
  document_format = "YAML"
  
  content = <<DOC
schemaVersion: '2.2'
description: 'Fix DDC keyspace replication strategy for ${local.scylla_config.keyspace_name}'
parameters:
  executionTimeout:
    type: String
    default: '3600'
    description: 'Timeout for the execution in seconds'
mainSteps:
  - action: aws:runShellScript
    name: fixKeyspaceReplication
    inputs:
      timeoutSeconds: '{{ executionTimeout }}'
      runCommand:
        - |
          echo "Starting ScyllaDB keyspace replication fix for ${local.scylla_config.keyspace_name}"
          echo "Target replication map: ${jsonencode(local.scylla_config.replication_map)}"
          
          # Retry configuration
          MAX_ATTEMPTS=${var.ssm_retry_config.max_attempts}
          RETRY_INTERVAL=${var.ssm_retry_config.retry_interval_seconds}
          INITIAL_DELAY=${var.ssm_retry_config.initial_delay_seconds}
          
          echo "Retry configuration: max_attempts=$MAX_ATTEMPTS, retry_interval=$RETRY_INTERVAL, initial_delay=$INITIAL_DELAY"
          
          # Initial delay for DDC startup
          echo "Waiting $INITIAL_DELAY seconds for DDC initial startup..."
          sleep $INITIAL_DELAY
          
          # Retry logic for DDC keyspace initialization
          ATTEMPT=1
          SUCCESS=false
          
          while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$SUCCESS" = "false" ]; do
            echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking DDC keyspace initialization..."
            
            # Check if keyspace exists
            if cqlsh --request-timeout=30 -e "DESCRIBE KEYSPACE ${local.scylla_config.keyspace_name};" 2>/dev/null >/dev/null; then
              echo "Keyspace ${local.scylla_config.keyspace_name} found - DDC is ready!"
              SUCCESS=true
              break
            else
              echo "Keyspace ${local.scylla_config.keyspace_name} not found yet (attempt $ATTEMPT/$MAX_ATTEMPTS)"
              
              if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                echo "Waiting $RETRY_INTERVAL seconds before next attempt..."
                sleep $RETRY_INTERVAL
              fi
              ATTEMPT=$((ATTEMPT + 1))
            fi
          done
          
          if [ "$SUCCESS" = "false" ]; then
            echo "ERROR: DDC keyspace ${local.scylla_config.keyspace_name} failed to initialize within timeout period"
            echo "Troubleshooting steps:"
            echo "1. Check DDC pod logs: kubectl logs -n unreal-cloud-ddc -l app.kubernetes.io/name=unreal-cloud-ddc"
            echo "2. Check ScyllaDB connectivity: cqlsh -e 'DESCRIBE KEYSPACES;'"
            echo "3. Verify DDC configuration and secrets"
            echo "4. Check if DDC service is running and healthy"
            exit 1
          fi
          
          echo "Keyspace ${local.scylla_config.keyspace_name} found. Starting replication fixes..."
          
          # Execute progressive ALTER commands (cwwalb style)
          %{~ for i, cmd in local.scylla_config.alter_commands ~}
          echo "Step ${i + 1}/${length(local.scylla_config.alter_commands)}: ${cmd}"
          if ! cqlsh --request-timeout=120 -e "${cmd}"; then
            echo "ERROR: Failed to execute ALTER command: ${cmd}"
            exit 1
          fi
          sleep 2  # Brief pause between commands
          %{~ endfor ~}
          
          # Verify final replication configuration
          echo "Verifying final replication configuration..."
          cqlsh --request-timeout=30 -e "SELECT keyspace_name, replication FROM system_schema.keyspaces WHERE keyspace_name = '${local.scylla_config.keyspace_name}';"
          
          echo "ScyllaDB keyspace replication fix completed successfully!"
          echo "Final replication map: ${jsonencode(local.scylla_config.replication_map)}"
DOC

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-keyspace-fix"
    Type = "ScyllaDB Keyspace Fix"
    Region = var.region
  })
}

# SSM association to run the keyspace fix on ScyllaDB seed node
resource "aws_ssm_association" "scylla_keyspace_replication_fix" {
  count = var.ddc_infra_config != null && try(var.ddc_infra_config.create_seed_node, true) == true ? 1 : 0
  
  name = aws_ssm_document.scylla_keyspace_replication_fix[0].name
  
  targets {
    key    = "InstanceIds"
    values = [module.ddc_infra[0].scylla_seed_instance_id]
  }
  
  # Run after DDC services are deployed
  depends_on = [
    module.ddc_services
  ]
  
  # Association configuration
  association_name = "${local.name_prefix}-scylla-keyspace-fix"
  max_concurrency = "1"
  max_errors      = "0"
  
  # Run once on creation, then manual execution only
  # schedule_expression = ""  # No automatic schedule - commented out since empty string not allowed
  
  dynamic "output_location" {
    for_each = local.logs_bucket_id != null ? [1] : []
    content {
      s3_bucket_name = local.logs_bucket_id
      s3_key_prefix  = "ssm-associations/scylla-keyspace-fix"
    }
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-keyspace-fix-association"
    Type = "SSM Association"
    Region = var.region
  })
}

########################################
# Outputs for debugging
########################################

# Output the generated ALTER commands for debugging
output "scylla_alter_commands" {
  description = "Generated ALTER commands for ScyllaDB keyspace replication"
  value = var.ddc_infra_config != null ? {
    keyspace_name = local.scylla_config.keyspace_name
    datacenter_name = local.scylla_config.current_datacenter
    replication_map = local.scylla_config.replication_map
    alter_commands = local.scylla_config.alter_commands
    is_multi_region = local.scylla_config.is_multi_region
  } : null
}