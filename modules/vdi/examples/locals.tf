# Local variables for the VDI example
locals {
  name_prefix = "${var.project_prefix}-${var.name}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = "VDI-Example"
    Owner       = "DevOps-Team"
    Purpose     = "Development-Workstation"
  })
  
  # Validation: directory_name is always required in this example
  validate_directory_name = var.directory_name != null && var.directory_name != ""
}

# Validation resource
resource "null_resource" "validate_directory_name" {
  count = local.validate_directory_name ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: directory_name is required in this example. Please set directory_name in your terraform.tfvars file.' && exit 1"
  }
}