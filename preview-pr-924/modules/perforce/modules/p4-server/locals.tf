locals {
  name_prefix  = "${var.project_prefix}-${var.name}"
  p4_server_az = data.aws_subnet.instance_subnet.availability_zone
  tags = merge(
    {
      "environment" = var.environment
    },
    var.tags,
  )
}
