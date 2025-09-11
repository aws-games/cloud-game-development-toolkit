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
}
data "aws_iam_policy_document" "unreal_horde_elasticache_policy" {
  count = var.custom_cache_connection_config == null ? 1 : 0
  # Elasticache
  statement {
    sid    = "ElasticacheConnect"
    effect = "Allow"
    actions = [
      "elasticache:Connect"
    ]
    resources = (var.elasticache_engine == "redis" ?
      [aws_elasticache_cluster.horde[0].arn] :
    [aws_elasticache_replication_group.horde[0].arn])

  }
}
data "aws_iam_policy_document" "unreal_horde_recycle_policy" {
  count = var.create_unreal_horde_recycle_policy ? 1 : 0
  # EC2
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:ModifyInstanceAttribute",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "unreal_horde_default_policy" {
  count = var.create_unreal_horde_default_policy ? 1 : 0

  name        = "${var.project_prefix}-unreal_horde-default-policy"
  description = "Policy granting permissions for Unreal Horde."
  policy      = data.aws_iam_policy_document.unreal_horde_default_policy[0].json
}

resource "aws_iam_policy" "unreal_horde_elasticache_policy" {
  count = var.custom_cache_connection_config == null ? 1 : 0

  name        = "${var.project_prefix}-unreal_horde-elasticache-policy"
  description = "Policy granting elasticache connect permissions for Unreal Horde."
  policy      = data.aws_iam_policy_document.unreal_horde_elasticache_policy[0].json
}

resource "aws_iam_policy" "unreal_horde_recycle_policy" {
  count = var.create_unreal_horde_recycle_policy ? 1 : 0

  name        = "${var.project_prefix}-unreal_horde-recycle-policy"
  description = "Policy granting Unreal Horde access to EC2 for agent reuse/recycling."
  policy      = data.aws_iam_policy_document.unreal_horde_recycle_policy[0].json
}

resource "aws_iam_role" "unreal_horde_default_role" {
  count = var.create_unreal_horde_default_role ? 1 : 0

  name               = "${var.project_prefix}-unreal_horde-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "unreal_horde_s3_policy_attachment" {
  count = length(var.agents) > 0 ? 1 : 0

  role       = aws_iam_role.unreal_horde_default_role[0].name
  policy_arn = aws_iam_policy.horde_agents_s3_policy[0].arn
}

#conditionally attach elasticache policy to default role
resource "aws_iam_role_policy_attachment" "unreal_horde_elasticache_policy_attachment" {
  count = var.custom_cache_connection_config == null ? 1 : 0

  role       = aws_iam_role.unreal_horde_default_role[0].name
  policy_arn = aws_iam_policy.unreal_horde_elasticache_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "unreal_horde_default_policy_attachment" {
  count = var.create_unreal_horde_default_policy ? 1 : 0

  role       = aws_iam_role.unreal_horde_default_role[0].name
  policy_arn = aws_iam_policy.unreal_horde_default_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "unreal_horde_recycle_attachment" {
  count = var.create_unreal_horde_recycle_policy ? 1 : 0

  role       = aws_iam_role.unreal_horde_default_role[0].name
  policy_arn = aws_iam_policy.unreal_horde_recycle_policy[0].arn
}

data "aws_iam_policy_document" "unreal_horde_secrets_manager_policy" {
  count = var.github_credentials_secret_arn != null || var.p4_super_user_username_secret_arn != null ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = concat(
      var.github_credentials_secret_arn != null ? [
        var.github_credentials_secret_arn
      ] : [],
      var.p4_super_user_username_secret_arn != null ? [
        var.p4_super_user_username_secret_arn,
        var.p4_super_user_password_secret_arn,
      ] : [],
      var.dex_auth_secret_arn != null ? [
        var.dex_auth_secret_arn,
      ] : []
    )
  }
}

resource "aws_iam_policy" "unreal_horde_secrets_manager_policy" {
  count       = var.github_credentials_secret_arn != null || var.p4_super_user_username_secret_arn != null ? 1 : 0
  name        = "${var.project_prefix}-unreal-horde-secrets-manager-policy"
  description = "Policy granting permissions for Unreal Horde task execution role to access SSM."
  policy      = data.aws_iam_policy_document.unreal_horde_secrets_manager_policy[0].json
}

resource "aws_iam_role" "unreal_horde_task_execution_role" {
  name = "${var.project_prefix}-unreal_horde-task-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
}

resource "aws_iam_role_policy_attachment" "unreal_horde_task_execution_policy_attachment" {
  role       = aws_iam_role.unreal_horde_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "unreal_horde_secrets_manager_policy_attachment" {
  count = var.github_credentials_secret_arn != null || var.p4_super_user_username_secret_arn != null ? 1 : 0

  role       = aws_iam_role.unreal_horde_task_execution_role.name
  policy_arn = aws_iam_policy.unreal_horde_secrets_manager_policy[0].arn
}
