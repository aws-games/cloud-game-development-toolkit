####################################################
# EFS for Unity Accelerator storage
####################################################

# EFS for persistent storage
resource "aws_efs_file_system" "unity_accelerator_efs" {
  #checkov:skip=CKV_AWS_184: CMK encryption not supported currently

  count            = var.efs_id != null ? 0 : 1
  creation_token   = "${local.name_prefix}-efs"
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  encrypted        = var.efs_encryption_enabled

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs"
  })
}

# Mount Point for Unity Accelerator file system
resource "aws_efs_mount_target" "unity_accelerator_efs_mount_target" {
  count          = var.efs_id != null ? 0 : length(var.service_subnets)
  file_system_id = var.efs_id != null ? var.efs_id : aws_efs_file_system.unity_accelerator_efs[0].id
  subnet_id      = var.service_subnets[count.index]
  security_groups = [
    aws_security_group.unity_accelerator_efs_sg[0].id
  ]
}

# Unity Accelerator data directory
resource "aws_efs_access_point" "unity_accelerator_efs_data_access_point" {
  count          = var.efs_access_point_id != null ? 0 : 1
  file_system_id = aws_efs_file_system.unity_accelerator_efs[0].id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/data/unity_accelerator"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 0755
    }
  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-access-point"
  })
}

####################################################
# Unity Accelerator Secrets Manager
####################################################
# For web dashboard username and password

resource "awscc_secretsmanager_secret" "dashboard_username_arn" {
  count         = var.unity_accelerator_dashboard_username_arn == null ? 1 : 0
  name          = "${local.name_prefix}-dashboard-username"
  description   = "The Unity Accelerator web dashboard's username."
  secret_string = "uauser"
}

resource "awscc_secretsmanager_secret" "dashboard_password_arn" {
  count       = var.unity_accelerator_dashboard_password_arn == null ? 1 : 0
  name        = "${local.name_prefix}-dashboard-password"
  description = "The Unity Accelerator web dashboard's password."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
}

####################################################
# ECS Cluster for Unity Accelerator
####################################################

# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "unity_accelerator_cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}

# Unity Accelerator ECS Cluster (if not provided)
resource "aws_ecs_cluster" "unity_accelerator_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-ecs-cluster"
    }
  )
}

