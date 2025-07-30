# Example: Creating a new VPC with public and private subnets
module "vdi" {
  source = "../../"

  # General Configuration
  name           = "new-vpc-vdi"
  project_prefix = "cgd"
  environment    = "dev"

  # Create a new VPC with public and private subnets
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"
  
  # Public and private subnets
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # Availability zones (if left empty, will use the first n available AZs in the region)
  # availability_zones = ["us-west-2a", "us-west-2b"]  # Uncomment and set specific AZs if needed
  
  # NAT Gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = true
  
  # Set to true if you want a public IP (not recommended for production)
  associate_public_ip_address = true # Set to true for testing to allow direct access

  # Instance Configuration
  instance_type = "g4dn.2xlarge"
  
  # Key Pair and Password Options
  create_key_pair                 = true
  store_passwords_in_secrets_manager = true
  admin_password                  = var.admin_password # Required password for Windows admin
  
  # Storage Configuration
  root_volume_iops       = 4000
  root_volume_throughput = 250
  
  # Security Configuration - Restrict access to your network
  allowed_cidr_blocks = ["10.0.0.0/8", var.allowed_ip_address] # Add your public IP for access
  
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

  # Custom tags
  tags = {
    Environment = "dev"
    Project     = "VDI-Example"
    Owner       = "DevOps-Team"
    Purpose     = "Development-Workstation"
  }
}

# Output important information
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = module.vdi.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs in the created VPC"
  value       = module.vdi.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs in the created VPC"
  value       = module.vdi.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vdi.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vdi.nat_gateway_ids
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
