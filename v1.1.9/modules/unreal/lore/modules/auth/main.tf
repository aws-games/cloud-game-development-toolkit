data "aws_region" "current" {}

# =============================================================================
# Cognito User Pool — M2M auth for Lore
# =============================================================================

resource "aws_cognito_user_pool" "lore" {
  name           = "${var.name_prefix}-auth"
  user_pool_tier = "ESSENTIALS"

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.pre_token.arn
      lambda_version = "V3_0"
    }
  }

  tags = var.tags
}

resource "aws_cognito_resource_server" "lore" {
  user_pool_id = aws_cognito_user_pool.lore.id
  identifier   = "lore"
  name         = "Lore API"

  scope {
    scope_name        = "full_access"
    scope_description = "Full access to Lore API"
  }
}

resource "aws_cognito_user_pool_domain" "lore" {
  domain       = "${var.name_prefix}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.lore.id
}

resource "aws_cognito_user_pool_client" "lore" {
  name         = "${var.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.lore.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["lore/full_access"]
  supported_identity_providers         = ["COGNITO"]

  depends_on = [aws_cognito_resource_server.lore]
}

# =============================================================================
# Pre-Token-Generation Lambda — injects custom claims for Lore compat
# =============================================================================

data "archive_file" "pre_token" {
  type        = "zip"
  source_file = "${path.module}/lambda/pre_token_generation.mjs"
  output_path = "${path.module}/lambda/.build/pre_token_generation.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pre_token_lambda" {
  name_prefix        = "${var.name_prefix}-pre-token-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "pre_token_lambda_logs" {
  role       = aws_iam_role.pre_token_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "pre_token" {
  #checkov:skip=CKV_AWS_116: DLQ not applicable — synchronous Cognito pre-token trigger, errors surface to caller
  #checkov:skip=CKV_AWS_272: Code-signing not required — source is inline Terraform archive, not externally published
  #checkov:skip=CKV_AWS_173: No sensitive env vars — only ENVIRONMENT name string
  #checkov:skip=CKV_AWS_115: Concurrency limit not needed — invoked only by Cognito token flow, scales with auth requests
  #checkov:skip=CKV_AWS_117: VPC not required — no VPC resources accessed, only transforms JWT claims
  #checkov:skip=CKV_AWS_50: X-Ray not needed — trivial claim-mapping function, tracing adds no diagnostic value
  function_name    = "${var.name_prefix}-pre-token-gen"
  handler          = "pre_token_generation.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.pre_token_lambda.arn
  filename         = data.archive_file.pre_token.output_path
  source_code_hash = data.archive_file.pre_token.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.tags
}

resource "aws_lambda_permission" "cognito_invoke" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.lore.arn
}
