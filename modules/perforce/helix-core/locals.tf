locals {
  name_prefix = "${var.project_prefix}-${var.name}"
  tags = merge(
    {
      "environment" = var.environment
    },
    var.tags,
  )
}
