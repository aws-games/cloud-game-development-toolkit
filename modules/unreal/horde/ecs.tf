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
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      environment = [
        {
          name  = "Horde__databaseConnectionString"
          value = local.database_connection_string
        },
        {
          name  = "Horde__redisConnectionConfig"
          value = local.redis_connection_config
        },
        {
          name  = "Horde__authMethod"
          value = var.auth_method
        },
        {
          name  = "Horde__oidcAuthority"
          value = var.oidc_authority
        },
        {
          name  = "Horde__oidcAudience",
          value = var.oidc_audience
        },
        {
          name  = "Horde__oidcClientId"
          value = var.oidc_client_id
        },
        {
          name  = "Horde__oidcClientSecret"
          value = var.oidc_client_secret
        },
        {
          name  = "Horde__oidcSigninRedirect"
          value = var.oidc_signin_redirect
        },
        {
          name  = "Horde__adminClaimType"
          value = var.admin_claim_type
        },
        {
          name  = "Horde__adminClaimValue"
          value = var.admin_claim_value
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ue-horde"
        }
      }
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
  force_new_deployment = true

  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.unreal_horde_alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }
  network_configuration {
    subnets         = var.unreal_horde_subnets
    security_groups = [aws_security_group.unreal_horde_sg.id]
  }

  tags = local.tags
}

# - Trust Relationships -
#  ECS - Tasks
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

# - Policies -
data "aws_iam_policy_document" "unreal_horde_default_policy" {
  count = var.create_unreal_horde_default_policy ? 1 : 0
  # ECS
  statement {
    sid    = "ECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:CreateControlChannel"
    ]
    resources = [
      "*"
    ]
  }
}


resource "aws_iam_policy" "unreal_horde_default_policy" {
  count = var.create_unreal_horde_default_policy ? 1 : 0

  name        = "${var.project_prefix}-unreal_horde-default-policy"
  description = "Policy granting permissions for Unreal Horde."
  policy      = data.aws_iam_policy_document.unreal_horde_default_policy[0].json
}



# - Roles -
resource "aws_iam_role" "unreal_horde_default_role" {
  count = var.create_unreal_horde_default_role ? 1 : 0

  name               = "${var.project_prefix}-unreal_horde-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  managed_policy_arns = [
    aws_iam_policy.unreal_horde_default_policy[0].arn
  ]
  tags = local.tags
}

data "aws_iam_policy_document" "unreal_horde_secrets_manager_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.github_credentials_secret_arn
    ]
  }
}

resource "aws_iam_policy" "unreal_horde_secrets_manager_policy" {
  name        = "${var.project_prefix}-unreal-horde-secrets-manager-policy"
  description = "Policy granting permissions for Unreal Horde task execution role to access SSM."
  policy      = data.aws_iam_policy_document.unreal_horde_secrets_manager_policy.json
}


resource "aws_iam_role" "unreal_horde_task_execution_role" {
  name = "${var.project_prefix}-unreal_horde-task-execution-role"

  assume_role_policy  = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy", aws_iam_policy.unreal_horde_secrets_manager_policy.arn]
}
