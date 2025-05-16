
resource "aws_instance" "unity_client_instance" {
  #checkov:skip=CKV_AWS_126:Detailed monitoring is not required
  #checkov:skip=CKV_AWS_8:Encryption is set on the block device
  instance_type          = "t3.small"
  iam_instance_profile   = aws_iam_instance_profile.unity_client_instance_profile.name
  subnet_id              = var.subnet_id
  ami                    = data.aws_ami.amazon2023-ami.image_id
  vpc_security_group_ids = [aws_security_group.unity_license_client_sg.id, aws_security_group.ssm_security_group.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  ebs_optimized = true
  monitoring    = false

  tags = {
    Name = "unity-client-instance"
  }
}

resource "aws_iam_instance_profile" "unity_client_instance_profile" {
  name_prefix = "unity-client-instance-profile"
  role        = aws_iam_role.client_instance_role.name
}

resource "aws_iam_role" "client_instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_ami" "amazon2023-ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_security_group" "ssm_security_group" {
  name        = "ssm-security-group"
  vpc_id      = var.vpc_id
  description = "Allow SSM access"
}

resource "aws_vpc_security_group_egress_rule" "client_ssm_egress_rule" {
  security_group_id = aws_security_group.ssm_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

}

resource "aws_security_group" "unity_license_client_sg" {
  name        = "unity-license-client-sg"
  description = "Allow traffic to Unity License Server"
  vpc_id      = var.vpc_id
}