# Unity Accelerator ECS Task Definition
resource "aws_ecs_task_definition" "unity_accelerator_task_definition" {
  family                   = "${var.name}-${var.environment}-ecs"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.unity_accelerator_task_execution_role.arn
  task_role_arn            = aws_iam_role.unity_accelerator_default_role.arn

  container_definitions = jsonencode([
    {
      name                   = var.container_name
      image                  = var.unity_accelerator_docker_image
      enable_execute_command = var.debug

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "TCP"
        },
        {
          containerPort = 10080
          hostPort      = 10080
          protocol      = "TCP"
        }
      ]

      environment = local.base_env

      entryPoint = ["/bin/sh", "-c"]

      secrets = [
        {
          name      = "DASHBOARD_USERNAME"
          valueFrom = local.dashboard_username_secret
        },
        {
          name      = "DASHBOARD_PASSWORD"
          valueFrom = local.dashboard_password_secret
        }
      ]

      command = [
        <<-EOT
        /usr/local/bin/unity-accelerator register adbv2 &&
        /usr/local/bin/unity-accelerator dashboard password "$DASHBOARD_USERNAME" --password "$DASHBOARD_PASSWORD" &&
        /usr/local/bin/unity-accelerator dashboard list &&
        /usr/local/bin/unity-accelerator run
        EOT
      ]

      mountPoints = [
        {
          sourceVolume  = "unity-cache-data"
          containerPath = "/agent"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unity_accelerator_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "[APP]"
        }
      }
    }
  ])

  volume {
    name = "unity-cache-data"
    efs_volume_configuration {
      file_system_id          = local.efs_file_system_id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = local.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  tags = merge(
    local.tags,
    {
      Name = var.name
    }
  )
}

# ECS Service
resource "aws_ecs_service" "unity_accelerator" {
  name                   = local.name_prefix
  cluster                = var.cluster_name != null ? data.aws_ecs_cluster.unity_accelerator_cluster[0].arn : aws_ecs_cluster.unity_accelerator_cluster[0].arn
  task_definition        = aws_ecs_task_definition.unity_accelerator_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  wait_for_steady_state = false

  network_configuration {
    subnets         = var.service_subnets
    security_groups = [aws_security_group.unity_accelerator_service_sg.id]
  }

  # Dashboard
  load_balancer {
    target_group_arn = aws_lb_target_group.unity_accelerator_dashboard_target_group.arn
    container_name   = var.container_name
    container_port   = 80
  }

  # Cache
  load_balancer {
    target_group_arn = aws_lb_target_group.unity_accelerator_cache_target_group.arn
    container_name   = var.container_name
    container_port   = 10080
  }

  depends_on = [
    aws_lb_listener.unity_accelerator_https_dashboard_listener,
    aws_lb_listener.unity_accelerator_https_dashboard_redirect,
    aws_lb_listener.unity_accelerator_cache_listener
  ]

  tags = merge(
    local.tags,
    {
      Name = var.name
    }
  )
}

####################################################
# Security Groups
####################################################

######
# EFS
######

# Unity Accelerator EFS security group
resource "aws_security_group" "unity_accelerator_efs_sg" {
  count       = var.efs_id == null ? 1 : 0
  name        = "${local.name_prefix}-efs-sg"
  description = "Unity Accelerator EFS mount target security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for NFS traffic from service to EFS
resource "aws_vpc_security_group_ingress_rule" "service_efs" {
  count                        = var.efs_id == null ? 1 : 0
  security_group_id            = aws_security_group.unity_accelerator_efs_sg[0].id
  referenced_security_group_id = aws_security_group.unity_accelerator_service_sg.id
  description                  = "Allows inbound access from Unity Accelerator service containers to EFS"
  ip_protocol                  = "TCP"
  from_port                    = 2049
  to_port                      = 2049
}

######
# ECS
######

# Unity Accelerator service security group
resource "aws_security_group" "unity_accelerator_service_sg" {
  name        = "${local.name_prefix}-service-sg"
  vpc_id      = var.vpc_id
  description = "Unity Accelerator service security group"
  tags        = local.tags
}

# ECS ingress rule from ALB on port 80 (dashboard)
resource "aws_vpc_security_group_ingress_rule" "unity_accelerator_service_ingress_from_alb_80" {
  #checkov:skip=CKV_AWS_260:Dashboard is password-protected

  count                        = var.create_alb ? 1 : 0
  security_group_id            = aws_security_group.unity_accelerator_service_sg.id
  referenced_security_group_id = aws_security_group.unity_accelerator_alb_sg[0].id
  description                  = "Allows HTTP traffic on port 80 (dashboard) from the Application Load Balancer"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "TCP"
}

# ECS ingress rule on port 10080 (cache)
resource "aws_vpc_security_group_ingress_rule" "unity_accelerator_service_ingress_from_nlb_10080" {
  for_each          = var.create_nlb ? data.aws_subnet.nlb_subnets : {}
  security_group_id = aws_security_group.unity_accelerator_service_sg.id
  description       = "Allows TCP traffic on port 10080 (cache) from the Network Load Balancer subnets"
  from_port         = 10080
  to_port           = 10080
  ip_protocol       = "TCP"
  cidr_ipv4         = each.value.cidr_block
}

# ECS ingres rules to allow health checks from NLB subnets
resource "aws_vpc_security_group_ingress_rule" "unity_accelerator_service_ingress_from_nlb_80" {
  for_each          = var.create_nlb ? data.aws_subnet.nlb_subnets : {}
  security_group_id = aws_security_group.unity_accelerator_service_sg.id
  description       = "Allows inbound HTTP health checks from NLB"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "TCP"
  cidr_ipv4         = each.value.cidr_block
}

# ECS egress Rule for all outbound traffic
resource "aws_vpc_security_group_egress_rule" "unity_accelerator_service_egress_all" {
  count             = var.create_alb ? 1 : 0
  security_group_id = aws_security_group.unity_accelerator_service_sg.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Get subnet data for each subnet ID
data "aws_subnet" "nlb_subnets" {
  for_each = var.create_nlb ? local.lb_subnet_map : {}
  id       = each.value
}

######
# ALB
######

# Unity Accelerator ALB security group
resource "aws_security_group" "unity_accelerator_alb_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to Unity Accelerator service ALB

  count       = var.create_alb ? 1 : 0
  name        = "${local.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id
  description = "Unity Accelerator Application Load Balancer security group"
  tags        = local.tags
}

# ALB egress rule for http dashboard traffic to the Unity Accelerator service on port 80
resource "aws_vpc_security_group_egress_rule" "unity_accelerator_alb_egress_service_80" {
  count                        = var.create_alb ? 1 : 0
  security_group_id            = aws_security_group.unity_accelerator_alb_sg[0].id
  referenced_security_group_id = aws_security_group.unity_accelerator_service_sg.id
  description                  = "Allows HTTP traffic (dashboard) to the Unity Accelerator service"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "TCP"
}

####################################################
# IAM Roles And Policies
####################################################

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

resource "aws_iam_policy" "unity_accelerator_default_policy" {
  name        = "${local.name_prefix}-default-policy"
  description = "Policy granting permissions for Unity Accelerator."
  policy      = data.aws_iam_policy_document.unity_accelerator_default_policy.json
}

data "aws_iam_policy_document" "unity_accelerator_default_policy" {
  statement {
    sid    = "ECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:CreateControlChannel",
    ]
    resources = [
      "*"
    ]
  }

  # EFS-related permissions needed by the ECS task to be able to modify directories
  statement {
    sid    = "EFS"
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientMount"
    ]
    resources = [
      local.efs_file_system_arn
    ]
  }
}

