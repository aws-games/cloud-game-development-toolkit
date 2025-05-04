locals {
  name_prefix = "${var.project_prefix}-${var.name}"

  tags = merge(var.tags, {
    "environment" = var.environment
  })

  source_image = {
    provider = "dockerhub"
    image    = var.container_image
    tag      = "latest"
    auth = {
      secret_arn = var.dockerhub_secret_arn
    }
  }
}
