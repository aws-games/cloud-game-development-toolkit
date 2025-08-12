# VPC Outputs
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.vdi_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs in the created VPC"
  value       = aws_subnet.vdi_public_subnet[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs in the created VPC"
  value       = aws_subnet.vdi_private_subnet[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.vdi_igw.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.vdi_nat_gateway.id
}

# Directory Outputs
output "directory_information" {
  description = "Directory information"
  value = {
    directory_id   = aws_directory_service_directory.managed_ad.id
    directory_name = aws_directory_service_directory.managed_ad.name
    dns_ips        = aws_directory_service_directory.managed_ad.dns_ip_addresses
    status         = "Managed AD created successfully"
  }
}

# VDI Instance Outputs
output "vdi_instances" {
  description = "Information about all VDI instances"
  value       = module.vdi.vdi_instances
}

output "vdi_instance_john_smith" {
  description = "Information about JohnSmith VDI instance"
  value = {
    id         = module.vdi.vdi_instances["JohnSmith"].id
    private_ip = module.vdi.vdi_instances["JohnSmith"].private_ip
    public_ip  = module.vdi.vdi_instances["JohnSmith"].public_ip
  }
}

output "vdi_instance_sarah_johnson" {
  description = "Information about SarahJohnson VDI instance"
  value = {
    id         = module.vdi.vdi_instances["SarahJohnson"].id
    private_ip = module.vdi.vdi_instances["SarahJohnson"].private_ip
    public_ip  = module.vdi.vdi_instances["SarahJohnson"].public_ip
  }
}

output "ami_info" {
  description = "Information about AMIs used"
  value       = module.vdi.ami_info
}

output "security_groups" {
  description = "Security groups for VDI instances"
  value       = module.vdi.vdi_security_groups
}

output "credentials_secrets" {
  description = "AWS Secrets Manager secrets for VDI credentials"
  value       = module.vdi.secrets_manager_secrets
}

output "credentials_instructions" {
  description = "Instructions for accessing stored credentials"
  value = "To retrieve credentials from AWS Secrets Manager, run:\naws secretsmanager get-secret-value --secret-id <SECRET_ID> --query 'SecretString' --output text | jq .\n\nAvailable secrets: ${join(", ", values(module.vdi.secrets_manager_secrets)[*].name)}"
}

# Optional DNS Outputs
output "vdi_dns_names" {
  description = "DNS names for VDI access (if domain_name provided)"
  value = var.domain_name != null && var.associate_public_ip_address ? {
    for user in keys(module.vdi.vdi_instances) : user => "vdi-${lower(user)}.${var.domain_name}"
  } : {}
}

# AD User Information
output "ad_user_info" {
  description = "Active Directory user information"
  value       = module.vdi.ad_user_info
}

# DCV Connection Information
output "dcv_connection_info" {
  description = "NICE DCV connection information for each user"
  value       = module.vdi.dcv_connection_info
}