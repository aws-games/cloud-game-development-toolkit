##########################################
# S3 | Broker Config Bucket
##########################################
resource "random_string" "broker_config" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "broker_config" {
  bucket        = "${local.name_prefix}-config-${random_string.broker_config.result}"
  force_destroy = true

  #checkov:skip=CKV_AWS_21: Versioning not required for broker config
  #checkov:skip=CKV_AWS_144: Cross-region replication not required
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  #checkov:skip=CKV2_AWS_61: Lifecycle configuration not necessary for config bucket
  #checkov:skip=CKV2_AWS_6: S3 Buckets have public access blocked by default

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-config-${random_string.broker_config.result}"
  })
}

resource "aws_s3_bucket_public_access_block" "broker_config" {
  bucket = aws_s3_bucket.broker_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "broker_config" {
  bucket = aws_s3_bucket.broker_config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "broker_config" {
  bucket = aws_s3_bucket.broker_config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

##########################################
# S3 | Broker Config Object
##########################################
resource "aws_s3_object" "broker_config" {
  bucket = aws_s3_bucket.broker_config.id
  key    = "p4broker.conf"
  content = templatefile("${path.module}/templates/p4broker.conf.tftpl", {
    p4_target     = var.p4_target
    listen_port   = var.container_port
    command_rules = var.broker_command_rules
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-broker-config"
  })
}
