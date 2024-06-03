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

resource "aws_cloudwatch_log_group" "swarm_redis_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-redis-log-group"
  retention_in_days = var.swarm_cloudwatch_log_retention_in_days
  tags              = local.tags
}


# Define swarm task definition
resource "aws_ecs_task_definition" "swarm_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  container_definitions = jsonencode(
    concat(
      var.existing_redis_host == null ? [
        {
          name      = var.redis_container_name,
          image     = var.redis_image,
          cpu       = var.redis_container_cpu,
          memory    = var.redis_container_memory,
          essential = true,
          portMappings = [
            {
              containerPort = var.redis_container_port
              hostPort      = var.redis_container_port
              protocol      = "tcp"
            }
          ]
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = aws_cloudwatch_log_group.swarm_redis_service_log_group.name
              awslogs-region        = data.aws_region.current.name
              awslogs-stream-prefix = "redis"
            }
          }
          readonlyRootFilesystem = false
          mountPoints = var.enable_elastic_filesystem ? [
            {
              containerPath = local.helix_swarm_redis_data_path,
              sourceVolume  = "redis_data",
              readOnly      = false,
            }
          ] : []
      }] : [],
      [{
        name      = var.swarm_container_name,
        image     = local.swarm_image,
        cpu       = var.swarm_container_cpu,
        memory    = var.swarm_container_memory,
        essential = true,
        portMappings = [
          {
            containerPort = var.swarm_container_port,
            hostPort      = var.swarm_container_port
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
        secrets = [
          {
            name      = "P4D_SUPER",
            valueFrom = var.p4d_super_user_arn
          },
          {
            name      = "P4D_SUPER_PASSWD",
            valueFrom = var.p4d_super_user_password_arn
          },
          {
            name      = "SWARM_USER"
            valueFrom = var.p4d_swarm_user_arn
          },
          {
            name      = "SWARM_PASSWD"
            valueFrom = var.p4d_swarm_password_arn
          }
        ]
        environment = [
          {
            name  = "P4D_PORT",
            value = var.p4d_port
          },
          {
            name  = "SWARM_HOST"
            value = var.swarm_host
          },
          {
            name  = "SWARM_REDIS"
            value = var.existing_redis_host != null ? var.existing_redis_host : "127.0.0.1"
          },
          {
            name  = "SWARM_REDIS_PORT"
            value = tostring(var.redis_container_port)
          }
        ],
        readonlyRootFilesystem = false
        mountPoints = var.enable_elastic_filesystem ? [
          {
            containerPath = local.helix_swarm_config_path,
            sourceVolume  = "swarm_data",
            readOnly      = false,
          }
        ] : []
      }]
  ))

  task_role_arn      = var.custom_swarm_role != null ? var.custom_swarm_role : aws_iam_role.swarm_default_role[0].arn
  execution_role_arn = aws_iam_role.swarm_task_execution_role.arn

  dynamic "volume" {
    for_each = var.enable_elastic_filesystem ? [1] : []
    content {
      name = "swarm_data"
      efs_volume_configuration {
        file_system_id     = aws_efs_file_system.swarm_efs_file_system[0].id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = aws_efs_access_point.swarm_efs_access_point[0].id
          iam             = "ENABLED"
        }
      }
    }
  }

  dynamic "volume" {
    for_each = var.enable_elastic_filesystem ? [1] : []
    content {
      name = "redis_data"
      efs_volume_configuration {
        file_system_id     = aws_efs_file_system.swarm_efs_file_system[0].id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = aws_efs_access_point.redis_efs_access_point[0].id
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
  desired_count        = var.swarm_desired_container_count
  force_new_deployment = true

  load_balancer {
    target_group_arn = aws_lb_target_group.swarm_alb_target_group.arn
    container_name   = var.swarm_container_name
    container_port   = var.swarm_container_port
  }

  network_configuration {
    subnets         = var.swarm_service_subnets
    security_groups = [aws_security_group.swarm_service_sg.id]
  }

  tags = local.tags
}

