################################################################################
# Archive Deploy Assets (Deploy scripts + buildspecs only)
################################################################################

data "archive_file" "deploy_assets" {
  type        = "zip"
  output_path = "${path.module}/.terraform/tmp/deploy-assets.zip"

  source {
    content  = ""
    filename = "scripts/"
  }

  # Deploy scripts from deploy/ subdirectory
  dynamic "source" {
    for_each = fileset("${path.module}/scripts/deploy", "**/*")
    content {
      content  = file("${path.module}/scripts/deploy/${source.value}")
      filename = "scripts/deploy/${source.value}"
    }
  }

  # Deploy buildspec
  source {
    content  = file("${path.module}/buildspecs/deploy-ddc.yml")
    filename = "buildspecs/deploy-ddc.yml"
  }
}

################################################################################
# Archive Test Assets (Test scripts + buildspecs only)
################################################################################

data "archive_file" "test_assets" {
  type        = "zip"
  output_path = "${path.module}/.terraform/tmp/test-assets.zip"

  source {
    content  = ""
    filename = "scripts/"
  }

  # Test scripts from test/ subdirectory
  dynamic "source" {
    for_each = fileset("${path.module}/scripts/test", "**/*")
    content {
      content  = file("${path.module}/scripts/test/${source.value}")
      filename = "scripts/test/${source.value}"
    }
  }

  # Test buildspec
  source {
    content  = file("${path.module}/buildspecs/test-ddc.yml")
    filename = "buildspecs/test-ddc.yml"
  }
}

################################################################################
# S3 Objects for Separate Assets
################################################################################

resource "aws_s3_object" "deploy_assets" {
  region = var.region
  bucket = aws_s3_bucket.assets.id
  key    = "deploy/assets.zip"
  source = data.archive_file.deploy_assets.output_path
  etag   = data.archive_file.deploy_assets.output_md5
}

resource "aws_s3_object" "test_assets" {
  region = var.region
  bucket = aws_s3_bucket.assets.id
  key    = "test/assets.zip"
  source = data.archive_file.test_assets.output_path
  etag   = data.archive_file.test_assets.output_md5
}
