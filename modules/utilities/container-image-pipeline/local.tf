locals {
  name_prefix = "${var.project_prefix}-${var.name}"
  tags = merge(var.tags, {
    "environment" = var.environment
  })
}
