##########################################
# Random Strings
##########################################
# - Random Strings to prevent naming conflicts -
resource "random_string" "p4_auth" {
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
      var.admin_username_secret_arn == null ? awscc_secretsmanager_secret.admin_username[0].secret_id : var.admin_username_secret_arn,
      var.admin_password_secret_arn == null ? awscc_secretsmanager_secret.admin_password[0].secret_id : var.admin_password_secret_arn,
    ]
  }
}

# Secrets Manager Policy Document
data "aws_iam_policy_document" "secrets_manager_policy" {
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
      var.admin_username_secret_arn == null ? awscc_secretsmanager_secret.admin_username[0].secret_id : var.admin_username_secret_arn,
      var.admin_password_secret_arn == null ? awscc_secretsmanager_secret.admin_password[0].secret_id : var.admin_password_secret_arn,
    ]
  }
}

data "aws_iam_policy_document" "helix_authentication_service_scim_secrets_manager_policy" {
  count = var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null && var.scim_bearer_token_arn != null ? 1 : 0
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
      var.p4d_super_user_arn,
      var.p4d_super_user_password_arn,
      var.scim_bearer_token_arn,
    ]
  }
}

resource "aws_iam_policy" "scim_secrets_manager_policy" {
  count       = var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null && var.scim_bearer_token_arn != null ? 1 : 0
  name        = "${var.project_prefix}-helix-auth-scim-ssm-policy"
  description = "Policy granting permissions for Helix Auth task execution role to access secrets in SSM required for enabling SCIM."
  policy      = data.aws_iam_policy_document.helix_authentication_service_scim_secrets_manager_policy[0].json
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
# Default Role
resource "aws_iam_role" "default_role" {
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

resource "aws_iam_role_policy_attachment" "task_execution_role_ecs" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_execution_role_secrets_manager" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}
resource "aws_iam_role_policy_attachment" "task_execution_role_scim_secrets_manager" {
  count      = var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null && var.scim_bearer_token_arn != null ? 1 : 0
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.scim_secrets_manager_policy[0].arn
}
