# Fetch FSxN Password Value from Secrets Manager
data "aws_secretsmanager_secret" "fsxn_password" {
  arn = var.fsxn_password
}

data "aws_secretsmanager_secret_version" "fsxn_password" {
  secret_id = data.aws_secretsmanager_secret.fsxn_password.id
}

provider "netapp-ontap" {
  connection_profiles = [
    {
      name     = "aws"
      hostname = var.fsxn_mgmt_ip
      username = "fsxadmin"
      password = data.aws_secretsmanager_secret_version.fsxn_password.secret_string
      aws_lambda = {
        function_name         = aws_lambda_function.lambda_function[0].function_name
        region                = data.aws_region.current.name
        shared_config_profile = var.fsxn_aws_profile
      }
    }
  ]
}

resource "aws_iam_role" "lambda_role" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  name  = "LambdaLinkRole-link-perforce"

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

resource "aws_security_group" "fsxn_lambda_link_security_group" {
  name        = "fsxn-link-sg"
  description = "Security group for the FSxN Link Lambda."
  vpc_id      = var.vpc_id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "fsxn_lambda_link_security_group_egress_rule" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.fsxn_lambda_link_security_group.id
  description                  = "Grants outbound access from FSxN Lambda to FSxN filesystem"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = var.fsxn_filesystem_security_group_id
}

resource "aws_lambda_function" "lambda_function" {
  count         = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  function_name = "link-perforce"
  role          = aws_iam_role.lambda_role[count.index].arn
  package_type  = "Image"
  image_uri     = "052582346341.dkr.ecr.${var.fsxn_region}.amazonaws.com/fsx_link:production"
  vpc_config {
    security_group_ids = [aws_security_group.fsxn_lambda_link_security_group.id]
    subnet_ids         = [var.instance_subnet_id]
  }
  environment {
    variables = {
      NODE_TLS_REJECT_UNAUTHORIZED = "0"
      LATEST                       = "1.0.0"
    }
  }
  timeout = 10
}

resource "netapp-ontap_protocols_san_igroup_resource" "perforce_igroup" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  name            = "perforce"
  svm = {
    name = var.fsxn_svm_name
  }
  os_type    = "linux"
  protocol   = "iscsi"
  depends_on = [aws_lambda_function.lambda_function]
}
#
# resource "netapp-ontap_volume" "logs_vol" {
#   count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
#   cx_profile_name = "aws"
#   name            = "logs"
#   svm_name        = var.fsxn_svm_name
#   aggregates = [
#     {
#       name = "aggr1"
#     }
#   ]
#   space = {
#     size      = var.logs_volume_size
#     size_unit = "gb"
#   }
#   nas = {
#     junction_path = "/hxlogs"
#   }
#   depends_on = [aws_lambda_function.lambda_function]
# }

resource "netapp-ontap_lun" "logs_volume_lun" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.logs_volume_size * 0.75 * 1073741824
  svm_name        = var.fsxn_svm_name
  volume_name     = aws_fsx_ontap_volume.logs[0].name
  name            = "/vol/${aws_fsx_ontap_volume.logs[0].name}/${aws_fsx_ontap_volume.logs[0].name}"
  depends_on      = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_protocols_san_lun-maps_resource" "logs_lun_map" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.logs_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_protocols_san_igroup_resource.perforce_igroup[count.index].name
  }
  depends_on = [aws_lambda_function.lambda_function]
}

# resource "netapp-ontap_volume" "metadata_vol" {
#   count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
#   cx_profile_name = "aws"
#   name            = "metadata"
#   svm_name        = var.fsxn_svm_name
#   aggregates = [
#     {
#       name = "aggr1"
#     }
#   ]
#   space = {
#     size      = var.metadata_volume_size
#     size_unit = "gb"
#   }
#   nas = {
#     junction_path = "/hxmetadata"
#   }
#   depends_on = [aws_lambda_function.lambda_function]
# }

resource "netapp-ontap_lun" "metadata_volume_lun" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.metadata_volume_size * 0.75 * 1073741824
  svm_name        = var.fsxn_svm_name
  volume_name     = aws_fsx_ontap_volume.metadata[0].name
  name            = "/vol/${aws_fsx_ontap_volume.metadata[0].name}/${aws_fsx_ontap_volume.metadata[0].name}"
  depends_on      = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_protocols_san_lun-maps_resource" "metadata_lun_map" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.metadata_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_protocols_san_igroup_resource.perforce_igroup[count.index].name
  }
  depends_on = [aws_lambda_function.lambda_function]
}

# resource "netapp-ontap_volume" "depots_vol" {
#   count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
#   cx_profile_name = "aws"
#   name            = "depot"
#   svm_name        = var.fsxn_svm_name
#   aggregates = [
#     {
#       name = "aggr1"
#     }
#   ]
#   space = {
#     size      = var.depot_volume_size
#     size_unit = "gb"
#   }
#   nas = {
#     junction_path = "/hxdepots"
#   }
#   depends_on = [aws_lambda_function.lambda_function]
# }

resource "netapp-ontap_lun" "depots_volume_lun" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.depot_volume_size * 0.75 * 1073741824
  svm_name        = var.fsxn_svm_name
  volume_name     = aws_fsx_ontap_volume.depot[0].name
  name            = "/vol/${aws_fsx_ontap_volume.depot[0].name}/${aws_fsx_ontap_volume.depot[0].name}"
  depends_on      = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_protocols_san_lun-maps_resource" "depots_lun_map" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.depots_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_protocols_san_igroup_resource.perforce_igroup[count.index].name
  }
  depends_on = [aws_lambda_function.lambda_function]
}
