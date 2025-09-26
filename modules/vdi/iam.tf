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
    Purpose  = "VDI-Instance-Role"
    RoleType = "Default"
  })
}

# IAM instance profile for VDI instances (only create if user doesn't provide custom profile)
resource "aws_iam_instance_profile" "vdi_instance_profile" {
  for_each = aws_iam_role.vdi_instance_role
  name     = "${local.name_prefix}-${each.key}-vdi-profile"
  role     = aws_iam_role.vdi_instance_role[each.key].name

  tags = merge(var.tags, local.assignment_tags[each.key], {
    Purpose     = "VDI-Instance-Profile"
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
    resources = [
      for workstation_key in keys(var.workstations) :
      "arn:aws:ec2:${var.region}:*:instance/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Workstation"
      values   = [for workstation_key in keys(var.workstations) : workstation_key]
    }
  }

  # SSM permissions for software installation and hybrid user creation
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

  # Additional SSM permissions for hybrid approach (instance triggering SSM on itself)
  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:document/${local.name_prefix}-create-vdi-users",
      "arn:aws:ec2:${var.region}:*:instance/*"
    ]
  }

  # S3 permissions for installation scripts
  dynamic "statement" {
    for_each = [1] # S3 buckets always created
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

  # Secrets Manager permissions for Windows-side password generation and storage
  # NOTE: All Secrets Manager actions require "*" resources due to dynamic secret naming
  # and cross-workstation access patterns for fleet administrators
  # Security is provided by the SSM script only processing secrets with specific naming patterns
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }

  # Directory Service permissions removed (AD integration disabled)
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
