# S3 buckets for VDI module (always created)

# Keys bucket
resource "aws_s3_bucket" "keys" {
  bucket = local.s3_bucket_names.keys
  tags = merge(var.tags, {
    Name    = local.s3_bucket_names.keys
    Purpose = "VDI Keys"
  })
}

# Scripts bucket  
resource "aws_s3_bucket" "scripts" {
  bucket = local.s3_bucket_names.scripts
  tags = merge(var.tags, {
    Name    = local.s3_bucket_names.scripts
    Purpose = "VDI Scripts"
  })
}

# Bucket versioning
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

# Bucket encryption
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

# Block public access
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