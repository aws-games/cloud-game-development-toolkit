data "aws_region" "current" {}

locals {
  image       = "ghcr.io/epicgames/horde-server:latest"
  name_prefix = "${var.project_prefix}-${var.name}"
  tags = merge(var.tags, {
    "ENVIRONMENT" = var.environment
  })
}

# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "unreal_horde_cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}

# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "unreal_horde_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "unreal_horde_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.unreal_horde_cloudwatch_log_retention_in_days
  tags              = local.tags
}

resource "aws_ecs_task_definition" "unreal_horde_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  container_definitions = jsonencode([
    {
      name  = var.name
      image = local.image
      repositoryCredentials = {
        "credentialsParameter" : var.github_credentials_secret_arn
      }
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      environment = [
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ue-horde"
        }
      }
    }
  ])
  tags = {
    Name = var.name
  }
  task_role_arn      = var.custom_unreal_horde_role != null ? var.custom_unreal_horde_role : aws_iam_role.unreal_horde_default_role[0].arn
  execution_role_arn = aws_iam_role.unreal_horde_task_execution_role.arn
}

resource "aws_ecs_service" "unreal_horde" {
  name = local.name_prefix

  cluster              = var.cluster_name != null ? data.aws_ecs_cluster.unreal_horde_cluster[0].arn : aws_ecs_cluster.unreal_horde_cluster[0].arn
  task_definition      = aws_ecs_task_definition.unreal_horde_task_definition.arn
  launch_type          = "FARGATE"
  desired_count        = var.desired_container_count
  force_new_deployment = true

  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.unreal_horde_alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }
  network_configuration {
    subnets         = var.unreal_horde_subnets
    security_groups = [aws_security_group.unreal_horde_sg.id]
  }

  tags = local.tags
}

resource "aws_security_group" "unreal_horde_alb_sg" {
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "unreal_horde ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "unreal_horde_alb_outbound_service" {
  security_group_id            = aws_security_group.unreal_horde_alb_sg.id
  description                  = "Allow outbound traffic from unreal_horde ALB to unreal_horde service"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

########################################
# unreal_horde SERVICE SECURITY GROUP
########################################

# unreal_horde Service Security Group (attached to containers)
resource "aws_security_group" "unreal_horde_sg" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "unreal_horde Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_outbound_ipv4" {
  security_group_id = aws_security_group.unreal_horde_sg.id
  description       = "Allow outbound traffic from unreal_horde service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_outbound_ipv6" {
  security_group_id = aws_security_group.unreal_horde_sg.id
  description       = "Allow outbound traffic from unreal_horde service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_alb" {
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound traffic from unreal_horde ALB to service"
  referenced_security_group_id = aws_security_group.unreal_horde_alb_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

# - Random Strings to prevent naming conflicts -
resource "random_string" "unreal_horde" {
  length  = 4
  special = false
  upper   = false
}

# - Trust Relationships -
#  ECS - Tasks
data "aws_iam_policy_document" "ecs_tasks_trust_relationship" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# - Policies -
data "aws_iam_policy_document" "unreal_horde_default_policy" {
  count = var.create_unreal_horde_default_policy ? 1 : 0
  # ECS
  statement {
    sid    = "ECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:CreateControlChannel"
    ]
    resources = [
      "*"
    ]
  }
}


resource "aws_iam_policy" "unreal_horde_default_policy" {
  count = var.create_unreal_horde_default_policy ? 1 : 0

  name        = "${var.project_prefix}-unreal_horde-default-policy"
  description = "Policy granting permissions for Unreal Horde."
  policy      = data.aws_iam_policy_document.unreal_horde_default_policy[0].json
}



# - Roles -
resource "aws_iam_role" "unreal_horde_default_role" {
  count = var.create_unreal_horde_default_role ? 1 : 0

  name               = "${var.project_prefix}-unreal_horde-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  managed_policy_arns = [
    aws_iam_policy.unreal_horde_default_policy[0].arn
  ]
  tags = local.tags
}

data "aws_iam_policy_document" "unreal_horde_secrets_manager_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.github_credentials_secret_arn
    ]
  }
}

resource "aws_iam_policy" "unreal_horde_secrets_manager_policy" {
  name        = "${var.project_prefix}-unreal-horde-secrets-manager-policy"
  description = "Policy granting permissions for Unreal Horde task execution role to access SSM."
  policy      = data.aws_iam_policy_document.unreal_horde_secrets_manager_policy.json
}


resource "aws_iam_role" "unreal_horde_task_execution_role" {
  name = "${var.project_prefix}-unreal_horde-task-execution-role"

  assume_role_policy  = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy", aws_iam_policy.unreal_horde_secrets_manager_policy.arn]
}

################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "unreal_horde_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.unreal_horde_alb_subnets
  security_groups    = concat(var.existing_security_groups, [aws_security_group.unreal_horde_alb_sg.id])

  dynamic "access_logs" {
    for_each = var.enable_unreal_horde_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_unreal_horde_alb_access_logs
      bucket  = var.unreal_horde_alb_access_logs_bucket != null ? var.unreal_horde_alb_access_logs_bucket : aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0].id
      prefix  = var.unreal_horde_alb_access_logs_prefix != null ? var.unreal_horde_alb_access_logs_prefix : "${local.name_prefix}-alb"
    }
  }
  enable_deletion_protection = var.enable_unreal_horde_alb_deletion_protection

  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  drop_invalid_header_fields = true

  tags = local.tags
}

resource "random_string" "unreal_horde_alb_access_logs_bucket_suffix" {
  count   = var.enable_unreal_horde_alb_access_logs && var.unreal_horde_alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "unreal_horde_alb_access_logs_bucket" {
  count  = var.enable_unreal_horde_alb_access_logs && var.unreal_horde_alb_access_logs_bucket == null ? 1 : 0
  bucket = "${local.name_prefix}-alb-access-logs-${random_string.unreal_horde_alb_access_logs_bucket_suffix[0].result}"

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.unreal_horde_alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.enable_unreal_horde_alb_access_logs && var.unreal_horde_alb_access_logs_bucket == null ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = ["${var.unreal_horde_alb_access_logs_bucket != null ? var.unreal_horde_alb_access_logs_bucket : aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0].arn}/${var.unreal_horde_alb_access_logs_prefix != null ? var.unreal_horde_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count  = var.enable_unreal_horde_alb_access_logs && var.unreal_horde_alb_access_logs_bucket == null ? 1 : 0
  bucket = var.unreal_horde_alb_access_logs_bucket == null ? aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0].id : var.unreal_horde_alb_access_logs_bucket
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.enable_unreal_horde_alb_access_logs && var.unreal_horde_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0].id
  rule {
    id     = "access-logs-lifecycle"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs_bucket_public_block" {
  count = var.enable_unreal_horde_alb_access_logs && var.unreal_horde_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.unreal_horde_alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_lb_target_group" "unreal_horde_alb_target_group" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }

  tags = local.tags
}


# HTTPS listener for unreal_horde ALB
resource "aws_lb_listener" "unreal_horde_alb_https_listener" {
  load_balancer_arn = aws_lb.unreal_horde_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.unreal_horde_alb_target_group.arn
    type             = "forward"
  }

  tags = local.tags
}
