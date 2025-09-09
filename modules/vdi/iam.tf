# IAM Configuration for VDI Module v2.0.0

# IAM role for VDI instances (only create if user doesn't provide custom profile)
resource "aws_iam_role" "vdi_instance_role" {
  for_each = { for k, v in local.final_instances : k => v if v.iam_instance_profile == null }
  name     = "${local.name_prefix}-${each.key}-vdi-role"

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

  tags = merge(var.tags, local.assignment_tags[each.key], {
    Purpose = "VDI-Instance-Role"
    RoleType = "Default"
  })
}

# IAM instance profile for VDI instances (only create if user doesn't provide custom profile)
resource "aws_iam_instance_profile" "vdi_instance_profile" {
  for_each = aws_iam_role.vdi_instance_role
  name     = "${local.name_prefix}-${each.key}-vdi-profile"
  role     = aws_iam_role.vdi_instance_role[each.key].name

  tags = merge(var.tags, local.assignment_tags[each.key], {
    Purpose = "VDI-Instance-Profile"
    ProfileType = "Default"
  })
}

# IAM policy document for VDI permissions
data "aws_iam_policy_document" "vdi_instance_access" {
  for_each = aws_iam_role.vdi_instance_role
  
  # Basic EC2 permissions for instance metadata and tags
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  # SSM permissions for software installation (Phase 3)
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
      "ssm:UpdateInstanceInformation"
    ]
    resources = ["*"]
  }

  # S3 permissions for installation scripts
  dynamic "statement" {
    for_each = [1]  # S3 buckets always created
    content {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.scripts.arn,
        "${aws_s3_bucket.scripts.arn}/*"
      ]
    }
  }

  # S3 permissions for DCV licensing (required for EC2 DCV licensing)
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::dcv-license.${var.region}/*"
    ]
  }

  # CloudWatch Logs permissions for centralized logging
  dynamic "statement" {
    for_each = var.enable_centralized_logging ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      resources = [
        "arn:aws:logs:${var.region}:*:log-group:${local.log_group_name}*"
      ]
    }
  }

  # Secrets Manager permissions for password management (always needed for user creation)
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:CreateSecret",
      "secretsmanager:PutSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:*:secret:${var.project_prefix}/*"
    ]
  }

  # Directory Service permissions for AD integration (Phase 4)
  dynamic "statement" {
    for_each = var.enable_ad_integration ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "ds:DescribeDirectories",
        "ds:AuthorizeApplication",
        "ds:UnauthorizeApplication"
      ]
      resources = ["*"]
    }
  }
}

# Attach permissions to VDI instance role
resource "aws_iam_role_policy" "vdi_instance_access" {
  for_each = aws_iam_role.vdi_instance_role
  name     = "${local.name_prefix}-${each.key}-instance-access"
  role     = aws_iam_role.vdi_instance_role[each.key].id
  policy   = data.aws_iam_policy_document.vdi_instance_access[each.key].json
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "vdi_ssm_managed_instance_core" {
  for_each   = aws_iam_role.vdi_instance_role
  role       = aws_iam_role.vdi_instance_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for CloudWatch Agent (if centralized logging enabled)
resource "aws_iam_role_policy_attachment" "vdi_cloudwatch_agent" {
  for_each   = var.enable_centralized_logging ? aws_iam_role.vdi_instance_role : {}
  role       = aws_iam_role.vdi_instance_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}