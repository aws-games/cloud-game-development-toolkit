# VDI (Virtual Desktop Infrastructure) Module

This Terraform module creates a Virtual Desktop Infrastructure (VDI) setup on AWS using EC2 instances backed by EBS storage. The module is designed to work with AMIs created by the `windows-server-2025` Packer template.

## Features

- **EC2 Instance**: Configurable instance type with GPU support (default: g4dn.2xlarge)
- **EBS Storage**: 512GB encrypted root volume with configurable type and performance, plus an additional volume for file storage
- **Security**: Security group with configurable access rules for RDP and NICE DCV
- **IAM Integration**: IAM role and instance profile with SSM permissions for management
- **Launch Template**: Reusable launch template for consistent deployments
- **AMI Options**: Use auto-discovery or provide a custom AMI ID
- **Key Pair Management**: Automatically generates a key pair or uses an existing one
- **Password Management**: Sets a custom or auto-generated password for the administrator account

## Architecture

The module creates:
- An EC2 instance in a specified VPC subnet
- A security group with ingress rules for RDP and NICE DCV remote access
- An IAM role and instance profile for AWS service integration
- A launch template for instance configuration
- 512GB EBS root volume plus an additional volume for file storage, both with encryption support
- Auto-generated key pair and administrator password (optional)

## Usage

This is example for how to use the Terraform file. Uncomment specific configuration lines in your actual Terraform code (not in this README) when you want to use those options:

```hcl
module "vdi" {
  source = "./modules/vdi"

  # General Configuration
  name           = "dev-vdi"
  project_prefix = "cgd"
  environment    = "dev"

  # Networking
  vpc_id    = "vpc-12345678"  # Replace with actual VPC ID
  subnet_id = "subnet-12345678"
  
  # Instance Configuration
  instance_type = "g4dn.2xlarge"
  
  # Key Pair and Password Management
  # Option 1: Generate a key pair and password (default behavior)
  create_key_pair = true
  store_passwords_in_secrets_manager = true
  
  # Option 2: Use existing key pair (uncomment this line and replace with your key pair name)
  # key_pair_name = "my-key-pair"
  
  # Option 3: Provide a custom admin password (uncomment this line and replace with your password)
  # admin_password = "YourSecurePassword123!"
  
  # AMI Selection Options
  # Option 1: Auto-discover AMI from Packer template (default)
  ami_prefix = "windows-server-2025"
  
  # Option 2: Specify a custom AMI ID
  # ami_id = "ami-0123456789abcdef0"
  
  # Storage Configuration (root volume is 512GB by default)
  root_volume_type = "gp3"
  root_volume_iops = 4000
  
  # Security Configuration
  allowed_cidr_blocks = ["10.0.0.0/8"]
  
  # Additional EBS volume for file storage
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

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | 6.5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | 6.5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | The name attached to VDI module resources | `string` | `"vdi"` | no |
| project_prefix | The project prefix for this workload | `string` | `"cgd"` | no |
| environment | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| tags | Tags to apply to resources | `map(any)` | See variables.tf | no |
| vpc_id | The ID of the existing VPC to deploy the VDI instance into | `string` | `"vpc-placeholder-replace-with-actual-vpc-id"` | no |
| subnet_id | The subnet ID to deploy the VDI instance into | `string` | n/a | yes |
| associate_public_ip_address | Whether to associate a public IP address with the VDI instance | `bool` | `false` | no |
| allowed_cidr_blocks | List of CIDR blocks allowed to access the VDI instance | `list(string)` | `["10.0.0.0/8"]` | no |
| key_pair_name | The name of an existing AWS key pair to use | `string` | `null` | no |
| create_key_pair | Whether to create a new key pair if key_pair_name is not provided | `bool` | `true` | no |
| admin_password | The administrator password for the Windows instance | `string` | `null` | no |
| store_passwords_in_secrets_manager | Whether to store generated passwords in AWS Secrets Manager | `bool` | `true` | no |
| create_instance | Whether to create the VDI instance | `bool` | `true` | no |
| instance_type | The EC2 instance type for the VDI instance | `string` | `"g4dn.2xlarge"` | no |
| ami_id | The ID of a specific AMI to use for the VDI instance | `string` | `null` | no |
| ami_prefix | The prefix of the AMI name created by the packer template | `string` | `"windows-server-2025"` | no |
| user_data_base64 | Base64 encoded user data script to run on instance launch | `string` | `null` | no |
| root_volume_size | The size of the root EBS volume in GB | `number` | `512` | no |
| root_volume_type | The type of the root EBS volume | `string` | `"gp3"` | no |
| root_volume_iops | The IOPS for the root EBS volume | `number` | `3000` | no |
| root_volume_throughput | The throughput for the root EBS volume in MB/s | `number` | `125` | no |
| ebs_encryption_enabled | Whether to enable EBS encryption for all volumes | `bool` | `true` | no |
| ebs_kms_key_id | The KMS key ID to use for EBS encryption | `string` | `null` | no |
| additional_ebs_volumes | List of additional EBS volumes to attach to the VDI instance | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| vdi_instance_id | The ID of the VDI EC2 instance |
| vdi_instance_private_ip | The private IP address of the VDI instance |
| vdi_instance_public_ip | The public IP address of the VDI instance (if assigned) |
| vdi_instance_private_dns | The private DNS name of the VDI instance |
| vdi_instance_public_dns | The public DNS name of the VDI instance (if assigned) |
| vdi_security_group_id | The ID of the security group associated with the VDI instance |
| vdi_launch_template_id | The ID of the launch template for the VDI instance |
| vdi_launch_template_latest_version | The latest version of the launch template |
| vdi_iam_role_arn | The ARN of the IAM role associated with the VDI instance |
| vdi_iam_instance_profile_name | The name of the IAM instance profile associated with the VDI instance |
| key_pair_name | The name of the key pair used for the VDI instance |
| secrets_manager_secret_id | The ID of the AWS Secrets Manager secret containing credentials (if enabled) |
| admin_password_set | Indicates if an administrator password was set |
| ami_id | The ID of the AMI used for the VDI instance |
| ami_name | The name of the AMI used for the VDI instance |
| ami_creation_date | The creation date of the AMI used for the VDI instance |
| ami_source | The source of the AMI (custom or auto-discovered) |

## Prerequisites

1. **Packer AMI**: The module expects an AMI created by the `windows-server-2025` Packer template to be available in your AWS account.

2. **VPC and Subnets**: An existing VPC with appropriate subnets must be available. Update the `vpc_id` variable with the actual VPC ID.

3. **Key Pair and Password**:
   - The module can automatically generate a key pair if `create_key_pair` is set to true
   - The module can set a custom admin password or auto-generate one
   - If `store_passwords_in_secrets_manager` is true, credentials are securely stored in AWS Secrets Manager

## Security Considerations

- The module creates a security group with restrictive ingress rules for RDP (3389) and NICE DCV (8443) by default
- EBS encryption is enabled by default
- The instance is configured with an IAM role that has minimal permissions for AWS Systems Manager
- Generated passwords and private keys are securely stored in AWS Secrets Manager
- Consider deploying the instance in a private subnet and using a bastion host or VPN for access

## AMI Options

The module provides two options for selecting the AMI:

### 1. Auto-discovery (Default)

The module uses a data source to automatically discover the most recent AMI created by the Packer template:

```hcl
data "aws_ami" "windows_server_2025_vdi" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
```

This ensures that the module always uses the latest version of your packer AMI, even when the AMI name includes random strings generated during the Packer build process.

### 2. Custom AMI ID

You can specify a custom AMI ID to use a specific AMI instead of relying on auto-discovery:

```hcl
module "vdi" {
  source = "./modules/vdi"
  
