locals {
  image            = "perforce/helix-auth-svc" # cannot change this until the Perforce Helix Authentication Service Image is updated to use the new naming for P4Auth
  name_prefix      = "${var.project_prefix}-${var.name}"
  data_volume_name = "helix-auth-config" # cannot change this until the Perforce Helix Authentication Service Image is updated to use the new naming for P4Auth
  data_path        = "/var/has"          # cannot change this until the Perforce Helix Authentication Service Image is updated to use the new naming for P4Auth
}
