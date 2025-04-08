resource "aws_iam_role" "image_builder_iam_role" {
  name = "${local.name_prefix}-iam-role"
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
}

resource "aws_iam_instance_profile" "image_builder_instance_profile" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.image_builder_iam_role.name
}

# Attach managed policy for EC2 Image Builder
resource "aws_iam_role_policy_attachment" "image_builder_managed_policy" {
  role       = aws_iam_role.image_builder_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

# Attach managed policy for EC2 Image Builder container builds
resource "aws_iam_role_policy_attachment" "image_builder_container_policy" {
  role       = aws_iam_role.image_builder_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
}

# Attach managed policy for EC2 Image Builder SSM
resource "aws_iam_role_policy_attachment" "image_builder_ssm_policy" {
  role       = aws_iam_role.image_builder_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
