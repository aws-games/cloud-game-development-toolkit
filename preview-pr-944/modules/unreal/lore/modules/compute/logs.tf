resource "aws_cloudwatch_log_group" "loreserver" {
  name              = "/ecs/${var.name_prefix}-loreserver"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
