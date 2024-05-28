locals {
  swarm_image             = "perforce/helix-swarm"
  name_prefix             = "${var.project_prefix}-${var.name}"
  helix_swarm_config_path = "/opt/perforce/swarm/data"

  tags = merge(var.tags, {
    "ENVIRONMENT" = var.environment
  })
}
