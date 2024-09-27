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

  volume {
    name = "unreal-horde-config"
  }

  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = local.image
      repositoryCredentials = {
        "credentialsParameter" : var.github_credentials_secret_arn
      }
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_api_port
          hostPort      = var.container_api_port
        },
        {
          containerPort = var.container_grpc_port
          hostPort      = var.container_grpc_port
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL", "apt update && apt install curl -y && curl http://localhost:${var.container_api_port}/health/ok || exit 1",
        ]
        interval    = 5
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }
      environment = concat([
        {
          name  = "Horde__databaseConnectionString"
          value = local.database_connection_string
        },
        {
          name  = "Horde__redisConnectionConfig"
          value = local.redis_connection_config
        },
        {
          name  = "Horde__databasePublicCert",
          value = "/app/config/global-bundle.pem"
        }
      ], local.horde_service_env)
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "[APP]"
        }
      },
      mountPoints = [
        {
          sourceVolume  = "unreal-horde-config",
          containerPath = "/app/config"
        }
      ],
      dependsOn = [
        {
          containerName = "unreal-horde-docdb-cert",
          condition     = "COMPLETE"
        }
      ]
    },
    {
      name                     = "unreal-horde-docdb-cert",
      image                    = "bash",
      essential                = false
      command                  = ["wget", "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem", "-P", "/app/config/"]
      readonly_root_filesystem = false
      mountPoints = [
        {
          sourceVolume  = "unreal-horde-config",
          containerPath = "/app/config"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "[DOCDB CERT]"
        }
      },
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
  force_new_deployment = var.debug

  enable_execute_command = var.debug

  wait_for_steady_state = true

  # External target group for API traffic
  dynamic "load_balancer" {
    for_each = var.create_external_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_api_target_group_external[0].arn
      container_name   = var.container_name
      container_port   = var.container_api_port
    }
  }

  # External target group for GRPC traffic
  dynamic "load_balancer" {
    for_each = var.create_external_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_grpc_target_group_external[0].arn
      container_name   = var.container_name
      container_port   = var.container_grpc_port
    }
  }

  # Internal target group for API traffic
  dynamic "load_balancer" {
    for_each = var.create_internal_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_api_target_group_internal[0].arn
      container_name   = var.container_name
      container_port   = var.container_api_port
    }
  }

  # Internal target group for GRPC traffic
  dynamic "load_balancer" {
    for_each = var.create_internal_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_grpc_target_group_internal[0].arn
      container_name   = var.container_name
      container_port   = var.container_grpc_port
    }
  }

  network_configuration {
    subnets         = var.unreal_horde_service_subnets
    security_groups = [aws_security_group.unreal_horde_sg.id]
  }

  tags = local.tags

  depends_on = [aws_docdb_cluster_instance.horde, aws_elasticache_cluster.horde]
}
