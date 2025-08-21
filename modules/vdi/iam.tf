# IAM role for VDI instances (shared across all users)
resource "aws_iam_role" "vdi_instance_role" {
  name = "${var.project_prefix}-vdi-instance-role"

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

# IAM instance profile (shared across all users)
resource "aws_iam_instance_profile" "vdi_instance_profile" {
  name = "${var.project_prefix}-vdi-instance-profile"
  role = aws_iam_role.vdi_instance_role.name

  tags = var.tags
}

# AWS Managed Policy: SSM Core functionality
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.vdi_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWS Managed Policy: Directory Service access (only when any user joins domain)
resource "aws_iam_role_policy_attachment" "ssm_directory_service_access" {
  count      = local.any_ad_join_required ? 1 : 0
  role       = aws_iam_role.vdi_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

# Basic policy for VDI instances - no secrets manager needed with standard password encryption
resource "aws_iam_role_policy" "vdi_basic_access" {
  name_prefix = "${var.project_prefix}-vdi-basic-access-"
  role        = aws_iam_role.vdi_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# Custom policy for NICE DCV license access
resource "aws_iam_role_policy" "vdi_dcv_license_access" {
  name_prefix = "${var.project_prefix}-vdi-dcv-license-access-"
  role        = aws_iam_role.vdi_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::dcv-license.${data.aws_region.current.id}/*"
      }
    ]
  })
}
