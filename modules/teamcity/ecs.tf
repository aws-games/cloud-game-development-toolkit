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
  name                   = local.name_prefix
  cluster                = var.cluster_name != null ? data.aws_ecs_cluster.teamcity_cluster[0].arn : aws_ecs_cluster.teamcity_cluster[0].arn
  task_definition        = aws_ecs_task_definition.teamcity_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = var.desired_container_count
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

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

  depends_on = [
    aws_rds_cluster.teamcity_db_cluster[0],
    aws_rds_cluster_instance.teamcity_db_cluster_instance
  ]

  tags = local.tags
}