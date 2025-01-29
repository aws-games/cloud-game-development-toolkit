##########################################
# FSx ONTAP File System
##########################################

resource "aws_fsx_ontap_file_system" "helix_core_fs" {
  storage_capacity    = 1024
  subnet_ids          = [var.instance_subnet_id]
  preferred_subnet_id = var.instance_subnet_id
  deployment_type     = "SINGLE_AZ_1"
  throughput_capacity = 128
  fsx_admin_password = var.fsxn_password
}

resource "aws_fsx_ontap_storage_virtual_machine" "helix_core_svm" {
  file_system_id = aws_fsx_ontap_file_system.helix_core_fs.id
  name           = "helix_core_svm"
}

resource "awscc_secretsmanager_secret" "fsxn_user_password" {
  count         = var.protocol == "ISCSI" ? 1 : 0
  name          = "perforceFSxNuserPassword"
  secret_string = var.fsxn_password
}

module "perforce_helix_core" {
  source = "../../helix-core"
  providers = {
    aws = aws
  }

  # Networking
  vpc_id                      = var.vpc_id
  instance_subnet_id          = var.instance_subnet_id
  internal                    = true
  fully_qualified_domain_name = "core.helix.perforce.${var.root_domain_name}"


  # Compute and Storage
  instance_type         = "c8g.large"
  instance_architecture = "arm64"
  storage_type          = "FSxN"
  depot_volume_size     = 64
  metadata_volume_size  = 32
  logs_volume_size      = 32
  fsxn_region           = var.fsxn_region
  protocol              = var.protocol

  # FSxN configuration - FSxN NFS
  amazon_fsxn_filesystem_id = var.protocol == "NFS" ? aws_fsx_ontap_file_system.helix_core_fs.id : ""
  amazon_fsxn_svm_id        = var.protocol == "NFS" ? aws_fsx_ontap_storage_virtual_machine.helix_core_svm.id : ""

  # FSxN configuration - FSxN ISCSI
  fsxn_aws_profile     = var.protocol == "ISCSI" ? var.fsxn_aws_profile : ""
  fsxn_password        = var.protocol == "ISCSI" ? awscc_secretsmanager_secret.fsxn_user_password[0].secret_id : ""
  fsxn_mgmt_ip         = var.protocol == "ISCSI" ? "management.${aws_fsx_ontap_file_system.helix_core_fs.id}.fsx.${var.fsxn_region}.amazonaws.com" : ""
  fsxn_svm_name        = var.protocol == "ISCSI" ? aws_fsx_ontap_storage_virtual_machine.helix_core_svm.name : ""


  # Configuration
  plaintext                        = true # We will use the Perforce NLB to handle TLS termination
  server_type                      = "p4d_commit"

}