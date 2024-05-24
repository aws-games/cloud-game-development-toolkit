locals {
  name_prefix   = "${var.project_prefix}-${var.name}"
  helix_core_az = data.aws_subnet.instance_subnet.availability_zone
  tags = merge(
    {
      "ENVIRONMENT" = var.environment
    },
    var.tags,
  )
}
