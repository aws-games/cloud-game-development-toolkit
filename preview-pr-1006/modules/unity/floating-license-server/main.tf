####################################################
# S3 Bucket for temp storage
####################################################
# This bucket will eventually be mounted to the EC2 instance running the service

# Create the S3 bucket
resource "aws_s3_bucket" "unity_license_server_bucket" {
  # checkov:skip=CKV_AWS_18:  Ensure the S3 bucket has access logging enabled (unneeded)
  # checkov:skip=CKV_AWS_21:  Ensure all data stored in the S3 bucket have versioning enabled (unneeded)
  # checkov:skip=CKV2_AWS_61: Ensure that an S3 bucket has a lifecycle (unneeded)
  # checkov:skip=CKV2_AWS_62: Ensure S3 buckets should have event notifications enabled (unneeded)
  # checkov:skip=CKV_AWS_144: Ensure that S3 bucket has cross-region replication enabled (unneeded)

  bucket_prefix = var.unity_license_server_bucket_name

  tags = merge(var.tags, {
    Name = "${var.name}-s3-bucket"
  })
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket                  = aws_s3_bucket.unity_license_server_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.unity_license_server_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Upload the Unity Floating License Server zip file to S3
resource "aws_s3_object" "unity_license_file" {
  bucket       = aws_s3_bucket.unity_license_server_bucket.id
  key          = basename(var.unity_license_server_file_path)
  source       = var.unity_license_server_file_path
  content_type = "application/zip"

  depends_on = [
    aws_s3_bucket.unity_license_server_bucket
  ]
}

####################################################
# Unity Floating License Server Secrets Manager
####################################################
# For admin dashboard password
# Note that the administrator username is "admin" and cannot be changed

resource "awscc_secretsmanager_secret" "admin_password_arn" {
  count       = var.unity_license_server_admin_password_arn == null ? 1 : 0
  name        = "${var.name}-admin-password"
  description = "The Unity Floating License Server admin password."

  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
    password_length     = 12
  }
}

####################################################
# Security Group for Unity Floating License Server
####################################################

# Create security group if an ENI was not provided and the script will create one
resource "aws_security_group" "unity_license_server_sg" {
  count       = !local.eni_provided ? 1 : 0
  name        = "${var.name}-sg"
  description = "Security group allowing traffic for Unity Floating License Server"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

# Ingress rule from ALB, if created
resource "aws_vpc_security_group_ingress_rule" "unity_license_server_ingress_from_alb_8080" {
  #checkov:skip=CKV_AWS_260:Dashboard is password-protected

  count                        = var.create_alb ? 1 : 0
  security_group_id            = aws_security_group.unity_license_server_sg[0].id
  referenced_security_group_id = aws_security_group.unity_license_server_alb_sg[0].id
  description                  = "Allows HTTP traffic on from the Application Load Balancer"
  from_port                    = var.unity_license_server_port
  to_port                      = var.unity_license_server_port
  ip_protocol                  = "TCP"
}

# Egress rule for all outbound traffic
resource "aws_vpc_security_group_egress_rule" "unity_license_server_egress_all" {
  #checkov:skip=CKV_AWS_382

  count             = !local.eni_provided ? 1 : 0
  security_group_id = aws_security_group.unity_license_server_sg[0].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
}

#############################################################
# Elastic Network Interface and Elastic IP (if needed)
#############################################################

# Data source to fetch existing ENI if specified
data "aws_network_interface" "existing_eni" {
  count = local.eni_provided ? 1 : 0
  id    = var.existing_eni_id
}

# Create new ENI only if existing_eni_id is not provided
resource "aws_network_interface" "unity_license_server_eni" {
  count           = !local.eni_provided ? 1 : 0
  subnet_id       = var.vpc_subnet
  security_groups = [aws_security_group.unity_license_server_sg[0].id]

  tags = merge(var.tags, {
    Name = "${var.name}-eni"
  })
}

# Elastic IP (created only if create_public_ip is true and the ENI is created by the script, not provided by the user)
resource "aws_eip" "unity_license_server_eip" {
  # checkov:skip=CKV2_AWS_19: Ensure that all EIP addresses allocated to a VPC are attached to EC2 instances

  count             = var.add_eni_public_ip && !local.eni_provided ? 1 : 0
  domain            = "vpc"
  network_interface = local.eni_id

  tags = merge(var.tags, {
    Name = "${var.name}-eip"
  })
}

#############################################################
# EC2 Instance to run Unity Floating License Server
#############################################################

# IAM role and policy for EC2 to access S3 and Secrets Manager
resource "aws_iam_role" "ec2_access_role" {
  name = "${var.name}-ec2-access-role"

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
}

resource "aws_iam_role_policy" "access_policy" {
  name = "${var.name}-access-policy"
  role = aws_iam_role.ec2_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 access policy
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.unity_license_server_bucket.arn,
          "${aws_s3_bucket.unity_license_server_bucket.arn}/*"
        ]
      },
      # Secrets Manager access policy
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          local.admin_password_arn
        ]
      },
      # SSM access policy
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# AmazonSSMManagedInstanceCore managed policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2_access_role.name
}