# ECS task role
resource "aws_iam_role" "unity_accelerator_default_role" {
  name               = "${local.name_prefix}-default-role"
  description        = "Default role for Unity Accelerator ECS task."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "unity_accelerator_default_policy_attachment" {
  role       = aws_iam_role.unity_accelerator_default_role.name
  policy_arn = aws_iam_policy.unity_accelerator_default_policy.arn
}

# ECS task execution role
resource "aws_iam_role" "unity_accelerator_task_execution_role" {
  name               = "${local.name_prefix}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  tags               = local.tags
  description        = "Unity Accelerator service task execution role"
}

resource "aws_iam_role_policy_attachment" "unity_accelerator_task_execution_role_policy_attachment" {
  role       = aws_iam_role.unity_accelerator_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Adding permission to access dashboard password in Secrets Manager to ECS task execution role
resource "aws_iam_policy" "secret_access_policy" {
  name        = "${local.name_prefix}-secret-access-policy"
  description = "Policy to allow access to Unity Accelerator dashboard password secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          local.dashboard_username_secret,
          local.dashboard_password_secret
        ]
      }
    ]
  })
}

# New policy attachment for the secrets access
resource "aws_iam_role_policy_attachment" "task_execution_role_secret_policy" {
  role       = aws_iam_role.unity_accelerator_task_execution_role.name
  policy_arn = aws_iam_policy.secret_access_policy.arn
}


# CloudWatch Logs
resource "aws_cloudwatch_log_group" "unity_accelerator_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default

  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags              = local.tags
}

data "aws_iam_policy_document" "cloudwatch_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.name_prefix}-log-group:*"
    ]
  }
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${local.name_prefix}-cloudwatch-logs-policy"
  description = "Policy for CloudWatch Logs access for Unity Accelerator"
  policy      = data.aws_iam_policy_document.cloudwatch_logs_policy.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.unity_accelerator_default_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}


