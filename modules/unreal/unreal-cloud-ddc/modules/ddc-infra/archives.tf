################################################################################
# Archive and Upload Assets
################################################################################

data "archive_file" "assets" {
  type        = "zip"
  output_path = "${path.module}/.terraform/tmp/assets.zip"
  
  source {
    content  = ""
    filename = "manifests/"
  }
  
  dynamic "source" {
    for_each = fileset("${path.module}/manifests", "**/*")
    content {
      content  = file("${path.module}/manifests/${source.value}")
      filename = "manifests/${source.value}"
    }
  }
  
  dynamic "source" {
    for_each = fileset("${path.module}/scripts", "**/*")
    content {
      content  = file("${path.module}/scripts/${source.value}")
      filename = "scripts/${source.value}"
    }
  }
}

resource "aws_s3_object" "assets" {
  region = var.region
  bucket = aws_s3_bucket.manifests.id
  key    = "assets.zip"
  source = data.archive_file.assets.output_path
  etag   = data.archive_file.assets.output_md5
}