# =============================================================================
# X-Ray Pipeline Smoke Test Lambda — verifies trace delivery + IAM (when enabled)
# =============================================================================

data "archive_file" "xray_smoke_test" {
  count       = var.enable_xray_smoke_test ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/lambda/xray_smoke_test.mjs"
  output_path = "${path.module}/lambda/.build/xray_smoke_test.zip"
}

resource "aws_lambda_function" "xray_smoke_test" {
  #checkov:skip=CKV_AWS_116: DLQ not applicable — diagnostic utility Lambda invoked manually, not event-driven
  #checkov:skip=CKV_AWS_272: Code-signing not required — source is inline Terraform archive
  #checkov:skip=CKV_AWS_173: No sensitive env vars — only ENVIRONMENT name string
  #checkov:skip=CKV_AWS_115: Concurrency limit not needed — manual invocation only, not production traffic
  #checkov:skip=CKV_AWS_117: VPC not required — only calls X-Ray API, no VPC resources accessed
  #checkov:skip=CKV_AWS_50: X-Ray tracing on the X-Ray test Lambda is circular — function tests X-Ray, not itself traced
  count            = var.enable_xray_smoke_test ? 1 : 0
  function_name    = "${var.name_prefix}-xray-smoke-test"
  handler          = "xray_smoke_test.handler"
  runtime          = "nodejs20.x"
  timeout          = 15
  role             = aws_iam_role.xray_smoke_test[0].arn
  filename         = data.archive_file.xray_smoke_test[0].output_path
  source_code_hash = data.archive_file.xray_smoke_test[0].output_base64sha256

  environment {
    variables = { ENVIRONMENT = var.environment }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "xray_smoke_test_assume" {
  count = var.enable_xray_smoke_test ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "xray_smoke_test" {
  count              = var.enable_xray_smoke_test ? 1 : 0
  name_prefix        = "${var.name_prefix}-xray-test-"
  assume_role_policy = data.aws_iam_policy_document.xray_smoke_test_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "xray_smoke_test_logs" {
  count      = var.enable_xray_smoke_test ? 1 : 0
  role       = aws_iam_role.xray_smoke_test[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# X-Ray actions do NOT support resource-level ARNs. This is an AWS API limitation.
# See: https://docs.aws.amazon.com/service-authorization/latest/reference/list_awsx-ray.html
data "aws_iam_policy_document" "xray_smoke_test_xray" {
  count = var.enable_xray_smoke_test ? 1 : 0
  statement {
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetTraceSummaries"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "xray_smoke_test_xray" {
  count  = var.enable_xray_smoke_test ? 1 : 0
  name   = "xray-access"
  role   = aws_iam_role.xray_smoke_test[0].id
  policy = data.aws_iam_policy_document.xray_smoke_test_xray[0].json
}
