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
    Statement = [
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
      },
      {
        Effect = "Allow"
        Resource = [
          var.ghcr_credentials_secret_manager_arn
        ]
        Action = [
          "secretsmanager:GetSecretValue"
        ]
      },
      {
        Effect   = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      }
    ]
  })
}
