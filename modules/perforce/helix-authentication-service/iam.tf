# - Random Strings to prevent naming conflicts -
resource "random_string" "HAS" {
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
# HAS
data "aws_iam_policy_document" "HAS_default_policy" {
  count = var.create_HAS_default_policy ? 1 : 0
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

resource "aws_iam_policy" "HAS_default_policy" {
  count = var.create_HAS_default_policy ? 1 : 0

  name        = "${var.project_prefix}-HAS-default-policy"
  description = "Policy granting permissions for HAS."
  policy      = data.aws_iam_policy_document.HAS_default_policy[0].json
}

# - Roles -
# HAS
resource "aws_iam_role" "HAS_default_role" {
  count = var.create_HAS_default_role ? 1 : 0

  name               = "${var.project_prefix}-HAS-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  managed_policy_arns = [
    aws_iam_policy.HAS_default_policy[0].arn
  ]
  tags = local.tags
}

resource "aws_iam_role" "HAS_task_execution_role" {
  name = "${var.project_prefix}-HAS-task-execution-role"

  assume_role_policy  = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}
