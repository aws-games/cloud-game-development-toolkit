locals {
  name_prefix    = "${var.project_prefix}-${var.name}"
  swarm_port     = 80
  helix_swarm_az = data.aws_subnet.instance_subnet.availability_zone

  tags = merge(var.tags, {
    "ENVIRONMENT" = var.environment
  })
}
