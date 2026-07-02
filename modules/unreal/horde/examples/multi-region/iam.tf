# IAM policies for multi-region Horde deployment
# These supplement the base policies created by the CGD Horde module.

# --- MRAP access for Horde ECS task role ---
# Allows the Horde server to read/write artifacts via the Multi-Region Access Point
resource "aws_iam_role_policy" "horde_mrap_access" {
  name = "mrap-s3-access"
  role = data.aws_iam_role.horde_task_role.name

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
          aws_s3control_multi_region_access_point.horde.arn,
          "${aws_s3control_multi_region_access_point.horde.arn}/object/*",
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
          aws_s3_bucket.primary.arn,
          "${aws_s3_bucket.primary.arn}/*",
          aws_s3_bucket.secondary.arn,
          "${aws_s3_bucket.secondary.arn}/*",
        ]
      },
    ]
  })
}

# --- Cross-region fleet management for Horde ECS task role ---
# Allows the Horde server to manage EC2/ASG agents across regions
resource "aws_iam_role_policy" "horde_fleet_cross_region" {
  name = "fleet-manager-cross-region"
  role = data.aws_iam_role.horde_task_role.name

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
  name = "s3-mrap-access"
  role = aws_iam_role.secondary_agents.name

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
          aws_s3control_multi_region_access_point.horde.arn,
          "${aws_s3control_multi_region_access_point.horde.arn}/object/*",
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
          aws_s3_bucket.primary.arn,
          "${aws_s3_bucket.primary.arn}/*",
          aws_s3_bucket.secondary.arn,
          "${aws_s3_bucket.secondary.arn}/*",
        ]
      },
    ]
  })
}
