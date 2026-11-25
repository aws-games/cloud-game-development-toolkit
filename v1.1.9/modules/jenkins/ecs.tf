# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "jenkins_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "jenkins_cluster_fargate_rpvodiers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.jenkins_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "jenkins_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.jenkins_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Define Jenkins task definition
resource "aws_ecs_task_definition" "jenkins_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  container_definitions = jsonencode([
    {
      name      = var.container_name,
      image     = local.jenkins_image,
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
          awslogs-group         = aws_cloudwatch_log_group.jenkins_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jenkins"
        }
      }

      readonlyRootFilesystem = false
      mountPoints = [
        {
          containerPath = local.jenkins_home_path,
          sourceVolume  = "jenkins_data",
          readOnly      = false,
        }
      ]
    }
  ])

  task_role_arn      = var.custom_jenkins_role != null ? var.custom_jenkins_role : aws_iam_role.jenkins_default_role[0].arn
  execution_role_arn = aws_iam_role.jenkins_task_execution_role.arn

  volume {
    name = "jenkins_data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.jenkins_efs_file_system.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.jenkins_efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Define Jenkins service
resource "aws_ecs_service" "jenkins_service" {
  name = "${local.name_prefix}-service"

  cluster              = var.cluster_name != null ? data.aws_ecs_cluster.jenkins_cluster[0].arn : aws_ecs_cluster.jenkins_cluster[0].arn
  task_definition      = aws_ecs_task_definition.jenkins_task_definition.arn
  launch_type          = "FARGATE"
  desired_count        = var.jenkins_service_desired_container_count
  force_new_deployment = true

  load_balancer {
    target_group_arn = aws_lb_target_group.jenkins_alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets         = var.jenkins_service_subnets
    security_groups = [aws_security_group.jenkins_service_sg.id]
  }

  tags = local.tags
}
