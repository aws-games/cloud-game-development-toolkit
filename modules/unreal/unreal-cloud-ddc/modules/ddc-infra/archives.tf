################################################################################
# Archive and Upload BuildSpecs
################################################################################

data "archive_file" "manifests" {
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

resource "aws_s3_object" "manifests" {
  bucket = aws_s3_bucket.manifests.id
  key    = "assets.zip"
  source = data.archive_file.manifests.output_path
  etag   = data.archive_file.manifests.output_md5
}