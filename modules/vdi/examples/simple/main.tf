# VDI Example Configuration
module "vdi" {
  source = "../../"

  # General Configuration
  name           = var.name
  project_prefix = var.project_prefix
  environment    = var.environment

  # Networking - Use the VPC and subnet created in vpc.tf
  vpc_id    = aws_vpc.vdi_vpc.id
  subnet_id = aws_subnet.vdi_public_subnet[0].id

  # Public IP assignment for VDI access
  associate_public_ip_address = var.associate_public_ip_address

  # Instance Configuration
  instance_type = var.instance_type

  # Key Pair and Password Options
  create_key_pair                    = var.create_key_pair
  store_passwords_in_secrets_manager = var.store_passwords_in_secrets_manager
  admin_password                     = var.admin_password

  # Simple AD Domain Join Configuration
  directory_id         = var.enable_simple_ad ? aws_directory_service_directory.simple_ad[0].id : null
  directory_name       = var.enable_simple_ad ? aws_directory_service_directory.simple_ad[0].name : null
  dns_ip_addresses     = var.enable_simple_ad ? aws_directory_service_directory.simple_ad[0].dns_ip_addresses : []
  ad_admin_password    = var.directory_admin_password

  # Storage Configuration
  root_volume_size       = var.root_volume_size
  root_volume_iops       = var.root_volume_iops
  root_volume_throughput = var.root_volume_throughput

  # Additional EBS volume for file storage
  additional_ebs_volumes = var.additional_ebs_volumes

  # Tags
  tags = local.common_tags
}
