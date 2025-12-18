resource "aws_launch_template" "jenkins_build_farm_launch_template" {
  for_each = var.build_farm_compute

  name_prefix = "${local.name_prefix}-${each.key}-bf-"
  description = "${each.key} build farm launch template."

  image_id      = each.value.ami
  instance_type = each.value.instance_type
  ebs_optimized = each.value.ebs_optimized

  vpc_security_group_ids = [aws_security_group.jenkins_build_farm_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.build_farm_instance_profile.arn
  }
}

resource "aws_autoscaling_group" "jenkins_build_farm_asg" {
  for_each = aws_launch_template.jenkins_build_farm_launch_template

  name = "${local.name_prefix}-${each.key}-build-farm"
  #TODO: parameterize zones for ASG. Currently deploys to same zones as Jenkins service.
  vpc_zone_identifier = var.build_farm_subnets

  launch_template {
    id      = each.value.id
    version = "$Latest"
  }

  # These values are controlled by the EC2 Fleet plugin
  min_size = 0
  max_size = 1

  tag {
    key                 = "ASG"
    value               = each.key
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-${each.key}-build-farm"
    propagate_at_launch = true
  }
}
