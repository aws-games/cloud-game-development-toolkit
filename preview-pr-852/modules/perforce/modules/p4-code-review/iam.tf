##########################################
# Random Strings
##########################################
# - Random Strings to prevent naming conflicts -
resource "random_string" "p4_code_review" {
  length  = 2
  special = false
  upper   = false
}


##########################################
# Policies
##########################################
# Secrets Manager Policy Document for EC2 instances
data "aws_iam_policy_document" "secrets_manager_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      var.super_user_username_secret_arn,
      var.super_user_password_secret_arn,
      var.p4_code_review_user_username_secret_arn,
      var.p4_code_review_user_password_secret_arn,
    ]
  }
}

# Secrets Manager Policy
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "${local.name_prefix}-secrets-manager-policy"
  description = "Policy granting permissions for ${local.name_prefix} EC2 instance to access Secrets Manager."
  policy      = data.aws_iam_policy_document.secrets_manager_policy.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-secrets-manager-policy"
    }
  )
}


##########################################
# EC2 Instance Role
##########################################
# EC2 - Instance Trust Relationship
data "aws_iam_policy_document" "ec2_instance_trust_relationship" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# EBS Volume Attachment Policy
data "aws_iam_policy_document" "ebs_attachment_policy" {
  # Describe operations require wildcard - AWS doesn't support resource-level permissions for these
  statement {
    sid    = "EBSDescribeOperations"
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  # Attach/detach operations scoped to the specific Swarm data volume
  statement {
    sid    = "EBSVolumeAttachDetach"
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:DetachVolume"
    ]
    resources = [
      aws_ebs_volume.swarm_data.arn,
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }
}

resource "aws_iam_policy" "ebs_attachment_policy" {
  name        = "${local.name_prefix}-ebs-attachment-policy"
  description = "Policy granting permissions for EC2 instance to attach EBS volumes."
  policy      = data.aws_iam_policy_document.ebs_attachment_policy.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-ebs-attachment-policy"
    }
  )
}

# EC2 Instance Role
resource "aws_iam_role" "ec2_instance_role" {
  name               = "${local.name_prefix}-ec2-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_trust_relationship.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-ec2-instance-role"
    }
  )
}

# Attach SSM Managed Instance Core (for SSM Session Manager access)
resource "aws_iam_role_policy_attachment" "ec2_instance_role_ssm" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach EBS Attachment Policy (for attaching persistent data volume)
resource "aws_iam_role_policy_attachment" "ec2_instance_role_ebs" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ebs_attachment_policy.arn
}

# Attach Secrets Manager Policy (for retrieving P4 credentials)
resource "aws_iam_role_policy_attachment" "ec2_instance_role_secrets_manager" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-ec2-instance-profile"
    }
  )
}
