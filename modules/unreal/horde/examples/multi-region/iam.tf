# IAM policies for multi-region Horde deployment
# These supplement the base policies created by the CGD Horde module.

# --- MRAP access for Horde ECS task role ---
# Allows the Horde server to read/write artifacts via the Multi-Region Access Point
resource "aws_iam_role_policy" "horde_mrap_access" {
  count = var.enable_mrap ? 1 : 0
  name  = "mrap-s3-access"
  role  = data.aws_iam_role.horde_task_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MRAPAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3control_multi_region_access_point.horde[0].arn,
          "${aws_s3control_multi_region_access_point.horde[0].arn}/object/*",
        ]
      },
      {
        Sid    = "UnderlyingBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.primary[0].arn,
          "${aws_s3_bucket.primary[0].arn}/*",
          aws_s3_bucket.secondary[0].arn,
          "${aws_s3_bucket.secondary[0].arn}/*",
        ]
      },
    ]
  })
}

# --- Cross-region fleet management for Horde ECS task role ---
# Allows the Horde server to manage EC2/ASG agents across regions
resource "aws_iam_role_policy" "horde_fleet_cross_region" {
  count = var.enable_secondary_region ? 1 : 0
  name  = "fleet-manager-cross-region"
  role  = data.aws_iam_role.horde_task_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:SetDesiredCapacity",
        "ec2:DescribeInstances",
        "ec2:CreateTags",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
      ]
      Resource = "*"
    }]
  })
}

# --- MRAP access for EU agents ---
# Allows secondary-region agents to upload/download artifacts via MRAP
resource "aws_iam_role_policy" "eu_agent_mrap_access" {
  count = var.enable_secondary_region && var.enable_mrap ? 1 : 0
  name  = "s3-mrap-access"
  role  = aws_iam_role.secondary_agents[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MRAPAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3control_multi_region_access_point.horde[0].arn,
          "${aws_s3control_multi_region_access_point.horde[0].arn}/object/*",
        ]
      },
      {
        Sid    = "UnderlyingBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.primary[0].arn,
          "${aws_s3_bucket.primary[0].arn}/*",
          aws_s3_bucket.secondary[0].arn,
          "${aws_s3_bucket.secondary[0].arn}/*",
        ]
      },
    ]
  })
}
