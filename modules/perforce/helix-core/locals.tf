locals {
  name_prefix   = "${var.project_prefix}-${var.name}"
  #helix_core_az = data.aws_subnet.instance_subnet.availability_zone
  tags = merge(
    {
      "environment" = var.environment
    },
    var.tags,
  )

  p4_server_type_tags = {
    commit = {
      ServerType = "Commit"
      Role       = "Primary"
    }
    replica = {
      ServerType = "Replica"
      Role       = "Backup"
    }
    edge = {
      ServerType = "Edge"
      Role       = "Access"
    }
  }

  server_private_ips = {for k, v in aws_instance.helix_core_instance : k => v.private_ip}
  
}
