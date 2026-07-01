data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023${local.is_arm64 ? "/arm64" : ""}/recommended/image_id"
}

locals {
  # Detect ARM64 (Graviton) instances by family prefix
  instance_family = split(".", var.instance_type)[0]
  is_arm64        = contains(["c8gd", "c8g", "c7gd", "c7g", "c7gn", "m7g", "m7gd", "m8g", "r7g", "r7gd", "r8g", "t4g", "im4gn", "is4gen", "x2gd", "hpc7g"], local.instance_family)

  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ecs_ami.value
  asg_min_size = var.asg_min_size != null ? var.asg_min_size : (
    var.environment == "prod" ? 1 : 0
  )
  asg_max_size = var.asg_max_size != null ? var.asg_max_size : (
    var.environment == "prod" ? 3 : 1
  )
  asg_desired_size = var.asg_desired_size != null ? var.asg_desired_size : (
    var.environment == "prod" ? 1 : (var.environment == "staging" ? 1 : 0)
  )
}

resource "aws_launch_template" "ecs_instance" {
  name_prefix   = "${var.name_prefix}-ecs-"
  image_id      = local.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  vpc_security_group_ids = [var.server_security_group_id]

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    cluster_name  = aws_ecs_cluster.main.name
    mount_path    = "/srv/urc"
    container_uid = var.container_user
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-ecs-instance" })
  }

  tags = var.tags
}

resource "aws_autoscaling_group" "ecs" {
  name_prefix         = "${var.name_prefix}-ecs-"
  min_size            = local.asg_min_size
  max_size            = local.asg_max_size
  desired_capacity    = local.asg_desired_size
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.ecs_instance.id
    version = "$Latest"
  }

  # Prevent ASG from terminating instances with running tasks
  protect_from_scale_in = true

  # Allow Terraform to delete the ASG without waiting for instance termination.
  # Only affects `terraform destroy` — normal scaling operations are unaffected.
  # Without this, destroy blocks waiting for capacity provider to release
  # termination protection (15+ min due to target tracking alarm evaluation).
  force_delete = true

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    # ECS managed scaling adjusts desired_capacity externally; prevent Terraform from reverting
    ignore_changes = [desired_capacity]
  }
}
