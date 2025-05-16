resource "aws_iam_role" "unity_instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "unity_server_instance_profile" {
  name = "unity_server_instance_profile"
  role = aws_iam_role.unity_instance_role.name
}

resource "aws_iam_policy" "eip_attatch_policy" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PutS3Bucket",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
        ],
        "Resource" : "arn:aws:s3:::${var.unity_license_server_s3_bucket_name}/*"
      }
    ]
  })
}
