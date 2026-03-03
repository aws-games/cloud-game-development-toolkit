resource "aws_fsx_openzfs_file_system" "jenkins_build_farm_fsxz_file_system" {
  for_each = var.build_farm_fsx_openzfs_storage

  deployment_type     = each.value.deployment_type
  preferred_subnet_id = var.build_farm_subnets[0]

  subnet_ids      = var.build_farm_subnets
  route_table_ids = each.value.route_table_ids

  storage_capacity    = each.value.storage_capacity
  throughput_capacity = each.value.throughput_capacity

  security_group_ids = [aws_security_group.jenkins_build_storage_sg.id]

  root_volume_configuration {
    data_compression_type  = "LZ4"
    read_only              = false
    record_size_kib        = 128
    copy_tags_to_snapshots = true
    nfs_exports {
      client_configurations {
        clients = data.aws_vpc.build_farm_vpc.cidr_block
        options = ["async", "rw", "crossmnt"]
      }
    }
  }

  skip_final_backup                 = true
  automatic_backup_retention_days   = 7
  copy_tags_to_backups              = true
  copy_tags_to_volumes              = true
  daily_automatic_backup_start_time = "06:00"
  #checkov:skip=CKV_AWS_203: CMK encryption not supported currently
  tags = merge(local.tags, each.value.tags, {
    Name = "${var.project_prefix}-${each.key}"
  })
}

resource "aws_fsx_openzfs_volume" "jenkins_build_farm_fsxz_volume" {
  for_each = aws_fsx_openzfs_file_system.jenkins_build_farm_fsxz_file_system

  name             = "${var.project_prefix}-${each.key}"
  parent_volume_id = aws_fsx_openzfs_file_system.jenkins_build_farm_fsxz_file_system[each.key].root_volume_id

  copy_tags_to_snapshots = true

  data_compression_type = "LZ4"

  nfs_exports {
    client_configurations {
      clients = data.aws_vpc.build_farm_vpc.cidr_block
      options = ["async", "rw", "crossmnt"]
    }
  }

  tags = merge(local.tags, each.value.tags, {
    Name = "${var.project_prefix}-${each.key}"
  })
}
