##########################################
# CloudWatch | Application Logging
##########################################
resource "aws_cloudwatch_log_group" "application_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-application-log-group"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-application-log-group"
    }
  )
}

resource "aws_cloudwatch_log_group" "redis_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-redis-log-group"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-redis-log-group"
    }
  )
}
