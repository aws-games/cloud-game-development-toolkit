locals {
  name_prefix = "${var.project_prefix}-${var.name}"
  tags = merge(var.tags, {
    "environment" = var.environment
  })
  image_builder_base_component_version = "1.0.0"
}
