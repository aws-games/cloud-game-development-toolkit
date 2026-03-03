################################################################################
# Scylla Instances
################################################################################

# SCYLLA CLOUDWATCH AGENT ISSUE
#
# Problem:
# ScyllaDB instances fail to start when centralized logging is enabled due to CloudWatch agent dependency failures.
#
# Root Cause:
# When `enable_centralized_logging = true`, the module installs CloudWatch agent on ScyllaDB instances via user data:
#   yum install -y amazon-cloudwatch-agent
#   systemctl enable amazon-cloudwatch-agent
#
# This causes systemd dependency failures:
#   systemd[1]: Dependency failed for Scylla Server.
#   systemd[1]: scylla-server.service: Job scylla-server.service/start failed with result 'dependency'.
#
# Impact:
# - ScyllaDB service won't start (port 9042 unavailable)
# - DDC application pods crash with connection refused errors
# - Deployment fails after ~30+ minutes of timeouts
#
# Solution:
# Disabled CloudWatch agent installation for ScyllaDB instances only:
# File: modules/unreal/unreal-cloud-ddc/modules/ddc-infra/locals.tf
#   scylla_logging_enabled = false  # Disabled due to CloudWatch agent dependency issues
#
# Result:
# - ScyllaDB starts successfully without CloudWatch agent
# - Other services (EKS, NLB, DDC app) retain centralized logging
# - DDC deployment completes successfully
#
# Future Fix Options:
#
# 1. Delay CloudWatch Agent Startup
# Modify user data to configure CloudWatch agent but prevent immediate startup:
#   # Install but don't start immediately
#   yum install -y amazon-cloudwatch-agent
#   systemctl disable amazon-cloudwatch-agent
#   
#   # Create systemd override to depend on scylla-server
#   mkdir -p /etc/systemd/system/amazon-cloudwatch-agent.service.d
#   cat > /etc/systemd/system/amazon-cloudwatch-agent.service.d/override.conf << EOF
#   [Unit]
#   After=scylla-server.service
#   Requires=scylla-server.service
#   EOF
#   
#   systemctl daemon-reload
#   systemctl enable amazon-cloudwatch-agent
#
# 2. Use Systems Manager Quick Setup
# Deploy CloudWatch agent via SSM after instance boot:
# - Avoids boot-time dependency conflicts
# - Automated through SSM agent
# - Better lifecycle management
#
# 3. Custom Log Collection Script
# Replace CloudWatch agent with lightweight log shipper:
#   #!/bin/bash
#   # Simple log shipper that doesn't interfere with systemd
#   aws logs put-log-events --log-group-name "${log_group}" \
#     --log-stream-name "${instance_id}-scylla" \
#     --log-events file:///var/log/scylla/scylla.log
#
# 4. Custom AMI (Recommended)
# Bake CloudWatch agent into custom ScyllaDB AMI:
# - Pre-configure systemd dependencies correctly
# - Ensure clean boot every time
# - Most robust and repeatable solution
# - Handle complex AMI environments properly
resource "aws_instance" "scylla_ec2_instance_seed" {
  count  = var.scylla_config != null && var.create_seed_node ? length([var.scylla_subnets[0]]) : 0
  region = var.region

  ami                    = data.aws_ami.scylla_ami.id
  instance_type          = var.scylla_instance_type
  vpc_security_group_ids = [aws_security_group.scylla_security_group.id]
  monitoring             = true

  subnet_id = element(var.scylla_subnets, count.index)

  user_data                   = local.scylla_user_data_primary_node
  user_data_replace_on_change = false
  ebs_optimized               = true

  iam_instance_profile = aws_iam_instance_profile.scylla_instance_profile[0].name
  
  # Ensure proper destroy order - instances depend on IGW for internet access
  # and security group rules for proper cleanup sequence
  depends_on = [
    var.internet_gateway_id,
    aws_vpc_security_group_ingress_rule.self_ingress_sg_rules
  ]
  
  lifecycle {
    ignore_changes = [user_data]
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    throughput  = var.scylla_db_throughput
    volume_size = var.scylla_db_storage
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-db"
    }
  )
}

resource "aws_instance" "scylla_ec2_instance_other_nodes" {
  count  = var.scylla_config != null ? (var.create_seed_node ? var.scylla_replication_factor - 1 : var.scylla_replication_factor) : 0
  region = var.region

  ami                    = data.aws_ami.scylla_ami.id
  instance_type          = var.scylla_instance_type
  vpc_security_group_ids = [aws_security_group.scylla_security_group.id]
  monitoring             = true

  subnet_id = element(var.scylla_subnets, count.index + 1)

  user_data                   = local.scylla_user_data_other_nodes
  user_data_replace_on_change = false
  ebs_optimized               = true

  iam_instance_profile = aws_iam_instance_profile.scylla_instance_profile[0].name
  
  # Ensure proper destroy order - instances depend on IGW for internet access
  # and security group rules for proper cleanup sequence
  depends_on = [
    var.internet_gateway_id,
    aws_vpc_security_group_ingress_rule.self_ingress_sg_rules
  ]
  
  lifecycle {
    ignore_changes = [user_data]
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    throughput  = var.scylla_db_throughput
    volume_size = var.scylla_db_storage
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-db"
    }
  )
}
