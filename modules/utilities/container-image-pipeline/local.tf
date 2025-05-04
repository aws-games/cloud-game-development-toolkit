locals {
  name_prefix = "${var.project_prefix}-${var.name}"

  # Create hash of Dockerfile for triggering rebuilds
  dockerfile_hash = sha256(jsonencode({
    template_path    = var.dockerfile_template.template_path
    template_content = file(var.dockerfile_template.template_path)
    variables        = var.dockerfile_template.variables
  }))

  dockerfile_content = templatefile(
    var.dockerfile_template.template_path,
    var.dockerfile_template.variables
  )

  dockerfile_base64 = base64encode(local.dockerfile_content)

  tags = merge(var.tags, {
    "environment" = var.environment
  })
}
