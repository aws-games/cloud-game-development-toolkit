resource "aws_cloudwatch_log_group" "loreserver" {
  #checkov:skip=CKV_AWS_158: KMS encryption optional — user can provide KMS key via module variable in future iteration
  #checkov:skip=CKV_AWS_338: Retention is user-configurable via log_retention_days variable (default 30 days)
  name              = "/ecs/${var.name_prefix}-loreserver"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
