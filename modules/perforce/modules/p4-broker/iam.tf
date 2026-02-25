##########################################
# Random Strings
##########################################
resource "random_string" "p4_broker" {
  length  = 2
  special = false
  upper   = false
}

##########################################
# Trust Relationships
##########################################
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
# Default Policy Document (Task Role)
data "aws_iam_policy_document" "default_policy" {
  count = var.create_default_role ? 1 : 0

  # ECS Exec support
  statement {
    sid    = "ECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:CreateControlChannel"
    ]
    resources = ["*"]
  }

  # S3 read access for broker config
  statement {
    sid    = "S3ConfigRead"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.broker_config.arn}/*"
    ]
  }
}

# S3 Config Policy Document (Task Execution Role - for init container)
data "aws_iam_policy_document" "s3_config_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.broker_config.arn}/*"
    ]
  }
}

# Default Policy
resource "aws_iam_policy" "default_policy" {
  count = var.create_default_role ? 1 : 0

  name        = "${local.name_prefix}-default-policy"
  description = "Policy granting permissions for ${local.name_prefix}."
  policy      = data.aws_iam_policy_document.default_policy[0].json

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-default-policy"
  })
}

# S3 Config Policy
resource "aws_iam_policy" "s3_config_policy" {
  name        = "${local.name_prefix}-s3-config-policy"
  description = "Policy granting permissions for ${local.name_prefix} task execution role to read config from S3."
  policy      = data.aws_iam_policy_document.s3_config_policy.json

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-s3-config-policy"
  })
}


##########################################
# Roles
##########################################
# Default Role (Task Role)
resource "aws_iam_role" "default_role" {
  count              = var.create_default_role ? 1 : 0
  name               = "${local.name_prefix}-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-default-role"
  })
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

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-task-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_role_ecs" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_execution_role_s3_config" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.s3_config_policy.arn
}
