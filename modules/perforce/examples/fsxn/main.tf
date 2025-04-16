##########################################
# FSx ONTAP File System
##########################################

resource "aws_security_group" "fsx_ontap_file_system_sg" {
  #checkov:skip=CKV2_AWS_5: False positive, this SG is used by the FSX service
  name        = "perforce-fsxn-file-system"
  description = "Perforce FSxN File System"
  vpc_id      = aws_vpc.perforce_vpc.id
  lifecycle {
    create_before_destroy = true
  }
}

# TODO: Restrict Security groups to allow access only from Helix Core server.
resource "aws_vpc_security_group_ingress_rule" "fsxn_ibound_helix_core_link" {
  ip_protocol       = "-1"
  description       = "Allows all inbound access from the VPC."
  security_group_id = aws_security_group.fsx_ontap_file_system_sg.id
  cidr_ipv4         = aws_vpc.perforce_vpc.cidr_block
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_fsx_ontap_file_system" "helix_core_fs" {
  #checkov:skip=CKV_AWS_178: CMK is out of scope.
  storage_capacity    = 1024
  subnet_ids          = [aws_subnet.private_subnets[0].id]
  preferred_subnet_id = aws_subnet.private_subnets[0].id
  deployment_type     = "SINGLE_AZ_1"
  throughput_capacity = 128
  fsx_admin_password  = var.fsxn_password
  security_group_ids  = [aws_security_group.fsx_ontap_file_system_sg.id]
}

resource "aws_fsx_ontap_storage_virtual_machine" "helix_core_svm" {
  file_system_id = aws_fsx_ontap_file_system.helix_core_fs.id
  name           = "helix_core_svm"
}

resource "awscc_secretsmanager_secret" "fsxn_user_password" {
  name          = "perforceFSxnUserPassword"
  secret_string = var.fsxn_password
}

##########################################
# Perforce Helix Core
##########################################

module "perforce_helix_core" {
  source = "../../helix-core"

  # Networking
  vpc_id                      = aws_vpc.perforce_vpc.id
  instance_subnet_id          = aws_subnet.private_subnets[0].id
  internal                    = false
  fully_qualified_domain_name = "core.helix.perforce.${var.root_domain_name}"

  # Compute and Storage
  instance_type         = "c8g.large"
  instance_architecture = "arm64"
  storage_type          = "FSxN"
  depot_volume_size     = 64
  metadata_volume_size  = 32
  logs_volume_size      = 32
  fsxn_region           = data.aws_region.current.name
  protocol              = "ISCSI"

  # FSxN configuration - FSxN ISCSI
  fsxn_aws_profile                  = var.fsxn_aws_profile
  fsxn_password                     = awscc_secretsmanager_secret.fsxn_user_password.secret_id
  fsxn_mgmt_ip                      = aws_fsx_ontap_file_system.helix_core_fs.endpoints[0].management[0].dns_name
  fsxn_svm_name                     = aws_fsx_ontap_storage_virtual_machine.helix_core_svm.name
  amazon_fsxn_svm_id                = aws_fsx_ontap_storage_virtual_machine.helix_core_svm.id
  fsxn_filesystem_security_group_id = aws_security_group.fsx_ontap_file_system_sg.id


  # Configuration
  server_type = "p4d_commit"
}
