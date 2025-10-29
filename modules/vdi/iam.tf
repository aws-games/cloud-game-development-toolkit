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

resource "aws_iam_instance_profile" "vdi_instance_profile" {
  for_each = aws_iam_role.vdi_instance_role
  name     = "${local.name_prefix}-${each.key}-vdi-profile"
  role     = aws_iam_role.vdi_instance_role[each.key].name

  tags = merge(var.tags, local.assignment_tags[each.key], {
    Purpose     = "VDI-Instance-Profile"
    ProfileType = "Default"
  })
}

data "aws_iam_policy_document" "vdi_instance_access" {
  for_each = aws_iam_role.vdi_instance_role

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

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
      "ssm:UpdateInstanceInformation"
    ]
    resources = ["*"]
  }


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

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::dcv-license.${var.region}/*"
    ]
  }

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
}

resource "aws_iam_role_policy" "vdi_instance_access" {
  for_each = aws_iam_role.vdi_instance_role
  name     = "${local.name_prefix}-${each.key}-instance-access"
  role     = aws_iam_role.vdi_instance_role[each.key].id
  policy   = data.aws_iam_policy_document.vdi_instance_access[each.key].json
}

resource "aws_iam_role_policy_attachment" "vdi_ssm_managed_instance_core" {
  for_each   = aws_iam_role.vdi_instance_role
  role       = aws_iam_role.vdi_instance_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "vdi_cloudwatch_agent" {
  for_each   = var.enable_centralized_logging ? aws_iam_role.vdi_instance_role : {}
  role       = aws_iam_role.vdi_instance_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each = {
    for combo in flatten([
      for workstation_key, role in aws_iam_role.vdi_instance_role : [
        for policy_arn in local.final_instances[workstation_key].additional_policy_arns : {
          workstation_key = workstation_key
          policy_arn      = policy_arn
          key             = "${workstation_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}"
        }
      ]
    ]) : combo.key => combo
  }

  role       = aws_iam_role.vdi_instance_role[each.value.workstation_key].name
  policy_arn = each.value.policy_arn
}
