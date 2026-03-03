################################################################################
# Archive and Upload Buildspecs
################################################################################

data "archive_file" "assets" {
  type        = "zip"
  output_path = "${path.module}/.terraform/tmp/assets.zip"
  
  source {
    content  = ""
    filename = "scripts/"
  }
  
  dynamic "source" {
    for_each = fileset("${path.module}/scripts", "**/*")
    content {
      content  = file("${path.module}/scripts/${source.value}")
      filename = "scripts/${source.value}"
    }
  }
  
  source {
    content  = ""
    filename = "assets/scripts/"
  }
  
  dynamic "source" {
    for_each = fileset("${path.module}/../../assets/scripts", "**/*")
    content {
      content  = file("${path.module}/../../assets/scripts/${source.value}")
      filename = "assets/scripts/${source.value}"
    }
  }
}

resource "aws_s3_object" "assets" {
  bucket = aws_s3_bucket.assets.id
  key    = "assets.zip"
  source = data.archive_file.assets.output_path
  etag   = data.archive_file.assets.output_md5
}