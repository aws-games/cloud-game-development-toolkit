# Generate a key pair if one is not provided
resource "tls_private_key" "vdi_key" {
  count     = var.key_pair_name == null && var.create_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vdi_key_pair" {
  count      = var.key_pair_name == null && var.create_key_pair ? 1 : 0
  key_name   = "${var.project_prefix}-${var.name}-key"
  public_key = tls_private_key.vdi_key[0].public_key_openssh

  tags = var.tags
}

# Generate a random password if one is not provided
resource "random_password" "admin_password" {
  count   = var.admin_password == null ? 1 : 0
  length  = 16
  special = true
  # AWS Windows passwords must not contain / or @
  override_special = "!#$%^&*()_+[]{}|;:,.<>?"
}

locals {
  # Use the provided password or the generated one
  admin_password = var.admin_password != null ? var.admin_password : (length(random_password.admin_password) > 0 ? random_password.admin_password[0].result : null)
  # Generate user data for password setting if a password is available
  user_data_script = local.admin_password != null ? <<-EOT
    <powershell>
    $admin = [adsi]("WinNT://./administrator, user")
    $admin.psbase.invoke("SetPassword", "${local.admin_password}")
    </powershell>
  EOT
  : null
  
  encoded_user_data = local.user_data_script != null ? base64encode(local.user_data_script) : var.user_data_base64
}

# Store secrets in AWS Secrets Manager if enabled
resource "aws_secretsmanager_secret" "vdi_secrets" {
  count = var.store_passwords_in_secrets_manager ? 1 : 0
  name  = "${var.project_prefix}-${var.name}-secrets"
  tags  = var.tags
}

resource "aws_secretsmanager_secret_version" "vdi_secrets" {
  count     = var.store_passwords_in_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.vdi_secrets[0].id
  
  secret_string = jsonencode({
    private_key    = var.key_pair_name == null && var.create_key_pair ? tls_private_key.vdi_key[0].private_key_pem : null
    admin_password = local.admin_password
  })
}

# Data source to find the AMI created by the packer template
data "aws_ami" "windows_server_2025_vdi" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  # Use either the provided AMI ID or the discovered AMI ID
  ami_id = var.ami_id != null ? var.ami_id : (length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].id : null)
}

# Security group for the VDI instance
resource "aws_security_group" "vdi_sg" {
  name_prefix = "${var.project_prefix}-${var.name}-vdi-"
  vpc_id      = var.vpc_id
  description = "Security group for VDI instances"

  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "RDP access"
  }

  # NICE DCV access (HTTPS)
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "NICE DCV HTTPS access"
  }

  # NICE DCV access (UDP for QUIC protocol)
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "udp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "NICE DCV QUIC access"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vdi-sg"
  })
}

# IAM role for the VDI instance - should this be the one kevon creates in his CFN template?
resource "aws_iam_role" "vdi_instance_role" {
  name = "${var.project_prefix}-${var.name}-vdi-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM instance profile
resource "aws_iam_instance_profile" "vdi_instance_profile" {
  name = "${var.project_prefix}-${var.name}-vdi-instance-profile"
  role = aws_iam_role.vdi_instance_role.name

  tags = var.tags
}

# IAM policy for VDI instance
resource "aws_iam_role_policy" "vdi_instance_policy" {
  name = "${var.project_prefix}-${var.name}-vdi-instance-policy"
  role = aws_iam_role.vdi_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })
}

# Launch template for the VDI instance
resource "aws_launch_template" "vdi_launch_template" {
  name_prefix   = "${var.project_prefix}-${var.name}-vdi-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != null ? var.key_pair_name : (var.create_key_pair ? aws_key_pair.vdi_key_pair[0].key_name : null)

  vpc_security_group_ids = [aws_security_group.vdi_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.vdi_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 512  # Changed to 512 GB as requested
      volume_type           = var.root_volume_type
      iops                  = var.root_volume_type == "gp3" ? var.root_volume_iops : null
      throughput            = var.root_volume_type == "gp3" ? var.root_volume_throughput : null
      delete_on_termination = true
      encrypted             = var.ebs_encryption_enabled
      kms_key_id            = var.ebs_kms_key_id
    }
  }

  # Additional EBS volumes if specified
  dynamic "block_device_mappings" {
    for_each = var.additional_ebs_volumes
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_size           = block_device_mappings.value.volume_size
        volume_type           = block_device_mappings.value.volume_type
        iops                  = block_device_mappings.value.volume_type == "gp3" ? block_device_mappings.value.iops : null
        throughput            = block_device_mappings.value.volume_type == "gp3" ? block_device_mappings.value.throughput : null
        delete_on_termination = block_device_mappings.value.delete_on_termination
        encrypted             = var.ebs_encryption_enabled
        kms_key_id            = var.ebs_kms_key_id
      }
    }
  }

  user_data = local.encoded_user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_prefix}-${var.name}-vdi"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.project_prefix}-${var.name}-vdi-volume"
    })
  }

  tags = var.tags
}

# EC2 instance for VDI
resource "aws_instance" "vdi_instance" {
  count = var.create_instance ? 1 : 0

  launch_template {
    id      = aws_launch_template.vdi_launch_template.id
    version = "$Latest"
  }

  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vdi"
  })

  lifecycle {
    create_before_destroy = true
  }
}
