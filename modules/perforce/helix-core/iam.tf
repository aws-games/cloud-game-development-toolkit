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

# Grants permissions for Helix Core instance to fetch super user credentials from Secrets Manager and allows ansible to write logs to the CloudWatch Log Group
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

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${aws_s3_bucket.ansible_bucket.arn}/ssm-output/*"]
  }
}


resource "aws_iam_policy" "helix_core_default_policy" {
  name        = "${var.project_prefix}-helix-core-default-policy"
  description = "Policy granting permissions for Helix Core to access Secrets Manager."
  policy      = data.aws_iam_policy_document.helix_core_default_policy.json
}

# Instance Role
resource "aws_iam_role" "helix_core_default_role" {
  count              = var.create_helix_core_default_role ? 1 : 0
  name               = "${var.project_prefix}-${var.name}-helix-core-${var.server_type}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_relationship.json

  #managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", aws_iam_policy.helix_core_default_policy.arn]

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "helix_core_ssm_policy_attachment" {
  count      = var.create_helix_core_default_role ? 1 : 0
  role       = aws_iam_role.helix_core_default_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "helix_core_default_policy_attachment" {
  count      = var.create_helix_core_default_role ? 1 : 0
  role       = aws_iam_role.helix_core_default_role[0].name
  policy_arn = aws_iam_policy.helix_core_default_policy.arn
}

resource "aws_iam_role_policy_attachment" "helix_core_s3_readonly_attachment" {
  count      = var.create_helix_core_default_role ? 1 : 0
  role       = aws_iam_role.helix_core_default_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Instance Profile
resource "aws_iam_instance_profile" "helix_core_instance_profile" {
  name = "${local.name_prefix}-${random_string.helix_core.result}-instance-profile"
  role = var.custom_helix_core_role != null ? var.custom_helix_core_role : aws_iam_role.helix_core_default_role[0].name
}

