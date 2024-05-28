
# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "swarm_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "swarm_cluster_fargate_rpvodiers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.swarm_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "swarm_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.swarm_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Define swarm task definition
resource "aws_ecs_task_definition" "swarm_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  container_definitions = jsonencode([
    {
      name      = var.container_name,
      image     = local.swarm_image,
      cpu       = var.container_cpu,
      memory    = var.container_memory,
      essential = true,
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.swarm_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "swarm"
        }
      }
      environment = concat(
        [
          {
            name  = "P4D_PORT",
            value = var.p4d_port
          },
          {
            name  = "P4D_SUPER",
            value = "perforce"
          },
          {
            name  = "P4D_SUPER_PASSWD",
            value = "GudL0ngAdminP@sswerd"
          },
          { name  = "SWARM_USER",
            value = "perforce"
          },
          {
            name  = "SWARM_PASSWD",
            value = "GudL0ngAdminP@sswerd"
          }
        ],
        var.enable_elasticache_serverless ? [
          { name  = "SWARM_REDIS",
            value = tostring(aws_elasticache_serverless_cache.swarm_elasticache[0].endpoint[0].address)
          },
          {
            name  = "SWARM_REDIS_PORT",
            value = tostring(aws_elasticache_serverless_cache.swarm_elasticache[0].endpoint[0].port)
          }
        ] : []
      )
      readonlyRootFilesystem = false
      mountPoints = var.enable_elastic_filesystem ? [
        {
          containerPath = local.helix_swarm_config_path,
          sourceVolume  = "swarm_data",
          readOnly      = false,
        }
      ] : []
    }
  ])

  task_role_arn      = var.custom_swarm_role != null ? var.custom_swarm_role : aws_iam_role.swarm_default_role[0].arn
  execution_role_arn = aws_iam_role.swarm_task_execution_role.arn

  dynamic "volume" {
    for_each = var.enable_elastic_filesystem ? [1] : []
    content {
      name = "swarm_data"
      efs_volume_configuration {
        file_system_id          = aws_efs_file_system.swarm_efs_file_system[0].id
        transit_encryption      = "ENABLED"
        transit_encryption_port = 2999
        authorization_config {
          access_point_id = aws_efs_access_point.swarm_efs_access_point[0].id
          iam             = "ENABLED"
        }
      }
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Define swarm service
resource "aws_ecs_service" "swarm_service" {
  name = "${local.name_prefix}-service"

  cluster              = var.cluster_name != null ? data.aws_ecs_cluster.swarm_cluster[0].arn : aws_ecs_cluster.swarm_cluster[0].arn
  task_definition      = aws_ecs_task_definition.swarm_task_definition.arn
  launch_type          = "FARGATE"
  desired_count        = var.desired_container_count
  force_new_deployment = true

  load_balancer {
    target_group_arn = aws_lb_target_group.swarm_alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets         = var.swarm_service_subnets
    security_groups = [aws_security_group.swarm_service_sg.id]
  }

  tags = local.tags
}

# Redis elasticache serverless for Swarm
resource "aws_elasticache_serverless_cache" "swarm_elasticache" {
  count  = var.enable_elasticache_serverless ? 1 : 0
  engine = "redis"
  name   = "${local.name_prefix}-redis"
  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }
  description          = "Serverless Redis for Helix Swarm"
  major_engine_version = "7"
  security_group_ids   = [aws_security_group.swarm_elasticache_sg[0].id]
  subnet_ids           = var.swarm_service_subnets
}


