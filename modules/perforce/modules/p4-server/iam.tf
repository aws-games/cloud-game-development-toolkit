resource "random_string" "p4_server" {
  length  = 4
  special = false
  upper   = false
}

#  EC2 Trust Relationship
data "aws_iam_policy_document" "ec2_trust_relationship" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Grants permissions for P4 Server instance to fetch super user credentials from Secrets Manager
data "aws_iam_policy_document" "default_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetRandomPassword",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:BatchGetSecretValue"
    ]
    resources = compact([
      var.super_user_password_secret_arn == null ? awscc_secretsmanager_secret.super_user_username[0].secret_id : var.super_user_password_secret_arn,
      var.super_user_username_secret_arn == null ? awscc_secretsmanager_secret.super_user_password[0].secret_id : var.super_user_username_secret_arn,
      var.storage_type == "FSxN" && var.protocol == "ISCSI" ? var.fsxn_password : null
    ])
  }
}

resource "aws_iam_policy" "default_policy" {
  name        = "${local.name_prefix}-default-policy"
  description = "Policy granting permissions for P4 Server to access Secrets Manager."
  policy      = data.aws_iam_policy_document.default_policy.json

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-default-policy"
    }
  )
}

# Instance Role
resource "aws_iam_role" "default_role" {
  count              = var.create_default_role ? 1 : 0
  name               = "${local.name_prefix}-default-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_relationship.json

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-default-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "default_role_ssm_managed_instance_core" {
  count      = var.create_default_role ? 1 : 0
  role       = aws_iam_role.default_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "default_role_default_policy" {
  count      = var.create_default_role ? 1 : 0
  role       = aws_iam_role.default_role[0].name
  policy_arn = aws_iam_policy.default_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${local.name_prefix}-${var.name}-${random_string.p4_server.result}-instance-profile"
  role = var.custom_role != null ? var.custom_role : aws_iam_role.default_role[0].name

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-default-instance-profile"
    }
  )
}
