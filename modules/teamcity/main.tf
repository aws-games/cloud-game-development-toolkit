###################################
# ECS Cluster for TeamCity Server #
###################################

resource "aws_ecs_cluster" "teamcity_cluster" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
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
        },
        {
          sourceVolume  = "teamcity_logs",
          containerPath = "/data/teamcity_server/logs"
          readOnly      = false
        }
      ]
      # Set environment variables for database connection string
      environment = [
        {
          name  = "TEAMCITY_DB_URL"
          value = local.database_connection_string
        },
        {
          name  = "TEAMCITY_DB_USER"
          value = local.database_user
        },
        {
          name  = "TEAMCITY_DB_PASSWORD"
          value = local.database_password
        },
        {
          name  = "TEAMCITY_LOGS_PATH"
          value = "/data/teamcity_server/logs"
        }
      ]
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
      file_system_id          = aws_efs_file_system.teamcity_efs_file_system.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.teamcity_efs_data_access_point.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "teamcity_logs"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.teamcity_efs_file_system.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2998
      authorization_config {
        access_point_id = aws_efs_access_point.teamcity_efs_logs_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

# ECS Service
resource "aws_ecs_service" "teamcity" {
  name = local.name_prefix

  cluster                = aws_ecs_cluster.teamcity_cluster.name
  task_definition        = aws_ecs_task_definition.teamcity_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = 1    #TODO: make this configurable
  force_new_deployment   = true #TODO: make this configurable
  enable_execute_command = true #TODO: make this configurable

  wait_for_steady_state = true

  network_configuration {
    subnets         = var.service_subnets
    security_groups = [aws_security_group.teamcity_service_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.teamcity_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  tags = local.tags
}

# TeamCity service security group
resource "aws_security_group" "teamcity_service_sg" {
  name        = "${local.name_prefix}-service-sg"
  vpc_id      = var.vpc_id
  description = "TeamCity service security group"
  tags        = local.tags
}

# TeamCity EFS security group
resource "aws_security_group" "teamcity_efs_sg" {
  name        = "${local.name_prefix}-efs-sg"
  description = "TeamCity EFS mount target security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for NFS traffic from service to EFS
resource "aws_vpc_security_group_ingress_rule" "service_efs" {
  security_group_id            = aws_security_group.teamcity_efs_sg.id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow inbound access from TeamCity service containers to EFS"
  ip_protocol                  = "TCP"
  from_port                    = 2049
  to_port                      = 2049
}

# Ingress rule for NFS traffic from EFS to service
resource "aws_vpc_security_group_ingress_rule" "efs_service" {
  security_group_id            = aws_security_group.teamcity_service_sg.id
  referenced_security_group_id = aws_security_group.teamcity_efs_sg.id
  description                  = "Allow inbound access from EFS to TeamCity service containers"
  ip_protocol                  = "TCP"
  from_port                    = 2049
  to_port                      = 2049
}

# TeamCity Aurora Serverless PostgreSQL security group
resource "aws_security_group" "teamcity_db_sg" {
  name        = "${local.name_prefix}-db-sg"
  description = "TeamCity DB security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for PostgreSQL from service to database cluster
resource "aws_vpc_security_group_ingress_rule" "service_db" {
  security_group_id            = aws_security_group.teamcity_db_sg.id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow inbound access from TeamCity service containers to DB"
  ip_protocol                  = "TCP"
  from_port                    = 5432
  to_port                      = 5432
}

# Ingress rule for PostgreSQL from database cluster to service
resource "aws_vpc_security_group_ingress_rule" "db_service" {
  security_group_id            = aws_security_group.teamcity_service_sg.id
  referenced_security_group_id = aws_security_group.teamcity_db_sg.id
  description                  = "Allow inbound access from DB to TeamCity service containers"
  ip_protocol                  = "TCP"
  from_port                    = 5432
  to_port                      = 5432
}

# Egress rule for database to let all traffic out
resource "aws_vpc_security_group_egress_rule" "db_outbound" {
  security_group_id = aws_security_group.teamcity_db_sg.id
  description       = "Allow outbound access from DB to all"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# TeamCity ALB security group
resource "aws_security_group" "teamcity_alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id
  description = "TeamCity ALB security group"
  tags        = local.tags
}

# Ingress rule to allow ALB to send health checks to service
resource "aws_vpc_security_group_ingress_rule" "alb_service_healthcheck" {
  security_group_id            = aws_security_group.teamcity_service_sg.id
  referenced_security_group_id = aws_security_group.teamcity_alb_sg.id
  description                  = "Allow health checks from ALB to service containers"
  ip_protocol                  = "TCP"
  from_port                    = 80
  to_port                      = 80
}

# Ingress rule for HTTP traffic from ALB to service
resource "aws_vpc_security_group_ingress_rule" "service_inbound_alb" {
  security_group_id            = aws_security_group.teamcity_service_sg.id
  referenced_security_group_id = aws_security_group.teamcity_alb_sg.id
  description                  = "Allow inbound HTTP traffic from ALB to service containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "TCP"

}

# Egress rule for HTTP traffic from ALB to service
resource "aws_vpc_security_group_egress_rule" "service_outbound_alb" {
  security_group_id            = aws_security_group.teamcity_alb_sg.id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow outbound HTTP traffic from ALB to service containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "TCP"

}

# Grant TeamCity service access to internet
resource "aws_vpc_security_group_egress_rule" "internet_outbound" {
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
}
resource "aws_iam_policy" "teamcity_default_policy" {
  name        = "teamcity-default-policy"
  description = "Policy granting permissions for Unreal Horde."
  policy      = data.aws_iam_policy_document.teamcity_default_policy.json
}

resource "aws_iam_role" "teamcity_default_role" {
  name               = "teamcity-default-role"
  description        = "Default role for TeamCity ECS task."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  managed_policy_arns = [
    aws_iam_policy.teamcity_default_policy.arn
  ]

  tags = local.tags
}
resource "aws_iam_role" "teamcity_task_execution_role" {
  name = "teamcity-task-execution-role"

  assume_role_policy  = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
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
  name                       = "${local.name_prefix}-lb"
  security_groups            = [aws_security_group.teamcity_alb_sg.id]
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.alb_subnets
  drop_invalid_header_fields = true
  tags                       = local.tags
}

# TeamCity target group for ALB
resource "aws_lb_target_group" "teamcity_target_group" {
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
  load_balancer_arn = aws_lb.teamcity_external_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.teamcity_target_group.arn
  }
  tags = local.tags
}




# #######################################
# # TeamCity Aurora Serverless Database #
# #######################################
# Subnet group
resource "aws_db_subnet_group" "teamcity_db_subnet_group" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.service_subnets
  tags       = local.tags
}

# # RDS instance with Aurora serverless engine
resource "aws_rds_cluster" "teamcity_db_cluster" {
  cluster_identifier   = "teamcity-cluster"
  engine               = "aurora-postgresql"
  engine_mode          = "provisioned"
  engine_version       = "16.6"
  database_name        = "teamcity"
  master_username      = "teamcity"
  master_password      = "teamcity2025"
  storage_encrypted    = true
  db_subnet_group_name = aws_db_subnet_group.teamcity_db_subnet_group.id
  vpc_security_group_ids = [
    aws_security_group.teamcity_db_sg.id
  ]


  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
}

resource "aws_rds_cluster_instance" "teamcity_db_cluster" {
  cluster_identifier = aws_rds_cluster.teamcity_db_cluster.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.teamcity_db_cluster.engine
  engine_version     = aws_rds_cluster.teamcity_db_cluster.engine_version
}

# ################
# # TeamCity EFS #
# ################

# File system for teamcity
resource "aws_efs_file_system" "teamcity_efs_file_system" {
  creation_token   = "${local.name_prefix}-efs-file-system"
  performance_mode = var.teamcity_efs_performance_mode
  throughput_mode  = var.teamcity_efs_throughput_mode

  #TODO: Parameterize encryption and customer managed key creation
  encrypted = false

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

# # Mount Point for teamcity file system
resource "aws_efs_mount_target" "teamcity_efs_mount_target" {
  count          = length(var.service_subnets)
  file_system_id = aws_efs_file_system.teamcity_efs_file_system.id
  subnet_id      = var.service_subnets[count.index]
  security_groups = [
    aws_security_group.teamcity_efs_sg.id
  ]
}

# TeamCity data directory
resource "aws_efs_access_point" "teamcity_efs_data_access_point" {
  file_system_id = aws_efs_file_system.teamcity_efs_file_system.id
  posix_user {
    gid = 0
    uid = 0
  }
  root_directory {
    path = "/data/teamcity_server/datadir"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 0775
    }

  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-access-point"
  })
}

# TeamCity Log directory
resource "aws_efs_access_point" "teamcity_efs_logs_access_point" {
  file_system_id = aws_efs_file_system.teamcity_efs_file_system.id
  posix_user {
    gid = 0
    uid = 0
  }
  root_directory {
    path = "/data/teamcity_server/logs"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 0775
    }
  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-logs-access-point"
  })
}
