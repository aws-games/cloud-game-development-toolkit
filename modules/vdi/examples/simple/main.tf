# Example usage of the VDI module
module "vdi" {
  source = "../../"

  # General Configuration
  name           = "example-vdi"
  project_prefix = "cgd"
  environment    = "dev"

  # Networking Configuration
  # TODO: Replace with actual VPC ID and subnet ID
  vpc_id    = "vpc-12345678"
  subnet_id = "subnet-12345678"
  
  # Set to true if you want a public IP (not recommended for production)
  associate_public_ip_address = false

  # Instance Configuration
  instance_type = "g4dn.2xlarge"
  
  # Key Pair and Password Options
  # Option 1: Auto-generate key pair and password (default) (comment this line if you want to use your own password and key pair)
  create_key_pair                 = true  # This is the default behavior
  store_passwords_in_secrets_manager = true  # Store in Secrets Manager
  
  # Option 2: Use existing key pair (uncomment this line and replace with your key pair name)
  # key_pair_name = "my-existing-key-pair"
  
  # Option 3: Provide a custom admin password (uncomment this line and replace with your password)
  # admin_password = "YourSecurePassword123!"  # Best set through variables or environment variables
  
  # Storage Configuration
  # Note: Default root volume is now 512GB
  root_volume_iops       = 4000
  root_volume_throughput = 250
  
  # Security Configuration - Restrict access to your network
  allowed_cidr_blocks = ["10.0.0.0/8"]  # Applies to RDP and NICE DCV ports
  
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

  # AMI Selection - Choose one of these options:
  
  # Option 1: Auto-discovery (default) - finds AMI created by the packer template
  ami_prefix = "windows-server-2025"
  
  # Option 2: Use a specific AMI (uncomment this line and replace with your AMI ID)
  # ami_id = "ami-0123456789abcdef0"  # Replace with your custom AMI ID

  # Custom tags
  tags = {
    Environment = "dev"
    Project     = "VDI-Example"
    Owner       = "DevOps-Team"
    Purpose     = "Development-Workstation"
  }
}

# Output important information
output "vdi_instance_id" {
  description = "The ID of the created VDI instance"
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

output "key_pair_name" {
  description = "The name of the key pair used for the VDI instance"
  value       = module.vdi.key_pair_name
}

output "credentials_secret_id" {
  description = "The ID of the AWS Secrets Manager secret containing credentials (if enabled)"
  value       = module.vdi.secrets_manager_secret_id
}

output "credentials_instructions" {
  description = "Instructions for accessing credentials"
  value       = <<-EOT
    To retrieve the auto-generated credentials from AWS Secrets Manager, run:
    aws secretsmanager get-secret-value --secret-id ${module.vdi.secrets_manager_secret_id} --query 'SecretString' --output text | jq .
  EOT
}
