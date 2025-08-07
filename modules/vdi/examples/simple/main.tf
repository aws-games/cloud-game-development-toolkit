# Example: Using a VPC defined in the example
module "vdi" {
  source = "../../"

  # General Configuration
  name           = var.name
  project_prefix = var.project_prefix
  environment    = var.environment
  tags           = local.tags

  # VPC and Subnet IDs
  vpc_id     = aws_vpc.vdi_vpc.id
  subnet_id  = aws_subnet.vdi_public_subnet[0].id
  
  # Set to true if you want a public IP (not recommended for production)
  associate_public_ip_address = true # Set to true for testing to allow direct access

  # Instance Configuration
  instance_type = "g4dn.2xlarge"
  
  # Key Pair and Password Options
  create_key_pair = true
  admin_password  = var.admin_password # Required password for Windows admin
  
  # Storage Configuration
  root_volume_iops       = 4000
  root_volume_throughput = 250
  
  # Security Configuration - Restrict access to your network
  allowed_cidr_blocks = ["10.0.0.0/8", var.allowed_ip_address] # Add your public IP for access
  
  # Performance and monitoring settings
  ebs_optimized             = true
  enable_detailed_monitoring = true
  
  # AWS Secrets Manager configuration
  store_passwords_in_secrets_manager = true
  # secrets_kms_key_id = null # Set this to your KMS key ARN if you want to use a customer-managed key
  
  # Secret rotation is disabled for now - will be implemented in a future update
  enable_secrets_rotation   = false
  # secrets_rotation_days   = 30
  
  # Instance Metadata Service (IMDS) configuration - enforce IMDSv2
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 enforcement
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  # Additional EBS volume for file storage
  additional_ebs_volumes = [
    {
      device_name           = "/dev/xvdf"
      volume_size           = 1000
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
    }
  ]

  # AMI Selection - finds AMI created by the packer template
  ami_prefix = "windows-server-2025"

  # Tags are already defined above using local.tags
}

# Output important information
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

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.vdi_nat_gateway[*].id
}

output "vpc_flow_logs_enabled" {
  description = "Indicates if VPC Flow Logs are enabled"
  value       = local.enable_flow_logs
}

output "vpc_flow_logs_id" {
  description = "The ID of the VPC Flow Log"
  value       = length(aws_flow_log.vpc_flow_logs) > 0 ? aws_flow_log.vpc_flow_logs[0].id : null
}

output "vpc_flow_logs_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for VPC Flow Logs"
  value       = length(aws_cloudwatch_log_group.vpc_flow_logs) > 0 ? aws_cloudwatch_log_group.vpc_flow_logs[0].arn : null
}

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
  description = "Instructions for accessing credentials"
  value       = <<-EOT
    To retrieve the auto-generated credentials from AWS Secrets Manager, run:
    aws secretsmanager get-secret-value --secret-id ${module.vdi.secrets_manager_secret_id} --query 'SecretString' --output text | jq .
  EOT
}