  # ... other configuration ...
  
  # Use a specific AMI
  ami_id = "ami-0123456789abcdef0"
}
```

When `ami_id` is provided, it takes precedence over the auto-discovery mechanism. This is useful when:

- You want to use an AMI from a different account or public AMI
- You need to use a specific version of an AMI rather than the latest
- You have custom AMIs not created by the Packer template

## Remote Access Options

This module supports two main remote access options for Windows VDIs:

### RDP (Remote Desktop Protocol)
- Standard Windows remote desktop protocol
- Port: 3389 (TCP)
- Built-in client available on most operating systems

### NICE DCV
- High-performance remote display protocol optimized for GPU workloads
- Port: 8443 (TCP and UDP for QUIC protocol)
- Better performance than RDP for graphics-intensive applications
- Requires NICE DCV client installation on the client device
- Supports streaming 4K resolution at 60 FPS with low latency

## Key Pair and Password Management

This module provides several options for managing key pairs and administrator passwords:

### Auto-generated Key Pair
When `create_key_pair = true` and `key_pair_name = null`:
- Generates a new RSA key pair
- Stores the private key in AWS Secrets Manager (if enabled)

### Custom Key Pair
When `key_pair_name` is specified (by uncommenting and setting the value in your configuration):
- Uses an existing AWS key pair with the specified name

### Administrator Password
- Auto-generates a secure password when `admin_password = null` (default)
- Uses a custom password when `admin_password` is specified (by uncommenting and setting the value in your configuration)
- Sets the password via user data script during instance boot
- Stores the password securely in AWS Secrets Manager (if enabled)

## Accessing Generated Credentials

If `store_passwords_in_secrets_manager = true`, you can retrieve credentials using:

```bash
aws secretsmanager get-secret-value --secret-id <secret-id> --query 'SecretString' --output text | jq .
```

Replace `<secret-id>` with the value of the `secrets_manager_secret_id` output.

## TODO

- [ ] Replace VPC placeholder with actual VPC reference when VPC module is identified
- [ ] Add support for Auto Scaling Groups for multiple VDI instances
- [ ] Add CloudWatch monitoring and alerting?
- [ ] Add backup and snapshot policies?
