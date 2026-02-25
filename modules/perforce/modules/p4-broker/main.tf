##########################################
# ECS | Cluster
##########################################
# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cluster"
  })
}


##########################################
# ECS Cluster | Capacity Providers
##########################################
resource "aws_ecs_cluster_capacity_providers" "cluster_fargate_providers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}


##########################################
# ECS | Task Definition
##########################################
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${local.name_prefix}-task-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  volume {
    name = local.config_volume_name
  }

  container_definitions = jsonencode([
    {
      name      = var.container_name,
      image     = var.container_image,
      cpu       = var.container_cpu,
      memory    = var.container_memory,
      essential = true,
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port,
          protocol      = "tcp"
        }
      ]
      environment = concat(
        [],
        var.extra_env != null ? [for key, value in var.extra_env : {
          name  = key
          value = value
        }] : [],
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "${local.name_prefix}-service"
        }
      }
      mountPoints = [
        {
          sourceVolume  = local.config_volume_name
          containerPath = local.config_path
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL", "cat /proc/net/tcp | grep $(printf '%X' ${var.container_port}) || exit 1"
        ]
        startPeriod = 30
      }
      dependsOn = [
        {
          containerName = "${var.container_name}-config"
          condition     = "COMPLETE"
        }
      ]
    },
    {
      name                     = "${var.container_name}-config"
      image                    = "amazon/aws-cli"
      essential                = false
      command                  = ["s3", "cp", "s3://${aws_s3_bucket.broker_config.id}/${aws_s3_object.broker_config.key}", "${local.config_path}/p4broker.conf"]
      readonly_root_filesystem = false
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "${local.name_prefix}-service-config"
        }
      }
      mountPoints = [
        {
          sourceVolume  = local.config_volume_name
          containerPath = local.config_path
        }
      ]
    }
  ])

  task_role_arn      = var.custom_role != null ? var.custom_role : aws_iam_role.default_role[0].arn
  execution_role_arn = aws_iam_role.task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-task-definition"
  })
}


##########################################
# ECS | Service
##########################################
resource "aws_ecs_service" "service" {
  name = "${local.name_prefix}-service"

  cluster         = var.cluster_name != null ? data.aws_ecs_cluster.cluster[0].arn : aws_ecs_cluster.cluster[0].arn
  task_definition = aws_ecs_task_definition.task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  force_delete           = true
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  wait_for_steady_state = true

  load_balancer {
    target_group_arn = aws_lb_target_group.nlb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.ecs_service.id]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }

  timeouts {
    create = "20m"
  }

  depends_on = [aws_lb_target_group.nlb_target_group]
}


##########################################
# CloudWatch
##########################################
resource "aws_cloudwatch_log_group" "log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-log-group"
  })
}
