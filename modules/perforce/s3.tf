#################################################
# S3 Bucket for P4 Replica Configuration Scripts
#################################################
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket" "p4_server_config_scripts" {
  count  = var.p4_server_config != null ? 1 : 0
  bucket = "${var.project_prefix}-p4-server-scripts-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-p4-server-scripts"
  })
}

resource "aws_s3_bucket_versioning" "p4_server_config_scripts" {
  count  = var.p4_server_config != null ? 1 : 0
  bucket = aws_s3_bucket.p4_server_config_scripts[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "p4_server_config_scripts" {
  count  = var.p4_server_config != null ? 1 : 0
  bucket = aws_s3_bucket.p4_server_config_scripts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "p4_server_config_scripts" {
  count  = var.p4_server_config != null ? 1 : 0
  bucket = aws_s3_bucket.p4_server_config_scripts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#################################################
# Upload Configuration Scripts to S3
#################################################
resource "aws_s3_object" "configure_primary_script" {
  count  = length(var.p4_server_replicas_config) > 0 ? 1 : 0
  bucket = aws_s3_bucket.p4_server_config_scripts[0].id
  key    = "configure_primary_for_replicas.sh"
  source = "${path.module}/scripts/configure_primary_for_replicas.sh"
  etag   = filemd5("${path.module}/scripts/configure_primary_for_replicas.sh")

  tags = var.tags
}

resource "aws_s3_object" "configure_replica_script" {
  count  = length(var.p4_server_replicas_config) > 0 ? 1 : 0
  bucket = aws_s3_bucket.p4_server_config_scripts[0].id
  key    = "configure_replica.sh"
  source = "${path.module}/scripts/configure_replica.sh"
  etag   = filemd5("${path.module}/scripts/configure_replica.sh")

  tags = var.tags
}

# TODO: Remove test script after SSM functionality is verified
resource "aws_s3_object" "test_ssm_script" {
  count  = length(var.p4_server_replicas_config) > 0 ? 1 : 0
  bucket = aws_s3_bucket.p4_server_config_scripts[0].id
  key    = "test_ssm_execution.sh"
  source = "${path.module}/scripts/test_ssm_execution.sh"
  etag   = filemd5("${path.module}/scripts/test_ssm_execution.sh")

  tags = var.tags
}