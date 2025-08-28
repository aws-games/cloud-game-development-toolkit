#################################################
# SSM Associations for P4 Replica Configuration
#################################################

# Configure primary server for replication
resource "aws_ssm_association" "configure_primary" {
  count = length(var.p4_server_replicas_config) > 0 ? 1 : 0
  
  name = "AWS-RunShellScript"
  
  targets {
    key    = "InstanceIds"
    values = [module.p4_server[0].instance_id]
  }
  
  parameters = {
    commands = join("\n", [
      "aws s3 cp s3://${aws_s3_bucket.p4_server_config_scripts[0].id}/configure_primary_for_replicas.sh /tmp/",
      "chmod +x /tmp/configure_primary_for_replicas.sh",
      "/tmp/configure_primary_for_replicas.sh"
    ])
  }
  
  depends_on = [
    module.p4_server,
    aws_s3_object.configure_primary_script
  ]

  tags = var.tags
}

# TODO: Remove test SSM execution after functionality is verified
# Test SSM execution on primary server
resource "aws_ssm_association" "test_ssm_primary" {
  count = length(var.p4_server_replicas_config) > 0 ? 1 : 0
  
  name = "AWS-RunShellScript"
  
  targets {
    key    = "InstanceIds"
    values = [module.p4_server[0].instance_id]
  }
  
  parameters = {
    commands = join("\n", [
      "aws s3 cp s3://${aws_s3_bucket.p4_server_config_scripts[0].id}/test_ssm_execution.sh /tmp/",
      "chmod +x /tmp/test_ssm_execution.sh",
      "/tmp/test_ssm_execution.sh"
    ])
  }
  
  depends_on = [
    module.p4_server,
    aws_s3_object.test_ssm_script
  ]

  tags = var.tags
}

# Configure replica servers
resource "aws_ssm_association" "configure_replicas" {
  for_each = var.p4_server_replicas_config
  
  name = "AWS-RunShellScript"
  
  targets {
    key    = "InstanceIds"
    values = [module.p4_server_replicas[each.key].instance_id]
  }
  
  parameters = {
    commands = join("\n", [
      # TODO: Remove test execution lines after SSM functionality is verified
      "aws s3 cp s3://${aws_s3_bucket.p4_server_config_scripts[0].id}/test_ssm_execution.sh /tmp/",
      "chmod +x /tmp/test_ssm_execution.sh",
      "/tmp/test_ssm_execution.sh",
      "aws s3 cp s3://${aws_s3_bucket.p4_server_config_scripts[0].id}/configure_replica.sh /tmp/",
      "chmod +x /tmp/configure_replica.sh",
      "/tmp/configure_replica.sh ${var.p4_server_config.fully_qualified_domain_name} ${each.value.replica_type}"
    ])
  }
  
  depends_on = [
    aws_ssm_association.configure_primary,
    aws_s3_object.configure_replica_script,
    aws_s3_object.test_ssm_script
  ]

  tags = var.tags
}