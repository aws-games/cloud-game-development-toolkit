resource "random_string" "helix_core" {
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

# Grants permissions for Helix Core instance to fetch super user credentials from Secrets Manager
data "aws_iam_policy_document" "helix_core_default_policy" {
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
    resources = [
      var.helix_core_super_user_username_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_username[0].secret_id : var.helix_core_super_user_username_secret_arn,
      var.helix_core_super_user_password_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_password[0].secret_id : var.helix_core_super_user_password_secret_arn,
    ]
  }
}

resource "aws_iam_policy" "helix_core_default_policy" {
  name        = "${var.project_prefix}-helix-core-default-policy"
  description = "Policy granting permissions for Helix Core to access Secrets Manager."
  policy      = data.aws_iam_policy_document.helix_core_default_policy.json

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-core-default-policy"
    }
  )
}

# Instance Role
resource "aws_iam_role" "helix_core_default_role" {
  count              = var.create_helix_core_default_role ? 1 : 0
  name               = "${var.project_prefix}-helix-core-default-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_relationship.json

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-core-default-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "helix_core_default_role_ssm_managed_instance_core" {
  count      = var.create_helix_core_default_role ? 1 : 0
  role       = aws_iam_role.helix_core_default_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "helix_core_default_role_helix_core_default_policy" {
  count      = var.create_helix_core_default_role ? 1 : 0
  role       = aws_iam_role.helix_core_default_role[0].name
  policy_arn = aws_iam_policy.helix_core_default_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "helix_core_instance_profile" {
  name = "${local.name_prefix}-helix-core-${random_string.helix_core.result}-instance-profile"
  role = var.custom_helix_core_role != null ? var.custom_helix_core_role : aws_iam_role.helix_core_default_role[0].name

  tags = merge(local.tags,
    {
      Name = "${var.project_prefix}-helix-core-default-instance-profile"
    }
  )
}