# Data source to get the latest Ubuntu 24.04 LTS AMI from Canonical Ltd's official AWS account
data "aws_ami" "ubuntu_latest" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "unity_license_server" {
  # checkov:skip=CKV_AWS_126: Ensure that detailed monitoring is enabled for EC2 instances

  ami                     = coalesce(var.unity_license_server_instance_ami_id, data.aws_ami.ubuntu_latest.id)
  instance_type           = var.unity_license_server_instance_type
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name
  ebs_optimized           = true
  monitoring              = var.enable_instance_detailed_monitoring
  disable_api_termination = var.enable_instance_termination_protection

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.unity_license_server_instance_ebs_size
    volume_type = "gp3"
    encrypted   = true
  }

  # Specify the network interface as the primary network interface
  network_interface {
    network_interface_id  = local.eni_id
    delete_on_termination = false
    network_card_index    = 0
    device_index          = 0
  }

  user_data = templatefile("${path.module}/scripts/user_data.tpl", {
    server_setup_script = templatefile("${path.module}/scripts/server_setup.sh", {
      license_server_file_name     = basename(var.unity_license_server_file_path)
      license_server_name          = var.unity_license_server_name
      license_server_port          = var.unity_license_server_port
      s3_bucket_name               = aws_s3_bucket.unity_license_server_bucket.id
      iam_role_name                = aws_iam_role.ec2_access_role.name
      admin_password_arn           = local.admin_password_arn
      server_setup_expect          = file("${path.module}/scripts/server_setup_expect.exp")
      server_setup_systemd_service = file("${path.module}/scripts/server_setup_systemd.service")
    })
    daemon_setup_script = templatefile("${path.module}/scripts/daemon_setup.sh", {
      daemon_setup_watch = templatefile("${path.module}/scripts/daemon_setup_watch.sh", {
        license_server_name = var.unity_license_server_name
      })
      daemon_setup_expect = templatefile("${path.module}/scripts/daemon_setup_expect.exp", {
        license_server_name = var.unity_license_server_name
      })
      daemon_setup_systemd_service = file("${path.module}/scripts/daemon_setup_systemd.service")
    })
  })

  tags = merge(var.tags, {
    Name = "${var.name}-ec2"
  })

  # Wait for instance to be ready
  user_data_replace_on_change = true

  depends_on = [
    aws_network_interface.unity_license_server_eni,
    aws_eip.unity_license_server_eip,
    aws_security_group.unity_license_server_sg
  ]
}

# Data source to check instance status
data "aws_instance" "unity_license_server" {
  instance_id = aws_instance.unity_license_server.id
  depends_on  = [aws_instance.unity_license_server]
}

# Resource to wait for instance to be ready and user data to complete
resource "null_resource" "wait_for_user_data" {
  depends_on = [
    data.aws_instance.unity_license_server,
    aws_lb.unity_license_server_alb,
    aws_lb_listener.unity_license_server_https_dashboard_listener,
    aws_lb_listener.unity_license_server_https_dashboard_redirect,
    aws_lb_target_group_attachment.unity_license_server
  ]

  provisioner "local-exec" {
    command = <<-EOF
      # Wait for instance to be ready (up to 10 minutes)
      ATTEMPTS=60
      until aws ec2 describe-instance-status --instance-ids ${aws_instance.unity_license_server.id} --query "InstanceStatuses[0].InstanceStatus.Status" --output text | grep -q "ok" || [ $ATTEMPTS -eq 0 ]; do
        sleep 10
        ATTEMPTS=$((ATTEMPTS-1))
      done

      if [ $ATTEMPTS -eq 0 ]; then
        echo "Timeout waiting for instance to be ready"
        exit 1
      fi

      # Wait for user data script completion by searching for the end user data script token echoed at the end of the script (up to 15 minutes)
      ATTEMPTS=90
      until aws ec2 get-console-output --instance-id ${aws_instance.unity_license_server.id} --output text | grep -q "[END_UDS_TKN]" || [ $ATTEMPTS -eq 0 ]; do
        sleep 10
        ATTEMPTS=$((ATTEMPTS-1))
      done

      if [ $ATTEMPTS -eq 0 ]; then
        echo "Timeout waiting for user data script completion"
        exit 1
      fi

      echo "User data script completed successfully"
    EOF
  }
}

####################################################
# S3 Presigned URLS for Unity Floating License Server Files
####################################################
# server-registration-request.xml needs to be uploaded to Unity ID portal to receive a compressed license archive file.
# services-config.json must be copied to end user computer in order to enable floating licensing

# Generate presigned URLs after user data completion
resource "null_resource" "generate_presigned_urls" {
  depends_on = [null_resource.wait_for_user_data]

  # Generating for 1 hour (3600 seconds). Can always be retrieved from the S3 bucket however
  provisioner "local-exec" {
    command = <<-EOF
      echo "Generating presigned URLs..."
      echo $(aws s3 presign s3://${aws_s3_bucket.unity_license_server_bucket.id}/server-registration-request.xml --expires-in 3600) > ${path.module}/registration_url.txt
      echo $(aws s3 presign s3://${aws_s3_bucket.unity_license_server_bucket.id}/services-config.json --expires-in 3600) > ${path.module}/config_url.txt
    EOF
  }
}

# Add data sources to read the generated URLs
data "local_file" "registration_url" {
  depends_on = [null_resource.generate_presigned_urls]
  filename   = "${path.module}/registration_url.txt"
}

data "local_file" "config_url" {
  depends_on = [null_resource.generate_presigned_urls]
  filename   = "${path.module}/config_url.txt"
}
