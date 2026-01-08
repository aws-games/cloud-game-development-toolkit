##########################################
# EBS Volume for Persistent Storage
##########################################
# This volume stores /opt/perforce/swarm/data including the queue directory
# It persists across container and instance restarts
# Tagged so it can be automatically reattached to a new instance if the current one fails

resource "aws_ebs_volume" "swarm_data" {
  #checkov:skip=CKV_AWS_189:Customer-managed KMS key is optional; default AWS encryption enabled
  #checkov:skip=CKV_AWS_3:Encryption is enabled via var.ebs_volume_encrypted (defaults to true)
  availability_zone = local.ebs_availability_zone
  size              = var.ebs_volume_size
  type              = var.ebs_volume_type
  encrypted         = var.ebs_volume_encrypted

  tags = merge(var.tags,
    {
      Name                      = "${local.name_prefix}-data-volume"
      SwarmDataVolume           = "true" # Used by user data script to find this volume
      ModuleIdentifier          = local.module_identifier
      Purpose                   = "perforce-swarm-persistent-storage"
      ManagedBy                 = "terraform"
      AutoAttachToSwarmInstance = "true"
    }
  )

  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}


##########################################
# Launch Template
##########################################
# Defines the EC2 instance configuration for ECS
# Includes user data script that automatically attaches and mounts the EBS volume

resource "aws_launch_template" "swarm_instance" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = local.selected_ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }

  vpc_security_group_ids = [
    aws_security_group.ec2_instance.id,
    aws_security_group.application.id
  ]

  # User data script handles EBS volume attachment, mounting, and Swarm configuration
  user_data = base64encode(templatefile("${path.module}/user-data-native.sh.tpl", {
    region                                  = data.aws_region.current.name
    device_name                             = local.ebs_device_name
    mount_path                              = local.host_data_path
    module_identifier                       = local.module_identifier
    p4d_port                                = var.p4d_port
    p4charset                               = var.p4charset
    swarm_host                              = var.fully_qualified_domain_name
    swarm_redis                             = var.existing_redis_connection != null ? var.existing_redis_connection.host : aws_elasticache_cluster.cluster[0].cache_nodes[0].address
    swarm_redis_port                        = var.existing_redis_connection != null ? tostring(var.existing_redis_connection.port) : tostring(aws_elasticache_cluster.cluster[0].cache_nodes[0].port)
    swarm_force_ext                         = "y"
    enable_sso                              = var.enable_sso ? "true" : "false"
    super_user_username_secret_arn          = var.super_user_username_secret_arn
    super_user_password_secret_arn          = var.super_user_password_secret_arn
    p4_code_review_user_username_secret_arn = var.p4_code_review_user_username_secret_arn
    p4_code_review_user_password_secret_arn = var.p4_code_review_user_password_secret_arn
    config_php_source                       = var.config_php_source
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags,
      {
        Name          = "${local.name_prefix}-instance"
        SwarmInstance = "true"
        ManagedBy     = "terraform"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags,
      {
        Name      = "${local.name_prefix}-root-volume"
        ManagedBy = "terraform"
      }
    )
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-launch-template"
    }
  )
}


##########################################
# Auto Scaling Group
##########################################
# Single-instance ASG provides automatic instance replacement if it fails
# Min=1, Max=1 ensures only one instance runs at a time (Swarm doesn't scale horizontally)

resource "aws_autoscaling_group" "swarm_asg" {
  name_prefix         = "${local.name_prefix}-asg-"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [var.instance_subnet_id]

  target_group_arns = [aws_lb_target_group.alb_target_group.arn]

  launch_template {
    id      = aws_launch_template.swarm_instance.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 600 # 10 minutes for instance to boot, attach volume, and configure Swarm

  # Ensure instance is in the same AZ as the EBS volume
  # availability_zones is set implicitly by vpc_zone_identifier

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "SwarmInstance"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_ebs_volume.swarm_data
  ]
}
