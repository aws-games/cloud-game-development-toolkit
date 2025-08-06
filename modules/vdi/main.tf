# Module setup
locals {
  vpc_id     = var.vpc_id
  subnet_id  = var.subnet_id
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

locals {
  # We're removing the password setting from user_data and using SSM instead
  encoded_user_data = var.user_data_base64
}

# Generate a random string to make the secret name unique
resource "random_string" "secret_suffix" {
  count   = var.store_passwords_in_secrets_manager ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# Store secrets in AWS Secrets Manager if enabled
resource "aws_secretsmanager_secret" "vdi_secrets" {
  count = var.store_passwords_in_secrets_manager ? 1 : 0
  name  = "${var.project_prefix}-${var.name}-secrets-${random_string.secret_suffix[0].result}"
  
  # Use a customer-managed KMS key if provided, otherwise AWS will use the default AWS managed key
  kms_key_id = var.secrets_kms_key_id
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "vdi_secrets" {
  count     = var.store_passwords_in_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.vdi_secrets[0].id
  
  secret_string = jsonencode({
    private_key    = var.key_pair_name == null && var.create_key_pair ? tls_private_key.vdi_key[0].private_key_pem : null
    admin_password = var.admin_password
  })
}

# Secret rotation configuration
resource "aws_secretsmanager_secret_rotation" "vdi_secrets_rotation" {
  count               = var.store_passwords_in_secrets_manager && var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.vdi_secrets[0].id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotation_lambda[0].outputs["RotationLambdaARN"]
  
  rotation_rules {
    automatically_after_days = var.secrets_rotation_days
  }
}

# Use AWS Serverless Application Repository for the rotation lambda
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotation_lambda" {
  count           = var.store_passwords_in_secrets_manager && var.enable_secrets_rotation ? 1 : 0
  name            = "${var.project_prefix}-${var.name}-rotation-lambda"
  application_id  = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRotationTemplate"
  semantic_version = "1.1.3"
  capabilities    = ["CAPABILITY_IAM"]
  
  parameters = {
    endpoint       = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    functionName   = "${var.project_prefix}-${var.name}-rotation-lambda"
    excludeCharacters = " %+~`#$&*()|[]{}:;<>?!'/@\"\\"
    vpcSubnetIds   = ""
    vpcSecurityGroupIds = ""
  }
  
  tags = var.tags
}

# These IAM resources are no longer needed since we're using the AWS Serverless Application Repository
# which creates the necessary IAM roles and permissions automatically

# Get current region for the Lambda environment variables
data "aws_region" "current" {}

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

# Attach the AWS managed policy for SSM to ensure complete SSM functionality
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.vdi_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:UpdateAssociationStatus",
          "ssm:CreateAssociation",
          "ssm:UpdateAssociation",
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
      },
      {
        # Allow access to Secrets Manager for secure password retrieval
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.store_passwords_in_secrets_manager ? [aws_secretsmanager_secret.vdi_secrets[0].arn] : []
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
  ebs_optimized = var.ebs_optimized  # Use the configurable variable for EBS optimization
  
  # Enable detailed monitoring (1-minute metrics) if specified
  monitoring {
    enabled = var.enable_detailed_monitoring
  }
  
  # Configure Instance Metadata Service - enforce IMDSv2
  metadata_options {
    http_endpoint               = var.metadata_options.http_endpoint
    http_tokens                 = var.metadata_options.http_tokens  # "required" enforces IMDSv2
    http_put_response_hop_limit = var.metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = var.metadata_options.instance_metadata_tags
  }

  # Security groups are specified only in network_interfaces, not at the top level
  network_interfaces {
    subnet_id                   = local.subnet_id
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [aws_security_group.vdi_sg.id]
  }

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

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vdi"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSM document for setting the Administrator password
resource "aws_ssm_document" "set_admin_password" {
  count           = var.create_instance && var.admin_password != null ? 1 : 0
  name            = "${var.project_prefix}-${var.name}-set-password"
  document_type   = "Command"
  document_format = "YAML"
  
  content = <<DOC
schemaVersion: '2.2'
description: 'Set Windows Administrator password and configure NICE DCV'
parameters:
  Password:
    type: SecureString
    description: 'Administrator password'
    # No default value provided - will be passed at runtime
mainSteps:
  - action: aws:runPowerShellScript
    name: setPassword
    inputs:
      runCommand:
        - |
          # Set the Administrator password using multiple methods for reliability
          try {
            $password = '{{Password}}'
            
            # Method 1: Using ADSI
            $admin = [adsi]('WinNT://./Administrator, user')
            $admin.psbase.invoke('SetPassword', $password)
            Write-Host "Password set using ADSI method"
          } catch {
            Write-Host "ADSI method failed: $_"
          }
          
          # Method 2: Using Net User command (more reliable on Windows Server)
          try {
            net user Administrator $password /active:yes
            Write-Host "Password set using net user command"
          } catch {
            Write-Host "Net user command failed: $_"
          }
          
          # Method 3: Enable NICE DCV Console Session Authentication
          try {
            Set-ItemProperty -Path "HKLM:\\SOFTWARE\\GSettings\\com\\nicesoftware\\dcv\\security" -Name "auth-console-session" -Value "true" -Type String -ErrorAction SilentlyContinue
            Write-Host "Enabled NICE DCV console session authentication"
          } catch {
            Write-Host "DCV configuration failed: $_"
          }
          
          # Restart NICE DCV service to apply changes
          try {
            Restart-Service -Name dcvserver -Force -ErrorAction SilentlyContinue
            Write-Host "Restarted NICE DCV service"
          } catch {
            Write-Host "DCV service restart failed: $_"
          }
DOC

  tags = var.tags
}

# SSM command to execute the document on the instance
resource "aws_ssm_association" "run_password_command" {
  count       = var.create_instance && var.admin_password != null && var.store_passwords_in_secrets_manager ? 1 : 0
  name        = aws_ssm_document.set_admin_password[0].name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.vdi_instance[0].id]
  }
  
  # Use AWS Secrets Manager as parameter source for secure password handling
  parameters = {
    "Password" = "{{ssm-secure:${aws_secretsmanager_secret.vdi_secrets[0].name}:admin_password}}"
  }
  
  depends_on = [aws_instance.vdi_instance, aws_secretsmanager_secret_version.vdi_secrets]
}
