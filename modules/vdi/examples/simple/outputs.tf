# VPC Outputs
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.vdi_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs in the created VPC"
  value       = aws_subnet.vdi_public_subnet[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.vdi_igw.id
}

# VDI Instance Outputs
output "vdi_instance_id" {
  description = "The ID of the VDI instance"
  value       = module.vdi.vdi_instance_id
}

output "vdi_private_ip" {
  description = "The private IP address of the VDI instance"
  value       = module.vdi.vdi_instance_private_ip
}

output "vdi_public_ip" {
  description = "The public IP address of the VDI instance (if assigned)"
  value       = module.vdi.vdi_instance_public_ip
}

output "ami_used" {
  description = "Information about the AMI used for the VDI instance"
  value = {
    id            = module.vdi.ami_id
    name          = module.vdi.ami_name
    creation_date = module.vdi.ami_creation_date
    source        = module.vdi.ami_source
  }
}

output "security_group_id" {
  description = "The security group ID for the VDI instance"
  value       = module.vdi.vdi_security_group_id
}

output "credentials_secret_id" {
  description = "The ID of the AWS Secrets Manager secret for the VDI"
  value       = module.vdi.secrets_manager_secret_id
}

output "credentials_instructions" {
  description = "Instructions for accessing stored credentials"
  value       = module.vdi.secrets_manager_secret_id != null ? "To retrieve credentials from AWS Secrets Manager, run:\naws secretsmanager get-secret-value --secret-id ${module.vdi.secrets_manager_secret_id} --query 'SecretString' --output text | jq ." : "No secrets stored in Secrets Manager"
}

# Simple AD Outputs
output "simple_ad_id" {
  description = "The ID of the Simple AD directory (if created)"
  value       = var.enable_simple_ad ? aws_directory_service_directory.simple_ad[0].id : null
}

output "simple_ad_name" {
  description = "The name of the Simple AD directory (if created)"
  value       = var.enable_simple_ad ? aws_directory_service_directory.simple_ad[0].name : null
}

output "simple_ad_dns_ip_addresses" {
  description = "The DNS IP addresses of the Simple AD directory (if created)"
  value       = var.enable_simple_ad ? aws_directory_service_directory.simple_ad[0].dns_ip_addresses : []
}

output "simple_ad_security_group_id" {
  description = "The security group ID for the Simple AD (if created)"
  value       = var.enable_simple_ad ? aws_security_group.simple_ad_sg[0].id : null
}

# Note: Additional domain join outputs available from module.vdi (domain_join_enabled, ssm_document_name, etc.)

# Optional DNS Output
output "vdi_dns_name" {
  description = "DNS name for VDI access (if domain_name provided)"
  value       = var.domain_name != null && var.associate_public_ip_address ? "vdi.${var.domain_name}" : null
}

# Connection Information
output "simple_ad_connection_info" {
  description = "Connection information for the Simple AD"
  value = var.enable_simple_ad ? {
    domain_name    = aws_directory_service_directory.simple_ad[0].name
    dns_servers    = aws_directory_service_directory.simple_ad[0].dns_ip_addresses
    admin_username = "Administrator"
    admin_password = "Stored in Secrets Manager"
    directory_id   = aws_directory_service_directory.simple_ad[0].id
  } : null
}

# Simple Connection Guide
output "connection_info" {
  description = "How to connect to your VDI workstation"
  value = {
    rdp_address   = var.domain_name != null && var.associate_public_ip_address ? "vdi.${var.domain_name}:3389" : "${module.vdi.vdi_instance_public_ip}:3389"
    dcv_address   = var.domain_name != null && var.associate_public_ip_address ? "https://vdi.${var.domain_name}:8443" : "https://${module.vdi.vdi_instance_public_ip}:8443"
    username      = var.enable_simple_ad ? "${var.directory_name}\\Administrator" : "Administrator"
    password_info = "Stored in AWS Secrets Manager"
    secret_id     = module.vdi.secrets_manager_secret_id
  }
}
