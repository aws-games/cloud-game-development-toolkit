resource "aws_instance" "unity_license_server_eni" {
  #checkov:skip=CKV_AWS_126:Dont need detailed monitoring but its an option
  #checkov:skip=CKV_AWS_8:Encryption is set on the block device
  count = var.create_eip ? 0 : 1

  ami                  = data.aws_ami.unity_license_server.image_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.unity_server_instance_profile.id

  ebs_optimized = true

  monitoring = var.enable_instance_detailed_monitoring

  tags = merge(local.tags,
    {
      Name = "cgd-unity-floating-license-server"
  })

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = var.instance_ebs_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.unity_license_server_eni.id
  }
}

resource "aws_instance" "unity_license_server_eip" {
  #checkov:skip=CKV_AWS_126:Dont need detailed monitoring but its an option
  count = var.create_eip ? 1 : 0

  ami                  = data.aws_ami.unity_license_server.image_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.unity_server_instance_profile.id

  tags = merge(local.tags,
    {
      Name = "cgd-unity-floating-license-server"
  })

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = var.instance_ebs_size
    volume_type = "gp3"
    encrypted   = true
  }

  monitoring = var.enable_instance_detailed_monitoring

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.unity_license_server_eni.id
  }
}

resource "aws_eip" "unity_license_eip" {
  count  = var.create_eip ? 1 : 0
  domain = "vpc"
  tags = merge(local.tags,
    {
      Name = "cgd-unity-floating-license-eip"
  })
}

resource "aws_eip_association" "unity_license_eip_assoc" {
  count         = var.create_eip ? 1 : 0
  instance_id   = aws_instance.unity_license_server_eip[0].id
  allocation_id = aws_eip.unity_license_eip[0].id
}

resource "aws_network_interface" "unity_license_server_eni" {
  private_ips     = var.eni_private_ips_list
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.unity_license_server_sg.id]

  tags = merge(local.tags,
    {
      Name = "cgd-unity-floating-license-server-eni"
  })
}
