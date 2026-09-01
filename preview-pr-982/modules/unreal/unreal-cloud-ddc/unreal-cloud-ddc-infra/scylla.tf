################################################################################
# Scylla Instance Profile
################################################################################

resource "aws_iam_instance_profile" "scylla_instance_profile" {
  name = "${local.name_prefix}-scylladb-instance-profile"
  role = aws_iam_role.scylla_role.name
}
################################################################################
# Scylla Instances
################################################################################
resource "aws_instance" "scylla_ec2_instance_seed" {
  count = length([var.scylla_subnets[0]])

  ami                    = data.aws_ami.scylla_ami.id
  instance_type          = var.scylla_instance_type
  vpc_security_group_ids = [aws_security_group.scylla_security_group.id]
  monitoring             = true

  subnet_id = element(var.scylla_subnets, count.index)

  user_data                   = local.scylla_user_data_primary_node
  user_data_replace_on_change = true
  ebs_optimized               = true

  iam_instance_profile = aws_iam_instance_profile.scylla_instance_profile.name

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    throughput  = var.scylla_db_throughput
    volume_size = var.scylla_db_storage
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-db"
    }
  )
}

resource "aws_instance" "scylla_ec2_instance_other_nodes" {
  count = length(var.scylla_subnets) - 1

  ami                    = data.aws_ami.scylla_ami.id
  instance_type          = var.scylla_instance_type
  vpc_security_group_ids = [aws_security_group.scylla_security_group.id]
  monitoring             = true

  subnet_id = element(var.scylla_subnets, count.index + 1)

  user_data                   = local.scylla_user_data_other_nodes
  user_data_replace_on_change = true
  ebs_optimized               = true

  iam_instance_profile = aws_iam_instance_profile.scylla_instance_profile.name

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    throughput  = var.scylla_db_throughput
    volume_size = var.scylla_db_storage
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-db"
    }
  )
}
