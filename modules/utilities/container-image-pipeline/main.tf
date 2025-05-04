resource "aws_ecr_repository" "ecr_repository" {
  #checkov:skip=CKV_AWS_51: "Image tag mutability is required to able to apply `latest` tag or any other environment specific tags"
  name         = local.name_prefix
  tags         = local.tags
  force_delete = true

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
  build_timeout = var.codebuild_build_timeout

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = var.codebuild_type
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "NO_SOURCE"
    buildspec = templatefile("${path.module}/buildspec.yml.tpl", {
      aws_account_id    = data.aws_caller_identity.current.account_id
      source_image      = var.source_image
      target_repo       = aws_ecr_repository.ecr_repository.repository_url
      image_tags        = var.image_tags
      aws_region        = data.aws_region.current.name
      dockerfile_base64 = local.dockerfile_base64
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

resource "null_resource" "build_custom_image" {
  depends_on = [aws_codebuild_project.codebuild_project, aws_ecr_repository.ecr_repository]
  triggers = {
    dockerfile_hash = local.dockerfile_hash
  }
  provisioner "local-exec" {
    command = <<EOF
      set -e # Exit if non-zero status

      if ! BUILD_ID=$(aws codebuild start-build --project-name ${aws_codebuild_project.codebuild_project.name} --region ${data.aws_region.current.name} --query 'build.id' --output text); then
        echo "Failed to start CodeBuild project"
        exit 1
      fi

      echo "Started build with ID: $BUILD_ID"

      while true; do
        if ! STATUS=$(aws codebuild batch-get-builds --ids $BUILD_ID --query 'builds[0].buildStatus' --output text); then
          echo "Failed to get build status"
          exit 1
        fi

        echo "Current build status: $STATUS"

        case "$STATUS" in
          "SUCCEEDED")
            echo "Build completed successfully"
            exit 0
            ;;
          "FAILED"|"FAULT"|"STOPPED"|"TIMED_OUT")
            echo "Build failed with status: $STATUS"
            exit 1
            ;;
          *)
            echo "Build in progress..."
            sleep 10
            ;;
        esac
      done
    EOF
  }
}
