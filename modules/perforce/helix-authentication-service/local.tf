locals {
  helix_authentication_service_image = "perforce/helix-auth-svc"
  name_prefix                        = "${var.project_prefix}-${var.name}"

  tags = merge(var.tags, {
    "environment" = var.environment
  })
}
