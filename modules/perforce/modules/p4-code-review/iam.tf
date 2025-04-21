##########################################
# Random Strings
##########################################
# - Random Strings to prevent naming conflicts -
resource "random_string" "p4_code_review" {
  length  = 2
  special = false
  upper   = false
}


##########################################
# Trust Relationships
##########################################
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


##########################################
# Policies
##########################################
# Default Policy Document
data "aws_iam_policy_document" "default_policy" {
  count = var.create_default_role ? 1 : 0
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
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetRandomPassword",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:BatchGetSecretValue"
    ]
    resources = [
      var.super_user_username_secret_arn,
      var.super_user_password_secret_arn,
      var.p4_code_review_user_username_secret_arn,
      var.p4_code_review_user_password_secret_arn,
    ]
  }
}

# Secrets Manager Policy Document
data "aws_iam_policy_document" "secrets_manager_policy" {
  # ssm
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetRandomPassword",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:BatchGetSecretValue"
    ]
    resources = [
      var.super_user_username_secret_arn,
      var.super_user_password_secret_arn,
      var.p4_code_review_user_username_secret_arn,
      var.p4_code_review_user_password_secret_arn,
    ]
  }
}

# Default Policy
resource "aws_iam_policy" "default_policy" {
  count = var.create_default_role ? 1 : 0

  name        = "${local.name_prefix}-default-policy"
  description = "Policy granting permissions for ${local.name_prefix}."
  policy      = data.aws_iam_policy_document.default_policy[0].json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-default-policy"
    }
  )
}

# Secrets Manager Policy
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "${local.name_prefix}-secrets-manager-policy"
  description = "Policy granting permissions for ${local.name_prefix} task execution role to access Secrets Manager."
  policy      = data.aws_iam_policy_document.secrets_manager_policy.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-secrets-manager-policy"
    }
  )
}


##########################################
# Roles
##########################################
resource "aws_iam_role" "default_role" {
  # Default Role
  count              = var.create_default_role ? 1 : 0
  name               = "${local.name_prefix}-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-default-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "default_role" {
  count      = var.create_default_role ? 1 : 0
  role       = aws_iam_role.default_role[0].name
  policy_arn = aws_iam_policy.default_policy[0].arn
}

# Task Execution Role
resource "aws_iam_role" "task_execution_role" {
  name               = "${local.name_prefix}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "p4_auth_task_execution_role_ecs" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "p4_auth_task_execution_role_secrets_manager" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}
