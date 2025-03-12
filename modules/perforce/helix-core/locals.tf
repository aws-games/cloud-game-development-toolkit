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
  server_cidrs = {for k, v in local.server_private_ips : k => "${v}/32"}

##########################################
# Perforce Helix Core Instance Topology Structure
##########################################

  topology = {
    version = formatdate("YYYYMMDDhhmmss", timestamp())
    servers = {
      for server_type, instance in aws_instance.helix_core_instance :
      server_type => {
        role = server_type
        private_dns = instance.private_dns
        private_ip = instance.private_ip
        public_ip = var.internal ? null : try(aws_eip.helix_core_eip[server_type].public_ip, null)
        instance_id = instance.id
        subnet_id = instance.subnet_id
        vpc_id = var.server_configuration[index(var.server_configuration.*.type, server_type)].vpc_id
        region = instance.availability_zone != null ? regex("^([a-z]+-[a-z]+-[0-9]+)[a-z]$", instance.availability_zone)[0] : data.aws_region.current.name
        volumes = {
          depot = {
            device = aws_volume_attachment.depot_attachment[server_type].device_name
            id = aws_ebs_volume.depot[server_type].id
          }
          metadata = {
            device = aws_volume_attachment.metadata_attachment[server_type].device_name
            id = aws_ebs_volume.metadata[server_type].id
          }
          logs = {
            device = aws_volume_attachment.logs_attachment[server_type].device_name
            id = aws_ebs_volume.logs[server_type].id
          }
        }
      }
    }
    connections = [
      for server_type, instance in aws_instance.helix_core_instance :
      {
        from = instance.private_dns
        to = aws_instance.helix_core_instance["commit"].private_dns
      }
      if server_type != "commit"
    ]
  }


  
  # Calculate relative path from the module to the playbook
  playbook_path = "${path.module}/../../../assets/ansible-playbooks/perforce/helix-core/${var.playbook_file_name}"
  # Generate bucket name with random suffix
  bucket_name   = "ansible-playbook-bucket-${random_string.bucket_suffix.result}"

  helix_core_super_user_username_secret_arn = var.helix_core_super_user_username_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_username[0].secret_id : var.helix_core_super_user_username_secret_arn
  
  helix_core_super_user_password_secret_arn = var.helix_core_super_user_password_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_password[0].secret_id : var.helix_core_super_user_password_secret_arn

  
}
