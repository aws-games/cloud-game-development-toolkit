################################################################################
# S3
################################################################################
resource "aws_s3_bucket" "unreal_ddc_s3_bucket" {
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:This bucket doesnt have any triggers needed as its only an object store
  #checkov:skip=CKV_AWS_144:This bucket hosts ephemeral recreatable assets
  #checkov:skip=CKV_AWS_18:Logging bucket cna be configured by customer
  #checkov:skip=CKV_AWS_145:Causes issue with helm chart interacting with objects
  bucket_prefix = "${var.name}-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "unreal_ddc_s3_acls" {
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
