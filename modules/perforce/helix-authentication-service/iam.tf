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
}


resource "aws_iam_policy" "helix_authentication_service_default_policy" {
  count       = var.create_helix_authentication_service_default_policy ? 1 : 0
  name        = "${var.project_prefix}-helix_authentication_service-default-policy"
  description = "Policy granting permissions for helix_authentication_service."
  policy      = data.aws_iam_policy_document.helix_authentication_service_default_policy[0].json
}



# - Roles -
# helix_authentication_service
resource "aws_iam_role" "helix_authentication_service_default_role" {
  count              = var.create_helix_authentication_service_default_role ? 1 : 0
  name               = "${var.project_prefix}-helix_authentication_service-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "helix_authentication_service_default_policy_attachment" {
  count      = var.create_helix_authentication_service_default_policy ? 1 : 0
  role       = aws_iam_role.helix_authentication_service_default_role[0].name
  policy_arn = aws_iam_policy.helix_authentication_service_default_policy[0].arn
}

data "aws_iam_policy_document" "helix_authentication_service_config_s3_read_write" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.helix_authentication_service_config_bucket.arn
    ]

  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:HeadObject",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.helix_authentication_service_config_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "helix_authentication_service_config_s3_read_write_policy" {
  name        = "${var.project_prefix}-helix_authentication_service_config_s3_read_write_policy"
  description = "Policy enabling read and write access to S3 bucket"
  policy      = data.aws_iam_policy_document.helix_authentication_service_config_s3_read_write.json
}

resource "aws_iam_role" "helix_authentication_service_task_execution_role" {
  name               = "${var.project_prefix}-helix_authentication_service-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json
}

resource "aws_iam_role_policy_attachment" "helix_authentication_service_task_execution_role_policy_attachment" {
  role       = aws_iam_role.helix_authentication_service_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "helix_authentication_service_config_s3_read_write_policy_attachment" {
  count      = var.create_helix_authentication_service_default_policy ? 1 : 0
  role       = aws_iam_role.helix_authentication_service_default_role[0].name
  policy_arn = aws_iam_policy.helix_authentication_service_config_s3_read_write_policy.arn
}
