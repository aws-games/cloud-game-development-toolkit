data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "ecr_repository" {
  #checkov:skip=CKV_AWS_51: "Image tag mutability is required to able to apply `latest` tag or any other environment specific tags"
  name = local.name_prefix
  tags = local.tags

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.ecr_kms_key_id
  }
}

resource "aws_codebuild_project" "codebuild_project" {
  name          = "${local.name_prefix}-codebuild-project"
  description   = "Builds container images for ${local.name_prefix}"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "30"

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    #privileged_mode            = true
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "NO_SOURCE"
    buildspec = templatefile("${path.module}/buildspec.yml.tpl", {
      aws_account_id          = data.aws_caller_identity.current.account_id
      source_image            = var.base_image
      github_token_secret_arn = var.ghcr_credentials_secret_manager_arn
      target_repo             = aws_ecr_repository.ecr_repository.repository_url
      image_tags              = var.image_tags
      aws_region              = data.aws_region.current.name
    })
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  tags = local.tags
}
