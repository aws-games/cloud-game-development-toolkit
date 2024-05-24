################################################################################
# Instance
################################################################################
resource "aws_instance" "helix_core_instance" {
  ami           = data.aws_ami.helix_core_ami.id
  instance_type = var.instance_type

  availability_zone = local.helix_core_az
  subnet_id         = var.instance_subnet_id

  iam_instance_profile = aws_iam_instance_profile.helix_core_instance_profile.id

  user_data = <<-EOT
    #!/bin/bash
    sleep 30
    /home/rocky/p4_configure.sh /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 ${var.server_type}
  EOT

  vpc_security_group_ids = var.existing_security_groups

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring    = true
  ebs_optimized = true

  root_block_device {
    encrypted = true
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-${var.server_type}-${local.helix_core_az}"
  })
}

################################################################################
# Elastic IP Address for Public Facing Instance
################################################################################
resource "aws_eip" "helix_core_eip" {
  count    = var.internal ? 0 : 1
  instance = aws_instance.helix_core_instance.id
  domain   = "vpc"
}

################################################################################
# EBS Storage
################################################################################
resource "aws_ebs_volume" "logs" {
  availability_zone = local.helix_core_az
  size              = var.logs_volume_size
  encrypted         = true

  tags = local.tags
}

resource "aws_volume_attachment" "logs_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.logs.id
  instance_id = aws_instance.helix_core_instance.id
}


// hxmetadata
resource "aws_ebs_volume" "metadata" {
  availability_zone = local.helix_core_az
  size              = var.metadata_volume_size
  encrypted         = true

  tags = local.tags
}

resource "aws_volume_attachment" "metadata_attachment" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.metadata.id
  instance_id = aws_instance.helix_core_instance.id
}


// hxdepot
resource "aws_ebs_volume" "depot" {
  availability_zone = local.helix_core_az
  size              = var.depot_volume_size
  encrypted         = true

  tags = local.tags
}

resource "aws_volume_attachment" "depot_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.depot.id
  instance_id = aws_instance.helix_core_instance.id
}

