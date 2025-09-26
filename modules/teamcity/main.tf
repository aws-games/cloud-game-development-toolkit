###################################
# ECS Cluster for TeamCity Server #
###################################
# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "teamcity_cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}
resource "aws_ecs_cluster" "teamcity_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.teamcity[0].arn
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_service_discovery_http_namespace" "teamcity" {
  count       = var.cluster_name != null ? 0 : 1
  name        = "${local.name_prefix}-namespace"
  description = "Service Connect namespace for TeamCity services"
  tags        = local.tags
}

# TeamCity Task Definition
resource "aws_ecs_task_definition" "teamcity_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = local.image
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true

      portMappings = [
        {
          name          = "teamcity-server"
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.teamcity_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "[APP]"
        }
      }

      mountPoints = [
        {
          sourceVolume  = "teamcity_data",
          containerPath = "/data/teamcity_server/datadir"
          readOnly      = false
        }
      ]

      # Combine the lists
      environment = concat(local.base_env, local.password_env)

      secrets = var.database_connection_string == null ? [
        {
          name      = "TEAMCITY_DB_PASSWORD"
          valueFrom = "${aws_rds_cluster.teamcity_db_cluster[0].master_user_secret[0].secret_arn}:password::"
        }
      ] : []
    }
  ])
  tags = {
    Name = var.name
  }
  task_role_arn      = aws_iam_role.teamcity_default_role.arn
  execution_role_arn = aws_iam_role.teamcity_task_execution_role.arn

  volume {
    name = "teamcity_data"
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
}

# ECS Service
resource "aws_ecs_service" "teamcity" {
  name = local.name_prefix
  cluster = (var.cluster_name != null ? data.aws_ecs_cluster.teamcity_cluster[0].arn :
  aws_ecs_cluster.teamcity_cluster[0].arn)
  task_definition        = aws_ecs_task_definition.teamcity_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = var.desired_container_count
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  //The databases were breaking because the tasks would cycle out,
  // meaning that when one was terminating, another one would be booting up.
  // At this time, the Teamcity server thinks that the database is assigned to
  // 2 different servers and you'd be forced to do a completely new deployment because
  // the server won't work. This temp solution works because it makes sure the task
  // is completely off before another one is booted up, and I don't know an alternative yet
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  wait_for_steady_state = false #TODO: make this configurable

  network_configuration {
    subnets         = var.service_subnets
    security_groups = [aws_security_group.teamcity_service_sg.id]
  }
  dynamic "load_balancer" {
    for_each = var.create_external_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.teamcity_target_group[0].arn
      container_name   = var.container_name
      container_port   = var.container_port

    }
  }

  # to let the agent talk to the service w/o hitting ALB
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.teamcity[0].arn

    service {
      port_name      = "teamcity-server"
      discovery_name = "teamcity-server"
      client_alias {
        port = var.container_port
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.teamcity_log_group.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "[CONNECT]"
      }
    }
  }

  depends_on = [
    aws_rds_cluster.teamcity_db_cluster[0],
    aws_rds_cluster_instance.teamcity_db_cluster_instance
  ]

  tags = local.tags
}

###################################
# Security Groups                 #
###################################

# TeamCity service security group
resource "aws_security_group" "teamcity_service_sg" {
  name        = "${local.name_prefix}-service-sg"
  vpc_id      = var.vpc_id
  description = "TeamCity service security group"
  tags        = local.tags
}

# TeamCity EFS security group
resource "aws_security_group" "teamcity_efs_sg" {
  count       = var.efs_id == null ? 1 : 0
  name        = "${local.name_prefix}-efs-sg"
  description = "TeamCity EFS mount target security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for NFS traffic from service to EFS
resource "aws_vpc_security_group_ingress_rule" "service_efs" {
  count                        = var.efs_id == null ? 1 : 0
  security_group_id            = aws_security_group.teamcity_efs_sg[0].id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow inbound access from TeamCity service containers to EFS"
  ip_protocol                  = "TCP"
  from_port                    = 2049
  to_port                      = 2049
}

# TeamCity Aurora Serverless PostgreSQL security group
resource "aws_security_group" "teamcity_db_sg" {
  count       = var.database_connection_string == null ? 1 : 0
  name        = "${local.name_prefix}-db-sg"
  description = "TeamCity DB security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for PostgreSQL from service to database cluster
resource "aws_vpc_security_group_ingress_rule" "service_db" {
  count                        = var.database_connection_string == null ? 1 : 0
  security_group_id            = aws_security_group.teamcity_db_sg[0].id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow inbound access from TeamCity service containers to DB"
  ip_protocol                  = "TCP"
  from_port                    = 5432
  to_port                      = 5432
}

# TeamCity ALB security group
resource "aws_security_group" "teamcity_alb_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to TeamCity service ALB
  count       = var.create_external_alb ? 1 : 0
  name        = "${local.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id
  description = "TeamCity ALB security group"
  tags        = local.tags
}

# Ingress rule for HTTP traffic from ALB to service
resource "aws_vpc_security_group_ingress_rule" "service_inbound_alb" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.teamcity_service_sg.id
  referenced_security_group_id = aws_security_group.teamcity_alb_sg[0].id
  description                  = "Allow inbound HTTP traffic from ALB to service containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "TCP"
}

