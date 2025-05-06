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

resource "aws_vpc_security_group_ingress_rule" "fsxn_inbound_helix_core" {
  ip_protocol                  = "-1"
  description                  = "Allows all inbound access from the VPC."
  security_group_id            = aws_security_group.fsx_ontap_file_system_sg.id
  referenced_security_group_id = module.perforce.security_group_id
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

module "perforce" {
  source = "../../"

  # - Shared -
  project_prefix       = local.project_prefix
  vpc_id               = aws_vpc.perforce_vpc.id
  public_subnets       = aws_subnet.public_subnets[*].id
  public_subnets_cidrs = local.public_subnet_cidrs
  private_subnets      = aws_subnet.private_subnets[*].id

  create_route53_private_hosted_zone = true
  route53_private_hosted_zone_name   = "${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # - P4 Server Configuration -
  p4_server_config = {
    # General
    name                        = "p4-server"
    fully_qualified_domain_name = local.p4_server_fully_qualified_domain_name

    # Compute
    lookup_existing_ami      = false
    enable_auto_ami_creation = true
    p4_server_type           = "p4d_commit"

    # Storage
    depot_volume_size    = 128
    metadata_volume_size = 32
    logs_volume_size     = 32

    storage_type                   = "FSxN"
    protocol                       = "ISCSI"
    fsxn_filesystem_security_group = aws_security_group.fsx_ontap_file_system_sg.id
    fsxn_file_system_id            = aws_fsx_ontap_file_system.helix_core_fs.id
    fsxn_password                  = awscc_secretsmanager_secret.fsxn_user_password.id
    fsxn_management_ip             = aws_fsx_ontap_file_system.helix_core_fs.endpoints[0].management[0].dns_name
    fsxn_svm_name                  = aws_fsx_ontap_storage_virtual_machine.helix_core_svm.name
    amazon_fsxn_svm_id             = aws_fsx_ontap_storage_virtual_machine.helix_core_svm.id
    fsxn_region                    = data.aws_region.current
    fsxn_aws_profile               = var.fsxn_aws_profile

    # Networking & Security
    instance_subnet_id = aws_subnet.public_subnets[0].id
  }
}
