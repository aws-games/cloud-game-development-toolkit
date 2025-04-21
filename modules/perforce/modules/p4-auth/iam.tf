# - Random Strings to prevent naming conflicts -
resource "random_string" "helix_authentication_service" {
  length  = 4
  special = false
  upper   = false
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
# helix_authentication_service
data "aws_iam_policy_document" "helix_authentication_service_default_policy" {
  count = var.create_helix_authentication_service_default_policy ? 1 : 0
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
      var.helix_authentication_service_admin_username_secret_arn == null ? awscc_secretsmanager_secret.helix_authentication_service_admin_username[0].secret_id : var.helix_authentication_service_admin_username_secret_arn,
      var.helix_authentication_service_admin_password_secret_arn == null ? awscc_secretsmanager_secret.helix_authentication_service_admin_password[0].secret_id : var.helix_authentication_service_admin_password_secret_arn,
    ]
  }
}


resource "aws_iam_policy" "helix_authentication_service_default_policy" {
  count = var.create_helix_authentication_service_default_policy ? 1 : 0

  name        = "${var.project_prefix}-helix-authentication-service-default-policy"
  description = "Policy granting permissions for helix-authentication-service."
  policy      = data.aws_iam_policy_document.helix_authentication_service_default_policy[0].json

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-authentication-service-default-policy"
    }
  )
}



# - Roles -
# helix_authentication_service
resource "aws_iam_role" "helix_authentication_service_default_role" {
  count              = var.create_helix_authentication_service_default_role ? 1 : 0
  name               = "${var.project_prefix}-helix-authentication-service-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-authentication-service-default-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "helix_authentication_service_default_role" {
  count      = var.create_helix_authentication_service_default_role ? 1 : 0
  role       = aws_iam_role.helix_authentication_service_default_role[0].name
  policy_arn = aws_iam_policy.helix_authentication_service_default_policy[0].arn
}

data "aws_iam_policy_document" "helix_authentication_service_secrets_manager_policy" {
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
      var.helix_authentication_service_admin_username_secret_arn == null ? awscc_secretsmanager_secret.helix_authentication_service_admin_username[0].secret_id : var.helix_authentication_service_admin_username_secret_arn,
      var.helix_authentication_service_admin_password_secret_arn == null ? awscc_secretsmanager_secret.helix_authentication_service_admin_password[0].secret_id : var.helix_authentication_service_admin_password_secret_arn,
    ]
  }
}

resource "aws_iam_policy" "helix_authentication_service_secrets_manager_policy" {
  name        = "${var.project_prefix}-helix-authentication-service-secrets-manager-policy"
  description = "Policy granting permissions for helix-authentication-service task execution role to access SSM."
  policy      = data.aws_iam_policy_document.helix_authentication_service_secrets_manager_policy.json

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-authentication-service-secrets-manager-policy"
    }
  )
}

data "aws_iam_policy_document" "helix_authentication_service_scim_secrets_manager_policy" {
  count  = var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null && var.scim_bearer_token_arn != null ? 1 : 0
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

resource "aws_iam_policy" "helix_authentication_service_scim_secrets_manager_policy" {
  count  = var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null && var.scim_bearer_token_arn != null ? 1 : 0
  name        = "${var.project_prefix}-helix-auth-scim-ssm-policy"
  description = "Policy granting permissions for Helix Auth task execution role to access secrets in SSM required for enabling SCIM."
  policy      = data.aws_iam_policy_document.helix_authentication_service_scim_secrets_manager_policy[0].json
}

resource "aws_iam_role" "helix_authentication_service_task_execution_role" {
  name               = "${var.project_prefix}-helix-authentication-service-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-authentication-service-task-execution-role"
    }
  )
}
resource "aws_iam_role_policy_attachment" "helix_authentication_service_task_execution_role_ecs" {
  role       = aws_iam_role.helix_authentication_service_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "helix_authentication_service_task_execution_role_secrets_manager" {
  role       = aws_iam_role.helix_authentication_service_task_execution_role.name
  policy_arn = aws_iam_policy.helix_authentication_service_secrets_manager_policy.arn
}
resource "aws_iam_role_policy_attachment" "helix_authentication_service_task_execution_role_scim_secrets_manager" {
  count      = var.p4d_super_user_arn != null && var.p4d_super_user_password_arn != null && var.scim_bearer_token_arn != null ? 1 : 0
  role       = aws_iam_role.helix_authentication_service_task_execution_role.name
  policy_arn = aws_iam_policy.helix_authentication_service_scim_secrets_manager_policy[0].arn
}