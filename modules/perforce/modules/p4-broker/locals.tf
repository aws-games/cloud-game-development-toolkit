locals {
  name_prefix        = "${var.project_prefix}-${var.name}"
  config_volume_name = "p4-broker-config"
  config_path        = "/config"
}
