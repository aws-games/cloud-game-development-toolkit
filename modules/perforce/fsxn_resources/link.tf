resource "aws_iam_role" "lambda_role" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  name = "LambdaLinkRole-link-perforce"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
  ]

  inline_policy {
    name = "LambdaPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:AssignPrivateIpAddresses",
            "ec2:UnassignPrivateIpAddresses"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "lambda_function" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  function_name = "link-perforce"
  role          = aws_iam_role.lambda_role[count.index].arn
  package_type  = "Image"
  image_uri     = "052582346341.dkr.ecr.${var.fsxn_region}.amazonaws.com/fsx_link:production"
  vpc_config {
    security_group_ids = var.security_group_ids
    subnet_ids         = [var.subnet_ids]
  }
  environment {
    variables = {
      NODE_TLS_REJECT_UNAUTHORIZED = "0"
      LATEST                      = "1.0.0"
    }
  }
  timeout = 10
}