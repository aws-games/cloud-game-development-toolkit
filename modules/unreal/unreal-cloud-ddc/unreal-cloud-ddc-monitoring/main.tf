resource "aws_iam_role" "scylla_monitoring_role" {
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
  name_prefix = "scylla-monitoring-"
}

resource "aws_iam_role_policy" "scylla_monitoring_policy" {
  name = "scylla-monitoring-policy"
  role = aws_iam_role.scylla_monitoring_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.scylla_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "scylla_monitoring_profile" {
  name = "scylla-monitoring-profile"
  role = aws_iam_role.scylla_monitoring_role.name
}

# Scylla monitoring security group
resource "aws_security_group" "scylla_monitoring_security_group" {
  name        = "scylla_monitoring_security_group"
  description = "Scylla monitoring security group"
  vpc_id      = var.vpc_id
  tags = {
    Name = "unreal-cloud-ddc-scylla-monitoring-sg"
  }
}

# Scylla monitoring security group egress rule allowing outbound traffic to the internet
resource "aws_security_group_rule" "scylla_monitoring_security_group_egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.scylla_monitoring_security_group.id
}


# Instance size calculation for 2 node scylla cluster
# 2 nodes * 8 vcpu * 15 day retention period * 12 MB = 2.88 GB
#Scylla monitoring instance
resource "aws_instance" "scylla_monitoring" {
  ami                    = "ami-05572e392e80aee89"
  instance_type          = "t3.xlarge"
  subnet_id              = var.monitoring_subnets[0]
  vpc_security_group_ids = [aws_security_group.scylla_monitoring_security_group.id]
  key_name               = "unreal-ddc-cgd"
  # docker installation as user data
  user_data = file("${path.module}/shell-scripts/scylla_monitoring.sh")
  # enable publid ip
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.scylla_monitoring_profile.name

  root_block_device {
    volume_size = 50
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "scylla-monitoring"
  }
}
