################################################################################
# S3
################################################################################

resource "aws_s3_bucket" "unreal_ddc_s3_bucket" {
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:This bucket doesnt have any triggers needed as its only an object store
  #checkov:skip=CKV_AWS_144:This bucket hosts ephemeral recreatable assets
  bucket_prefix = "${var.name}-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unreal-s3-bucket" {
  #checkov:skip=CKV2_AWS_67:Ensure AWS S3 bucket encrypted with Customer Managed Key (CMK) has regular rotation
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = "aws/s3"
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "unreal_ddc_s3_acls" {
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_logging" "unreal-s3-log" {
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  target_bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id
  target_prefix = "log/unreal-ddc-bucket/"
}

resource "aws_s3_bucket_logging" "unreal-log-s3-log" {
  bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id

  target_bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id
  target_prefix = "log/unreal-ddc-logging-bucket/"
}

resource "aws_s3_bucket_public_access_block" "unreal_ddc_log_s3_acls" {
  bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Log Bucket
################################################################################
resource "aws_s3_bucket" "unreal_ddc_logging_s3_bucket" {
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:Ensure S3 buckets should have event notifications enabled
  #checkov:skip=CKV_AWS_144:Ensure that S3 bucket has cross-region replication enabled
  bucket_prefix = "${var.name}-logging-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unreal-s3-logging-bucket" {
  #checkov:skip=CKV2_AWS_67:Ensure AWS S3 bucket encrypted with Customer Managed Key (CMK) has regular rotation
  bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = "aws/s3"
      sse_algorithm     = "aws:kms"
    }
  }
}
