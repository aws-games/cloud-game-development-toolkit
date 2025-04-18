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
      "ssmmessages:CreateControlChannel",
    ]
    resources = [
      "*"
    ]
  }
  # Elasticache
  statement {
    sid    = "ElasticacheConnect"
    effect = "Allow"
    actions = [
      "elasticache:Connect"
    ]
    resources = [
      aws_elasticache_cluster.horde[0].arn,
    ]
  }
}

resource "aws_iam_policy" "unreal_horde_default_policy" {
  count = var.create_unreal_horde_default_policy ? 1 : 0

  name        = "${var.project_prefix}-unreal_horde-default-policy"
  description = "Policy granting permissions for Unreal Horde."
  policy      = data.aws_iam_policy_document.unreal_horde_default_policy[0].json
}

resource "aws_iam_role" "unreal_horde_default_role" {
  count = var.create_unreal_horde_default_role ? 1 : 0

  name               = "${var.project_prefix}-unreal_horde-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "unreal_horde_default_role" {
  count      = var.create_unreal_horde_default_role ? 1 : 0
  role       = aws_iam_role.unreal_horde_default_role[0].name
  policy_arn = aws_iam_policy.unreal_horde_default_policy[0].arn
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
  name               = "${var.project_prefix}-unreal_horde-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
}

resource "aws_iam_role_policy_attachment" "unreal_horde_task_execution_role_ecs" {
  role       = aws_iam_role.unreal_horde_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "unreal_horde_task_execution_role_secrets_manager" {
  role       = aws_iam_role.unreal_horde_task_execution_role.name
  policy_arn = aws_iam_policy.unreal_horde_secrets_manager_policy.arn
}
