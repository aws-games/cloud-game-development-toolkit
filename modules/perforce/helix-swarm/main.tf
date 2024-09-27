# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "helix_swarm_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "helix_swarm_cluster_fargate_providers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.helix_swarm_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "helix_swarm_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.helix_swarm_cloudwatch_log_retention_in_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "helix_swarm_redis_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-redis-log-group"
  retention_in_days = var.helix_swarm_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Define swarm task definition
resource "aws_ecs_task_definition" "helix_swarm_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.helix_swarm_container_cpu
  memory                   = var.helix_swarm_container_memory

  volume {
    name = local.helix_swarm_data_volume_name
  }

  container_definitions = jsonencode(
    [
      {
        name      = var.helix_swarm_container_name,
        image     = local.helix_swarm_image,
        cpu       = var.helix_swarm_container_cpu,
        memory    = var.helix_swarm_container_memory,
        essential = true,
        portMappings = [
          {
            containerPort = var.helix_swarm_container_port,
            hostPort      = var.helix_swarm_container_port
            protocol      = "tcp"
          }
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://localhost:${var.helix_swarm_container_port}/login || exit 1"]
          startPeriod = 30
        }
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.helix_swarm_service_log_group.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "helix-swarm"
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
            value = var.fqdn
          },
          {
            name  = "SWARM_REDIS"
            value = var.existing_redis_connection != null ? var.existing_redis_connection.host : aws_elasticache_cluster.swarm[0].cache_nodes[0].address
          },
          {
            name  = "SWARM_REDIS_PORT"
            value = var.existing_redis_connection != null ? tostring(var.existing_redis_connection.port) : tostring(aws_elasticache_cluster.swarm[0].cache_nodes[0].port)
          }
        ],
        readonlyRootFilesystem = false
        mountPoints = [
          {
            sourceVolume  = local.helix_swarm_data_volume_name
            containerPath = local.helix_swarm_data_path
            readOnly      = false
          }
        ],
      },
      {
        name      = local.helix_swarm_data_volume_name
        image     = "bash"
        essential = false
        // Only run this command if enable_sso is set
        command = concat([], var.enable_sso ? [
          "sh",
          "-c",
          "echo \"/p4/a\\\t'sso' => 'enabled',\" > ${local.helix_swarm_data_path}/sso.sed && sed -i -f ${local.helix_swarm_data_path}/sso.sed ${local.helix_swarm_data_path}/config.php && rm -rf ${local.helix_swarm_data_path}/cache",
        ] : []),
        readonly_root_filesystem = false

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.helix_swarm_service_log_group.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = local.helix_swarm_data_volume_name
          }
        }
        mountPoints = [
          {
            sourceVolume  = local.helix_swarm_data_volume_name
            containerPath = local.helix_swarm_data_path
          }
        ],
        dependsOn = [
          {
            containerName = var.helix_swarm_container_name
            condition     = "HEALTHY"
          }
        ]
      }
    ]
  )

  task_role_arn      = var.custom_helix_swarm_role != null ? var.custom_helix_swarm_role : aws_iam_role.helix_swarm_default_role[0].arn
  execution_role_arn = aws_iam_role.helix_swarm_task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Define swarm service
resource "aws_ecs_service" "helix_swarm_service" {
  name = "${local.name_prefix}-service"

  cluster                = var.cluster_name != null ? data.aws_ecs_cluster.helix_swarm_cluster[0].arn : aws_ecs_cluster.helix_swarm_cluster[0].arn
  task_definition        = aws_ecs_task_definition.helix_swarm_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = var.helix_swarm_desired_container_count
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  load_balancer {
    target_group_arn = aws_lb_target_group.helix_swarm_alb_target_group.arn
    container_name   = var.helix_swarm_container_name
    container_port   = var.helix_swarm_container_port
  }

  network_configuration {
    subnets         = var.helix_swarm_service_subnets
    security_groups = [aws_security_group.helix_swarm_service_sg.id]
  }

  tags = local.tags

  depends_on = [aws_elasticache_cluster.swarm]
}
