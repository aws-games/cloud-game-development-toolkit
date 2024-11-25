################################################################################
# Scylla Instance Profile
################################################################################

resource "aws_iam_instance_profile" "scylla_instance_profile" {
  name = "scylladb_instance_profile"
  role = aws_iam_role.scylla_role.name
}
################################################################################
# Scylla Instances
################################################################################
resource "aws_instance" "scylla_ec2_instance" {
  count = length(var.scylla_private_subnets)

  ami             = data.aws_ami.scylla_ami.id
  instance_type   = var.scylla_instance_type
  security_groups = [aws_security_group.scylla_security_group.id]
  monitoring      = true

  subnet_id = element(var.private_subnets, count.index)

  user_data                   = local.scylla_user_data
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

  tags = {
    Name = "${var.name}-scylla-db"
  }
}