####################################################
# Application Load Balancer
####################################################

resource "aws_lb" "unity_accelerator_external_alb" {
  #checkov:skip=CKV_AWS_150:Deletion protection disabled by default
  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  count              = var.create_alb ? 1 : 0
  name               = "${local.name_prefix}-alb"
  security_groups    = [aws_security_group.unity_accelerator_alb_sg[0].id]
  load_balancer_type = "application"
  internal           = var.alb_is_internal
  subnets            = var.lb_subnets

  dynamic "access_logs" {
    for_each = var.enable_unity_accelerator_lb_access_logs ? [1] : []
    content {
      enabled = var.enable_unity_accelerator_lb_access_logs
      bucket  = var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].id
      prefix  = var.unity_accelerator_alb_access_logs_prefix != null ? var.unity_accelerator_alb_access_logs_prefix : "${local.name_prefix}-alb"
    }
  }

  enable_deletion_protection = var.enable_unity_accelerator_lb_deletion_protection
  drop_invalid_header_fields = true
  tags                       = local.tags
}

resource "aws_lb_target_group" "unity_accelerator_dashboard_target_group" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination

  name        = "${local.name_prefix}-dashboard-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/agent-health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    port                = 80
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = local.tags
}

# ALB HTTPS Listener
resource "aws_lb_listener" "unity_accelerator_https_dashboard_listener" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.unity_accelerator_external_alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.unity_accelerator_dashboard_target_group.arn
  }
  tags = local.tags
}

# ALB HTTP to HTTPS redirect
resource "aws_lb_listener" "unity_accelerator_https_dashboard_redirect" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.unity_accelerator_external_alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

####################################################
# Network Load Balancer
####################################################

resource "aws_lb" "unity_accelerator_external_nlb" {
  #checkov:skip=CKV_AWS_150:Deletion protection disabled by default
  #checkov:skip=CKV2_AWS_28:NLB access is managed with SG allow listing
  #checkov:skip=CKV_AWS_152:Module is single-region

  count              = var.create_nlb ? 1 : 0
  name               = "${local.name_prefix}-nlb"
  load_balancer_type = "network"
  internal           = var.nlb_is_internal
  subnets            = var.lb_subnets

  dynamic "access_logs" {
    for_each = var.enable_unity_accelerator_lb_access_logs ? [1] : []
    content {
      enabled = var.enable_unity_accelerator_lb_access_logs
      bucket  = var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].id
      prefix  = var.unity_accelerator_nlb_access_logs_prefix != null ? var.unity_accelerator_nlb_access_logs_prefix : "${local.name_prefix}-nlb"
    }
  }

  enable_deletion_protection = var.enable_unity_accelerator_lb_deletion_protection
  tags                       = local.tags
}

resource "aws_lb_target_group" "unity_accelerator_cache_target_group" {
  name        = "${local.name_prefix}-cache-tg"
  port        = 10080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/agent-health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    port                = 80
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = local.tags
}

# NLB Protobuf (cache) Listener
resource "aws_lb_listener" "unity_accelerator_cache_listener" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.unity_accelerator_external_nlb[0].arn
  port              = 10080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.unity_accelerator_cache_target_group.arn
  }
  tags = local.tags
}

####################################################
# ALB and NLB Access Logs
####################################################

