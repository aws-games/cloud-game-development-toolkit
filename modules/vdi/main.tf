# VPC Creation
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Determine availability zones to use
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, length(var.private_subnet_cidrs))
  
  # Determine VPC and subnet IDs based on create_vpc variable
  vpc_id               = var.create_vpc ? aws_vpc.vdi_vpc[0].id : var.vpc_id
  subnet_id            = var.create_vpc ? aws_subnet.vdi_private_subnet[0].id : var.subnet_id
  public_subnet_count  = var.create_vpc ? length(var.public_subnet_cidrs) : 0
  private_subnet_count = var.create_vpc ? length(var.private_subnet_cidrs) : 0
}

# Create VPC if specified
resource "aws_vpc" "vdi_vpc" {
  count      = var.create_vpc ? 1 : 0
  cidr_block = var.vpc_cidr
  
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vpc"
  })
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "vdi_igw" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.vdi_vpc[0].id
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-igw"
  })
}

# Public subnets
resource "aws_subnet" "vdi_public_subnet" {
  count             = var.create_vpc ? local.public_subnet_count : 0
  vpc_id            = aws_vpc.vdi_vpc[0].id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index % length(local.availability_zones)]
  
  map_public_ip_on_launch = true
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-public-subnet-${count.index + 1}"
  })
}

# Private subnets
resource "aws_subnet" "vdi_private_subnet" {
  count             = var.create_vpc ? local.private_subnet_count : 0
  vpc_id            = aws_vpc.vdi_vpc[0].id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index % length(local.availability_zones)]
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-private-subnet-${count.index + 1}"
  })
}

# Route table for public subnets
resource "aws_route_table" "vdi_public_rt" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.vdi_vpc[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vdi_igw[0].id
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-public-rt"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "vdi_public_rta" {
  count          = var.create_vpc ? local.public_subnet_count : 0
  subnet_id      = aws_subnet.vdi_public_subnet[count.index].id
  route_table_id = aws_route_table.vdi_public_rt[0].id
}

# NAT Gateway for private subnets (if enabled)
resource "aws_eip" "vdi_nat_eip" {
  count      = var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.public_subnet_count) : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.vdi_igw[0]]
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "vdi_nat_gateway" {
  count         = var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.public_subnet_count) : 0
  allocation_id = aws_eip.vdi_nat_eip[count.index].id
  subnet_id     = aws_subnet.vdi_public_subnet[count.index].id
  depends_on    = [aws_internet_gateway.vdi_igw[0]]
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-nat-gateway-${count.index + 1}"
  })
}

# Route table for private subnets
resource "aws_route_table" "vdi_private_rt" {
  count  = var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.private_subnet_count) : (var.create_vpc ? 1 : 0)
  vpc_id = aws_vpc.vdi_vpc[0].id
  
  dynamic "route" {
    for_each = var.create_vpc && var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.vdi_nat_gateway[0].id : aws_nat_gateway.vdi_nat_gateway[count.index].id
    }
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-private-rt${var.single_nat_gateway ? "" : "-${count.index + 1}"}"
  })
}

# Associate private subnets with private route table
resource "aws_route_table_association" "vdi_private_rta" {
  count          = var.create_vpc ? local.private_subnet_count : 0
  subnet_id      = aws_subnet.vdi_private_subnet[count.index].id
  route_table_id = var.enable_nat_gateway ? (
    var.single_nat_gateway ? aws_route_table.vdi_private_rt[0].id : aws_route_table.vdi_private_rt[count.index].id
  ) : aws_route_table.vdi_private_rt[0].id
}

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
  vpc_id      = local.vpc_id
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

  subnet_id                   = local.subnet_id
  associate_public_ip_address = var.associate_public_ip_address

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vdi"
  })

  lifecycle {
    create_before_destroy = true
  }
}
