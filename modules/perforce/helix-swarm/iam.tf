# - Random Strings to prevent naming conflicts -
resource "random_string" "swarm" {
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
# swarm
data "aws_iam_policy_document" "swarm_default_policy" {
  count = var.create_swarm_default_policy ? 1 : 0
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

data "aws_iam_policy_document" "swarm_efs_policy" {
  count = var.enable_elastic_filesystem ? 1 : 0
  # EFS
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientMount"
    ]
    resources = [
      aws_efs_file_system.swarm_efs_file_system[0].arn
    ]
  }
}

resource "aws_iam_policy" "swarm_default_policy" {
  count = var.create_swarm_default_policy ? 1 : 0

  name        = "${var.project_prefix}-swarm-default-policy"
  description = "Policy granting permissions for swarm."
  policy      = data.aws_iam_policy_document.swarm_default_policy[0].json
}

resource "aws_iam_policy" "swarm_efs_policy" {
  count       = var.enable_elastic_filesystem ? 1 : 0
  name        = "${var.project_prefix}-swarm-efs-policy"
  description = "Policy granting permissions for swarm to access EFS."
  policy      = data.aws_iam_policy_document.swarm_efs_policy[0].json
}

# - Roles -
# swarm
resource "aws_iam_role" "swarm_default_role" {
  count = var.create_swarm_default_role ? 1 : 0

  name               = "${var.project_prefix}-swarm-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  managed_policy_arns = concat([
    aws_iam_policy.swarm_default_policy[0].arn
    ], var.enable_elastic_filesystem ? [
    aws_iam_policy.swarm_efs_policy[0].arn
  ] : [])
  tags = local.tags
}

resource "aws_iam_role" "swarm_task_execution_role" {
  name = "${var.project_prefix}-swarm-task-execution-role"

  assume_role_policy  = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}
