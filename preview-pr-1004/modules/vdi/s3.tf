resource "aws_s3_bucket" "keys" {
  #checkov:skip=CKV_AWS_18:Access logging not required for internal VDI keys bucket
  #checkov:skip=CKV2_AWS_61:Lifecycle policy not needed - emergency keys should be retained
  #checkov:skip=CKV2_AWS_62:Event notifications not required for VDI keys bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication not required for VDI keys
  #checkov:skip=CKV_AWS_145:KMS encryption not required for VDI keys - AES256 sufficient
  bucket = local.s3_bucket_names.keys
  tags = merge(var.tags, {
    Name    = local.s3_bucket_names.keys
    Purpose = "VDI Keys"
  })
}

resource "aws_s3_bucket" "scripts" {
  #checkov:skip=CKV_AWS_18:Access logging not required for internal VDI scripts bucket
  #checkov:skip=CKV2_AWS_61:Lifecycle policy not needed - scripts should be retained
  #checkov:skip=CKV2_AWS_62:Event notifications not required for VDI scripts bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication not required for VDI scripts
  #checkov:skip=CKV_AWS_145:KMS encryption not required for VDI scripts - AES256 sufficient
  bucket = local.s3_bucket_names.scripts
  tags = merge(var.tags, {
    Name    = local.s3_bucket_names.scripts
    Purpose = "VDI Scripts"
  })
}

resource "aws_s3_bucket_versioning" "keys" {
  bucket = aws_s3_bucket.keys.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "keys" {
  bucket = aws_s3_bucket.keys.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "keys" {
  bucket = aws_s3_bucket.keys.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
