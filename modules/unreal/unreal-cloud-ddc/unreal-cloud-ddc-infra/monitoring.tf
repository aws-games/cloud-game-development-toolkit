resource "aws_iam_instance_profile" "scylla_monitoring_profile" {
  count = var.create_scylla_monitoring_stack ? 1 : 0
  name  = "scylla-monitoring-profile"
  role  = aws_iam_role.scylla_monitoring_role[count.index].name
}


# Instance size calculation for 2 node scylla cluster
# 2 nodes * 8 vcpu * 15 day retention period * 12 MB = 2.88 GB

#Scylla monitoring instance
resource "aws_instance" "scylla_monitoring" {
  count                       = var.create_scylla_monitoring_stack ? 1 : 0
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.xlarge"
  subnet_id                   = element(var.scylla_subnets, count.index + 1)
  vpc_security_group_ids      = [aws_security_group.scylla_monitoring_sg[count.index].id]
  key_name                    = "unreal-ddc-cgd"
  user_data                   = local.scylla_monitoring_user_data
  user_data_replace_on_change = false
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.scylla_monitoring_profile[count.index].name
  monitoring                  = true
  root_block_device {
    volume_size = 50
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "scylla-monitoring"
  }
}

########################################
# Scylla Monitoring Load Balancer
########################################

# Network Load Balancer for Scylla Monitoring
resource "aws_lb" "scylla_monitoring_nlb" {
  count                            = var.create_scylla_monitoring_stack ? 1 : 0
  name                             = "scylla-monitoring-nlb"
  load_balancer_type               = "network"
  subnets                          = var.monitoring_lb_subnets
  security_groups                  = [aws_security_group.scylla_monitoring_lb_sg[count.index].id]
  enable_cross_zone_load_balancing = true
  #checkov:skip=CKV2_AWS_20:Keeping for early development
  dynamic "access_logs" {
    for_each = var.enable_scylla_monitoring_lb_access_logs ? [1] : []
    content {
      enabled = var.enable_scylla_monitoring_lb_access_logs
      bucket  = var.scylla_monitoring_lb_access_logs_bucket != null ? var.scylla_monitoring_lb_access_logs_bucket : aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
      prefix  = var.scylla_monitoring_lb_access_logs_prefix != null ? var.scylla_monitoring_lb_access_logs_prefix : "${var.name}-alb"
    }
  }
  #checkov:skip=CKV_AWS_150:Deletion protection disabled by default
  enable_deletion_protection = var.enable_scylla_monitoring_lb_deletion_protection
  tags = {
    Name = "scylla-monitoring-nlb"
  }
}

resource "aws_lb_target_group" "scylla_monitoring_nlb_target_group" {
  count    = var.create_scylla_monitoring_stack ? 1 : 0
  name     = "scylla-monitoring-tg"
  port     = 3000
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    port                = 3000
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

# Listeners for Scylla Monitoring
resource "aws_lb_listener" "scylla_monitoring_listener" {
  count             = var.create_scylla_monitoring_stack ? 1 : 0
  load_balancer_arn = aws_lb.scylla_monitoring_nlb[count.index].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.scylla_monitoring_nlb_target_group[count.index].arn
  }
}

# Attach the monitoring instance to the target group
resource "aws_lb_target_group_attachment" "scylla_monitoring" {
  count            = var.create_scylla_monitoring_stack ? 1 : 0
  target_group_arn = aws_lb_target_group.scylla_monitoring_nlb_target_group[count.index].arn
  target_id        = aws_instance.scylla_monitoring[0].id
  port             = 3000
}

data "aws_elb_service_account" "main" {}
