resource "aws_ecs_cluster" "teamcity_cluster" {
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}
resource "aws_ecs_task_definition" "teamcity_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory


  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = local.image
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
      },
    }
  ])

  tags = {
    Name = var.name
  }
   task_role_arn      = aws_iam_role.teamcity_default_role.arn
   execution_role_arn = aws_iam_role.teamcity_task_execution_role.arn
}

resource "aws_ecs_service" "teamcity" {
  name = local.name_prefix

  cluster                = aws_ecs_cluster.teamcity_cluster.name
  task_definition        = aws_ecs_task_definition.teamcity_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = 1 #TODO: make this configurable
  force_new_deployment   = true #TODO: make this configurable
  enable_execute_command = true #TODO: make this configurable

  wait_for_steady_state = true

  network_configuration {
    subnets         = var.service_subnets
    security_groups = [aws_security_group.teamcity_service_sg.id]
  }

  tags = local.tags
}

# TeamCity service security group
resource "aws_security_group" "teamcity_service_sg" {
  name   = "${local.name_prefix}-sg"
  vpc_id = var.vpc_id

  tags = local.tags
}

# Grant TeamCity service access to internet
resource "aws_vpc_security_group_egress_rule" "internet_outbound" {

  security_group_id = aws_security_group.teamcity_service_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#############################################
# IAM Roles for Unreal Engine Horde Module
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