# Egress rule for HTTP traffic from ALB to service
resource "aws_vpc_security_group_egress_rule" "alb_outbound_service" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.teamcity_alb_sg[0].id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow outbound HTTP traffic from ALB to service containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "TCP"
}

# Grant TeamCity service access to internet
resource "aws_vpc_security_group_egress_rule" "service_outbound_internet" {
  security_group_id = aws_security_group.teamcity_service_sg.id
  description       = "Allow outbound internet access from TeamCity service containers"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#############################################
# IAM Roles for TeamCity Module
#############################################

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

data "aws_iam_policy_document" "teamcity_default_policy" {
  #checkov:skip=CKV_AWS_111: resources need IAM write permissions
  #checkov:skip=CKV_AWS_356: resources need IAM write permissions

  # ECS
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

  #grant the task necessary EFS permissions to be able to modify directories
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

  statement {
    sid       = "ServiceDiscovery"
    effect    = "Allow"
    actions   = ["servicediscovery:DiscoverInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "teamcity_default_policy" {
  name        = "teamcity-default-policy"
  description = "Policy granting permissions for TeamCity."
  policy      = data.aws_iam_policy_document.teamcity_default_policy.json
}

resource "aws_iam_role" "teamcity_default_role" {
  name               = "teamcity-default-role"
  description        = "Default role for TeamCity ECS task."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "teamcity_default_role" {
  role       = aws_iam_role.teamcity_default_role.name
  policy_arn = aws_iam_policy.teamcity_default_policy.arn
}

data "aws_iam_policy_document" "teamcity_execution_database_policy" {
  count = var.database_connection_string == null ? 1 : 0
  statement {
    sid     = "SecretsManager"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_rds_cluster.teamcity_db_cluster[0].master_user_secret[0].secret_arn
    ]
  }
}

resource "aws_iam_policy" "teamcity_execution_database_policy" {
  count       = var.database_connection_string == null ? 1 : 0
  name        = "teamcity-execution-policy"
  description = "Policy granting permissions for TeamCity to access the database."
  policy      = data.aws_iam_policy_document.teamcity_execution_database_policy[0].json

}

resource "aws_iam_role" "teamcity_task_execution_role" {
  name               = "teamcity-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
}

resource "aws_iam_role_policy_attachment" "teamcity_task_execution_database_policy" {
  count      = var.database_connection_string == null ? 1 : 0
  role       = aws_iam_role.teamcity_task_execution_role.name
  policy_arn = aws_iam_policy.teamcity_execution_database_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "teamcity_task_execution_default_policy" {
  role       = aws_iam_role.teamcity_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# CloudWatch Logs
resource "aws_cloudwatch_log_group" "teamcity_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.teamcity_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Load Balancer for TeamCity Service
resource "aws_lb" "teamcity_external_lb" {
  count              = var.create_external_alb ? 1 : 0
  name               = "${local.name_prefix}-lb"
  security_groups    = [aws_security_group.teamcity_alb_sg[0].id]
  load_balancer_type = "application"
  internal           = false
  subnets            = var.alb_subnets


  dynamic "access_logs" {
    for_each = var.enable_teamcity_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_teamcity_alb_access_logs
      bucket = (var.teamcity_alb_access_logs_bucket != null ? var.teamcity_alb_access_logs_bucket :
      aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id)
      prefix = (var.teamcity_alb_access_logs_prefix != null ? var.teamcity_alb_access_logs_prefix :
      "${local.name_prefix}-alb")
    }
  }
  #checkov:skip=CKV_AWS_150:Deletion protection disabled by default
  enable_deletion_protection = var.enable_teamcity_alb_deletion_protection


  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  drop_invalid_header_fields = true
  tags                       = local.tags
}

# TeamCity target group for ALB
resource "aws_lb_target_group" "teamcity_target_group" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination
  count       = var.create_external_alb ? 1 : 0
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthCheck/healthy"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    port                = var.container_port
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = local.tags
}

# ALB HTTPS Listener
resource "aws_lb_listener" "teamcity_listener" {
  count             = var.create_external_alb ? 1 : 0
  load_balancer_arn = aws_lb.teamcity_external_lb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.teamcity_target_group[0].arn
  }
  tags = local.tags
}

# #######################################
# # TeamCity Aurora Serverless Database #
# #######################################
# Subnet group
resource "aws_db_subnet_group" "teamcity_db_subnet_group" {
  count      = var.database_connection_string == null ? 1 : 0
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.service_subnets
  tags       = local.tags
}

# # RDS instance with Aurora serverless engine
resource "aws_rds_cluster" "teamcity_db_cluster" {
  #checkov:skip=CKV2_AWS_27:not enabling query logging by design
  #checkov:skip=CKV2_AWS_8: TODO: add rds backup plan
  count                       = var.database_connection_string == null ? 1 : 0
  cluster_identifier          = "teamcity-cluster"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = "16.6" #check for latest as option
  database_name               = "teamcity"
  master_username             = "teamcity"
  manage_master_user_password = true #using AWS Secrets Manager
  storage_encrypted           = true
  skip_final_snapshot         = var.aurora_skip_final_snapshot
  db_subnet_group_name        = aws_db_subnet_group.teamcity_db_subnet_group[0].id
  vpc_security_group_ids = [
    aws_security_group.teamcity_db_sg[0].id
  ]

  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
}

resource "aws_rds_cluster_instance" "teamcity_db_cluster_instance" {
  count              = var.database_connection_string == null ? var.aurora_instance_count : 0
  cluster_identifier = aws_rds_cluster.teamcity_db_cluster[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.teamcity_db_cluster[0].engine
  engine_version     = aws_rds_cluster.teamcity_db_cluster[0].engine_version
}

# ################
# # TeamCity EFS #
# ################

# File system for teamcity
resource "aws_efs_file_system" "teamcity_efs_file_system" {
  count            = var.efs_id != null ? 0 : 1
  creation_token   = "${local.name_prefix}-efs-file-system"
  performance_mode = var.teamcity_efs_performance_mode
  throughput_mode  = var.teamcity_efs_throughput_mode

  encrypted = var.efs_encryption_enabled

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
  #checkov:skip=CKV_AWS_184: CMK encryption not supported currently
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-file-system"
  })
}

# Mount Point for teamcity file system
resource "aws_efs_mount_target" "teamcity_efs_mount_target" {
  count          = var.efs_id != null ? 0 : length(var.service_subnets)
  file_system_id = var.efs_id != null ? var.efs_id : aws_efs_file_system.teamcity_efs_file_system[0].id
  subnet_id      = var.service_subnets[count.index]
  security_groups = [
    aws_security_group.teamcity_efs_sg[0].id
  ]
}

# TeamCity data directory
resource "aws_efs_access_point" "teamcity_efs_data_access_point" {
  count          = var.efs_access_point_id != null ? 0 : 1
  file_system_id = aws_efs_file_system.teamcity_efs_file_system[0].id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/data/teamcity_server/datadir"
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

###########################
# Access Logs
###########################

resource "random_string" "teamcity_alb_access_logs_bucket_suffix" {
  count   = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "teamcity_alb_access_logs_bucket" {
  count         = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  bucket        = "${local.name_prefix}-alb-access-logs-${random_string.teamcity_alb_access_logs_bucket_suffix[0].result}"
  force_destroy = var.debug

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.teamcity_alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = [
      "${var.teamcity_alb_access_logs_bucket != null ? var.teamcity_alb_access_logs_bucket : aws_s3_bucket.teamcity_alb_access_logs_bucket[0].arn}/${var.teamcity_alb_access_logs_prefix != null ? var.teamcity_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  bucket = (var.teamcity_alb_access_logs_bucket == null ? aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id :
  var.teamcity_alb_access_logs_bucket)
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.teamcity_alb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id
  rule {
    id     = "access-logs-lifecycle"
    status = "Enabled"
    filter {}
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
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.teamcity_alb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
