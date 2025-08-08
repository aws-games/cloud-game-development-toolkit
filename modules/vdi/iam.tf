# IAM role for the VDI instance
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

# AWS Managed Policy: SSM Core functionality
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.vdi_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWS Managed Policy: Directory Service access (only when domain joining)
resource "aws_iam_role_policy_attachment" "ssm_directory_service_access" {
  count      = local.enable_domain_join ? 1 : 0
  role       = aws_iam_role.vdi_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

# Additional custom policy for Secrets Manager access (if needed)
resource "aws_iam_role_policy" "vdi_secrets_access" {
  count = var.store_passwords_in_secrets_manager ? 1 : 0
  name  = "${var.project_prefix}-${var.name}-secrets-access"
  role  = aws_iam_role.vdi_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.vdi_secrets[0].arn
      }
    ]
  })
}

# Custom policy for NICE DCV license access
resource "aws_iam_role_policy" "vdi_dcv_license_access" {
  name = "${var.project_prefix}-${var.name}-dcv-license-access"
  role = aws_iam_role.vdi_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::dcv-license.${data.aws_region.current.name}/*"
      }
    ]
  })
}
