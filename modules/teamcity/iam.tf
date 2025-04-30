#############################################
# IAM Roles for TeamCity Module
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

  #grant the task necessary EFS permissions to be able to modify directories
  statement {
    sid    = "EFS"
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientMount"
    ]
    resources = [
      local.efs_file_system_arn
    ]
  }
}

resource "aws_iam_policy" "teamcity_default_policy" {
  name        = "teamcity-default-policy"
  description = "Policy granting permissions for TeamCity."
  policy      = data.aws_iam_policy_document.teamcity_default_policy.json
}

resource "aws_iam_role" "teamcity_default_role" {
  name               = "teamcity-default-role"
  description        = "Default role for TeamCity ECS task."
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

  dynamic "inline_policy" {
    for_each = var.database_connection_string == null ? [1] : []
    content {
      name = "teamcity-secrets-access"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "SecretsManager"
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue"
            ]
            Resource = [
              aws_rds_cluster.teamcity_db_cluster[0].master_user_secret[0].secret_arn
            ]
          }
        ]
      })
    }
  }

}