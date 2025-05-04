resource "aws_iam_role" "codebuild_role" {
  name = "${local.name_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        Effect = "Allow"
        Resource = [
          aws_ecr_repository.ecr_repository.arn,
          "${aws_ecr_repository.ecr_repository.arn}/*"
        ]
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      },
      {
        Effect = "Allow"
        Resource = [
          "*"
        ]
        Action = [
          "ecr:GetAuthorizationToken"
        ]
      }
      ],
      var.source_image.auth.secret_arn != null ? [{
        Effect = "Allow"
        Resource = [
          var.source_image.auth.secret_arn
        ]
        Action = [
          "secretsmanager:GetSecretValue"
        ]
    }] : [])
  })
}


# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

# Lambda IAM Policy
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      }
    ]
  })
}