resource "random_string" "unity_accelerator_lb_access_logs_bucket_suffix" {
  count   = var.enable_unity_accelerator_lb_access_logs && var.unity_accelerator_lb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "unity_accelerator_lb_access_logs_bucket" {
  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  count         = var.enable_unity_accelerator_lb_access_logs && var.unity_accelerator_lb_access_logs_bucket == null ? 1 : 0
  bucket        = "${local.name_prefix}-lb-access-logs-${random_string.unity_accelerator_lb_access_logs_bucket_suffix[0].result}"
  force_destroy = var.debug

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-lb-access-logs-${random_string.unity_accelerator_lb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_lb_write" {
  count = var.enable_unity_accelerator_lb_access_logs && var.unity_accelerator_lb_access_logs_bucket == null ? 1 : 0

  statement {
    sid     = "AllowELBServiceAccount"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = [
      "${var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].arn}/${var.unity_accelerator_alb_access_logs_prefix != null ? var.unity_accelerator_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*",
      "${var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].arn}/${var.unity_accelerator_nlb_access_logs_prefix != null ? var.unity_accelerator_nlb_access_logs_prefix : "${local.name_prefix}-nlb"}/*",
    ]
  }

  # Statement for logs delivery service to put objects
  statement {
    sid     = "AllowLogDeliveryToPutObject"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = [
      "${var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].arn}/${var.unity_accelerator_alb_access_logs_prefix != null ? var.unity_accelerator_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*",
      "${var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].arn}/${var.unity_accelerator_nlb_access_logs_prefix != null ? var.unity_accelerator_nlb_access_logs_prefix : "${local.name_prefix}-nlb"}/*",
    ]
  }

  # Statement for logs delivery service to get bucket ACL
  statement {
    sid     = "AllowLogDeliveryToGetBucketACL"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = [
      var.unity_accelerator_lb_access_logs_bucket != null ? var.unity_accelerator_lb_access_logs_bucket : aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].arn
    ]
  }
}

resource "aws_s3_bucket_policy" "lb_access_logs_bucket_policy" {
  count  = var.enable_unity_accelerator_lb_access_logs && var.unity_accelerator_lb_access_logs_bucket == null ? 1 : 0
  bucket = var.unity_accelerator_lb_access_logs_bucket == null ? aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].id : var.unity_accelerator_lb_access_logs_bucket
  policy = data.aws_iam_policy_document.access_logs_bucket_lb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.enable_unity_accelerator_lb_access_logs && var.unity_accelerator_lb_access_logs_bucket == null && length(aws_s3_bucket.unity_accelerator_lb_access_logs_bucket) > 0 ? 1 : 0

  bucket = aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].id

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

  depends_on = [
    aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0]
  ]
}

resource "aws_s3_bucket_public_access_block" "access_logs_bucket_public_block" {
  count = var.enable_unity_accelerator_lb_access_logs && var.unity_accelerator_lb_access_logs_bucket == null ? 1 : 0

  bucket                  = aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [
    aws_s3_bucket.unity_accelerator_lb_access_logs_bucket[0]
  ]
}

####################################################
# Debugging / ECS Execute Command
####################################################

# VPC Endpoints for ECS Execute Command
resource "aws_vpc_endpoint" "ssm_vpce" {
  count               = var.debug == true ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.service_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages_vpce" {
  count               = var.debug == true ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.service_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages_vpce" {
  count               = var.debug == true ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.service_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to SSM, SSMMessages, EC2MEssages endpoints for debugging

  count       = var.debug == true ? 1 : 0
  name        = "${local.name_prefix}-vpce-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id
}

# Allow HTTPS traffic to VPC endpoints
resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_https" {
  count                        = var.debug == true ? 1 : 0
  security_group_id            = aws_security_group.vpc_endpoint_sg[0].id
  referenced_security_group_id = aws_security_group.unity_accelerator_service_sg.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "TCP"
  description                  = "Allows HTTPS traffic from Unity Accelerator service to VPC endpoints"
}

# Allow HTTPS traffic from VPC endpoints to Unity Accelerator service
resource "aws_vpc_security_group_ingress_rule" "unity_accelerator_ingress_to_vpce" {
  count                        = var.debug == true ? 1 : 0
  security_group_id            = aws_security_group.unity_accelerator_service_sg.id
  referenced_security_group_id = aws_security_group.vpc_endpoint_sg[0].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "TCP"
  description                  = "Allows HTTPS traffic from VPC endpoints to Unity Accelerator service"
}
