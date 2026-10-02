##########################################
# Storage Configuration - FSxN
##########################################
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
}

resource "aws_iam_role_policy_attachment" "lambda_service_basic_execution_role" {
  count      = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role[0].name
}

resource "aws_iam_role_policy_attachment" "lambda_service_role" {
  count      = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
  role       = aws_iam_role.lambda_role[0].name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_role" {
  count      = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role[0].name
}

resource "aws_security_group" "fsxn_lambda_link_security_group" {
  count       = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  name        = "fsxn-link-sg"
  description = "Security group for the FSxN Link Lambda."
  vpc_id      = var.vpc_id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "link_outbound_fsxn" {
  count                        = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.fsxn_lambda_link_security_group[0].id
  description                  = "Grants outbound access from FSxN Lambda to FSxN filesystem"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = var.fsxn_filesystem_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "fsxn_inbound_link" {
  count                        = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  ip_protocol                  = "tcp"
  security_group_id            = var.fsxn_filesystem_security_group_id
  description                  = "Allows inbound access from FSxN Lambda Link to Filesystem."
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.fsxn_lambda_link_security_group[0].id
}

resource "aws_lambda_function" "lambda_function" {
  #checkov:skip=CKV_AWS_50: X-Ray tracing not required
  #checkov:skip=CKV_AWS_116: DLQ not required
  #checkov:skip=CKV_AWS_173: Environment variables nonsensitive
  #$checkov:skip=CKV_AWS_272: AWS Lambda function code-signing not required

  count         = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  function_name = "link-perforce"
  role          = aws_iam_role.lambda_role[count.index].arn
  package_type  = "Image"
  image_uri     = "052582346341.dkr.ecr.${var.fsxn_region}.amazonaws.com/fsx_link:production"
  vpc_config {
    security_group_ids = [aws_security_group.fsxn_lambda_link_security_group[0].id]
    subnet_ids         = [var.instance_subnet_id]
  }
  environment {
    variables = {
      NODE_TLS_REJECT_UNAUTHORIZED = "0"
      LATEST                       = "1.0.0"
    }
  }
  reserved_concurrent_executions = 20 # Low reserved concurrency since this function is only used for FSxN calls from TF
  timeout                        = 10
}


// hxlogs
resource "aws_fsx_ontap_volume" "logs" {
  count                      = var.storage_type == "FSxN" ? 1 : 0
  storage_virtual_machine_id = var.amazon_fsxn_svm_id
  name                       = "logs"
  size_in_megabytes          = var.logs_volume_size * 1024
  tags                       = local.tags
  storage_efficiency_enabled = true
  junction_path              = "/hxlogs"
}

// hxmetadata
resource "aws_fsx_ontap_volume" "metadata" {
  count                      = var.storage_type == "FSxN" ? 1 : 0
  storage_virtual_machine_id = var.amazon_fsxn_svm_id
  name                       = "metadata"
  size_in_megabytes          = var.metadata_volume_size * 1024
  tags                       = local.tags
  storage_efficiency_enabled = true
  junction_path              = "/hxmetadata"
}

// hxdepot
resource "aws_fsx_ontap_volume" "depot" {
  count                      = var.storage_type == "FSxN" ? 1 : 0
  storage_virtual_machine_id = var.amazon_fsxn_svm_id
  name                       = "depot"
  size_in_megabytes          = var.depot_volume_size * 1024
  tags                       = local.tags
  storage_efficiency_enabled = true
  junction_path              = "/hxdepots"
}

resource "netapp-ontap_san_igroup" "perforce_igroup" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  name            = "perforce"
  svm = {
    name = var.fsxn_svm_name
  }
  os_type  = "linux"
  protocol = "iscsi"
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}

resource "netapp-ontap_lun" "logs_volume_lun" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.logs_volume_size * 0.75 * 1073741824
  svm_name        = var.fsxn_svm_name
  volume_name     = aws_fsx_ontap_volume.logs[0].name
  name            = "/vol/${aws_fsx_ontap_volume.logs[0].name}/${aws_fsx_ontap_volume.logs[0].name}"
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}

resource "netapp-ontap_san_lun-map" "logs_lun_map" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.logs_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_san_igroup.perforce_igroup[count.index].name
  }
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}

resource "netapp-ontap_lun" "metadata_volume_lun" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.metadata_volume_size * 0.75 * 1073741824
  svm_name        = var.fsxn_svm_name
  volume_name     = aws_fsx_ontap_volume.metadata[0].name
  name            = "/vol/${aws_fsx_ontap_volume.metadata[0].name}/${aws_fsx_ontap_volume.metadata[0].name}"
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}

resource "netapp-ontap_san_lun-map" "metadata_lun_map" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.metadata_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_san_igroup.perforce_igroup[count.index].name
  }
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}

resource "netapp-ontap_lun" "depots_volume_lun" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.depot_volume_size * 0.75 * 1073741824
  svm_name        = var.fsxn_svm_name
  volume_name     = aws_fsx_ontap_volume.depot[0].name
  name            = "/vol/${aws_fsx_ontap_volume.depot[0].name}/${aws_fsx_ontap_volume.depot[0].name}"
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}

resource "netapp-ontap_san_lun-map" "depots_lun_map" {
  count           = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.depots_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_san_igroup.perforce_igroup[count.index].name
  }
  depends_on = [
    aws_lambda_function.lambda_function,
    aws_vpc_security_group_egress_rule.link_outbound_fsxn,
    aws_vpc_security_group_ingress_rule.fsxn_inbound_link
  ]
}
