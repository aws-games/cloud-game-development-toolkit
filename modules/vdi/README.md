# VDI (Virtual Desktop Infrastructure) Module

This Terraform module creates a Virtual Desktop Infrastructure (VDI) setup on AWS using EC2 instances backed by EBS storage.

## Features

- **EC2 Instance**: Configurable instance type with GPU support (default: g4dn.2xlarge)
- **Detailed Monitoring**: Enhanced CloudWatch metrics with 1-minute interval (enabled by default)
- **EBS Storage**: 512GB encrypted root volume with configurable type, plus additional volumes if needed
- **EBS Optimization**: Enhanced storage performance with EBS-optimized instances (enabled by default)
- **Security**: Security group with configurable access rules for RDP and NICE DCV
- **IAM Integration**: IAM role and instance profile with SSM permissions for management
- **Key Pair Management**: Auto-generates a key pair or uses an existing one
- **Password Management**: Securely stores credentials in AWS Secrets Manager

## Usage

```hcl
module "vdi" {
  source = "./modules/vdi"

  # Required Configuration
  name           = "dev-vdi"
  project_prefix = "cgd"
  environment    = "dev"
  vpc_id         = "vpc-12345678"  # Your VPC ID
  subnet_id      = "subnet-12345678"  # Your subnet ID
  admin_password = "SecurePassword123!"  # Required
  
  # Optional Configuration
  instance_type  = "g4dn.2xlarge"
  create_key_pair = true
  store_passwords_in_secrets_manager = true
  allowed_cidr_blocks = ["10.0.0.0/8"]
  
  # Additional EBS volume (optional)
  additional_ebs_volumes = [
    {
      device_name = "/dev/xvdf"
      volume_size = 1000
      volume_type = "gp3"
    }
  ]

  tags = {
    Environment = "dev"
    Project     = "VDI"
  }
}
```

See the `examples/simple` directory for a complete example that includes VPC creation with public and private subnets.

## Required Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| name | Name attached to VDI resources | `string` | yes |
| project_prefix | Project prefix for this workload | `string` | yes |
| vpc_id | ID of the VPC to deploy the VDI instance | `string` | yes |
| subnet_id | Subnet ID to deploy the VDI instance | `string` | yes |
| admin_password | Administrator password for the Windows instance | `string` | yes |

## Key Outputs

| Name | Description |
|------|-------------|
| vdi_instance_id | The ID of the VDI EC2 instance |
| vdi_instance_private_ip | The private IP address of the VDI instance |
| vdi_instance_public_ip | The public IP address of the VDI instance (if assigned) |
| vdi_security_group_id | The ID of the security group associated with the VDI instance |
| secrets_manager_secret_id | The ID of the AWS Secrets Manager secret containing credentials |

## Prerequisites

1. **AMI**: Either provide an AMI ID or allow auto-discovery using the AMI prefix
2. **VPC and Subnet**: You must provide an existing VPC ID and subnet ID
3. **Administrator Password**: Required for Windows instance access

## Remote Access

This module supports two main remote access options:

- **RDP** (Port 3389): Standard Windows remote desktop protocol
- **NICE DCV** (Port 8443): High-performance remote display protocol optimized for GPU workloads

## Administrator Password Setup

This module uses AWS Systems Manager (SSM) Run Command to set the Administrator password instead of user data scripts. This approach is more reliable and resolves issues where user data scripts might fail to set the password correctly.

How it works:
1. The administrator password is securely stored in AWS Secrets Manager
2. The module creates an SSM document with the password setting commands
3. After instance creation, an SSM association references the password from Secrets Manager
4. The password is securely passed to the instance using SSM SecureString parameters
5. Multiple password setting methods are attempted for maximum reliability
6. NICE DCV is configured for proper authentication

This method avoids the timing issues that can occur with user data scripts and ensures the password is set consistently without exposing sensitive information.

## Security Considerations

- **Password Protection**:
  - Passwords are never hardcoded or exposed in clear text
  - Password is stored in AWS Secrets Manager and securely referenced
  - SSM uses SecureString parameters to protect sensitive data
  - IAM permissions restrict access to only the specific required secrets

- **Encryption**:
  - Secrets Manager secrets are encrypted using KMS (can use customer-managed CMK)
  - EBS volumes are encrypted by default
  - All sensitive data transmissions use secure channels

- **Secret Rotation**:
  - Automatic rotation of secrets is available and enabled by default
  - Configurable rotation period (default: 30 days)
  - Uses AWS Serverless Application Repository for reliable rotation

- **Network Security**:
  - Instance can be deployed in private or public subnet based on requirements
  - Customizable security groups limit access to specific CIDR blocks
  - Consider deploying in a private subnet with a bastion host or VPN for production

- **Instance Metadata Security**:
  - IMDSv2 is enforced by default (session token-based requests required)
  - Protects against SSRF vulnerabilities
  - Configurable hop limit prevents metadata service access from containers
  - IMDSv1 (less secure) is disabled
  
- **Monitoring and Observability**:
  - Detailed monitoring enabled by default (1-minute CloudWatch metrics)
  - Enhanced visibility into resource utilization and performance
  - Better alerting capabilities through more frequent metrics

- **Access Control**:
  - Instance is configured with least-privilege IAM permissions
  - Separation of duties between EC2 instance and secrets management
  - Fine-grained control over who can access the VDI instance
