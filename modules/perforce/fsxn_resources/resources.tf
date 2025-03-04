resource "netapp-ontap_protocols_san_igroup_resource" "perforce_igroup" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  name            = "perforce"
  svm = {
    name = var.amazon_fsxn_svm_name
  }
  os_type = "linux"
  protocol = "iscsi"
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_storage_volume_resource" "logs_vol" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  name            = "logs"
  svm_name        = var.amazon_fsxn_svm_name
  aggregates = [
    {
      name = "aggr1"
    }
  ]
  space = {
    size      = var.logs_volume_size
    size_unit = "gb"
  }
  nas = {
    junction_path = "/hxlogs"
  }
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_lun" "logs_volume_lun" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.logs_volume_size * 0.75 * 1073741824
  svm_name        = var.amazon_fsxn_svm_name
  volume_name     = netapp-ontap_storage_volume_resource.logs_vol[count.index].name
  name            = "/vol/${netapp-ontap_storage_volume_resource.logs_vol[count.index].name}/${netapp-ontap_storage_volume_resource.logs_vol[count.index].name}"
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_protocols_san_lun-maps_resource" "logs_lun_map" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.amazon_fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.logs_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_protocols_san_igroup_resource.perforce_igroup[count.index].name
  }
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_storage_volume_resource" "metadata_vol" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  name            = "metadata"
  svm_name        = var.amazon_fsxn_svm_name
  aggregates = [
    {
      name = "aggr1"
    }
  ]
  space = {
    size      = var.metadata_volume_size
    size_unit = "gb"
  }
  nas = {
    junction_path = "/hxmetadata"
  }
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_lun" "metadata_volume_lun" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.metadata_volume_size * 0.75 * 1073741824
  svm_name        = var.amazon_fsxn_svm_name
  volume_name     = netapp-ontap_storage_volume_resource.metadata_vol[count.index].name
  name            = "/vol/${netapp-ontap_storage_volume_resource.metadata_vol[count.index].name}/${netapp-ontap_storage_volume_resource.metadata_vol[count.index].name}"
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_protocols_san_lun-maps_resource" "metadata_lun_map" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.amazon_fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.metadata_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_protocols_san_igroup_resource.perforce_igroup[count.index].name
  }
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_storage_volume_resource" "depots_vol" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  name            = "depot"
  svm_name        = var.amazon_fsxn_svm_name
  aggregates = [
    {
      name = "aggr1"
    }
  ]
  space = {
    size      = var.depot_volume_size
    size_unit = "gb"
  }
  nas = {
    junction_path = "/hxdepots"
  }
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_lun" "depots_volume_lun" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  os_type         = "linux"
  size            = var.depot_volume_size * 0.75 * 1073741824
  svm_name        = var.amazon_fsxn_svm_name
  volume_name     = netapp-ontap_storage_volume_resource.depots_vol[count.index].name
  name            = "/vol/${netapp-ontap_storage_volume_resource.depots_vol[count.index].name}/${netapp-ontap_storage_volume_resource.depots_vol[count.index].name}"
  depends_on = [aws_lambda_function.lambda_function]
}

resource "netapp-ontap_protocols_san_lun-maps_resource" "depots_lun_map" {
  count = var.storage_type == "FSxN" && var.protocol == "ISCSI" ? 1 : 0
  cx_profile_name = "aws"
  svm = {
    name = var.amazon_fsxn_svm_name
  }
  lun = {
    name = netapp-ontap_lun.depots_volume_lun[count.index].name
  }
  igroup = {
    name = netapp-ontap_protocols_san_igroup_resource.perforce_igroup[count.index].name
  }
  depends_on = [aws_lambda_function.lambda_function]
}