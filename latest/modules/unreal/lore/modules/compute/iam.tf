data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# =============================================================================
# Task Role — application permissions (S3 + DynamoDB + ADOT)
# =============================================================================

resource "aws_iam_role" "task" {
  name_prefix        = "${var.name_prefix}-task-"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:HeadObject",
      "s3:HeadBucket",
      "s3:ListObjectVersions",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = [
      var.fragment_bucket_arn,
      "${var.fragment_bucket_arn}/*",
    ]
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable",
      "dynamodb:TransactWriteItems",
    ]
    resources = var.dynamodb_table_arns
  }

  statement {
    actions   = ["dynamodb:Query"]
    resources = ["${var.locks_table_arn}/index/*"]
  }
}

resource "aws_iam_role_policy" "task" {
  name_prefix = "${var.name_prefix}-task-"
  role        = aws_iam_role.task.id
  policy      = data.aws_iam_policy_document.task_permissions.json
}

# ADOT permissions (on task role — all containers share it)
data "aws_iam_policy_document" "otel_permissions" {
  count = var.enable_otel_sidecar ? 1 : 0

  # X-Ray trace submission + sampling config retrieval.
  # These actions do NOT support resource-level ARNs (IAM reference: Resource types column
  # is empty). No useful condition keys exist for the ECS sidecar pattern.
  # See: https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsx-ray.html
  statement {
    sid = "XRayTraceSubmission"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs — scoped to the specific log group created by this module.
  # CreateLogGroup omitted: Terraform creates the log group; ADOT doesn't need to.
  # PutMetricData omitted: ecs-xray.yaml has no metrics exporter (only awsxray).
  # If switching to ecs-cloudwatch-xray.yaml, add PutMetricData with cloudwatch:namespace condition.
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = [
      aws_cloudwatch_log_group.loreserver.arn,
      "${aws_cloudwatch_log_group.loreserver.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "otel" {
  count       = var.enable_otel_sidecar ? 1 : 0
  name_prefix = "${var.name_prefix}-otel-"
  role        = aws_iam_role.task.id
  policy      = data.aws_iam_policy_document.otel_permissions[0].json
}

# =============================================================================
# Execution Role — ECS infrastructure permissions (ECR pull + logs + secrets)
# =============================================================================

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.name_prefix}-exec-"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachments_exclusive" "execution" {
  role_name = aws_iam_role.execution.name
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = compact([
      local.tls_cert_secret_arn,
      local.tls_key_secret_arn,
      local.hmac_key_secret_arn,
      local.tls_ca_secret_arn,
    ])
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name_prefix = "${var.name_prefix}-exec-secrets-"
  role        = aws_iam_role.execution.id
  policy      = data.aws_iam_policy_document.execution_secrets.json
}
