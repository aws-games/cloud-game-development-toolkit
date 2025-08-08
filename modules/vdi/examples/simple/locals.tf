# Local variables for the VDI example
locals {
  name_prefix = "${var.project_prefix}-${var.name}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = "VDI-Example"
    Owner       = "DevOps-Team"
    Purpose     = "Development-Workstation"
  })
}
