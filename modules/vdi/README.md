# VDI (Virtual Desktop Infrastructure) Module

This Terraform module creates a Virtual Desktop Infrastructure (VDI) setup on AWS using [EC2](https://aws.amazon.com/pm/ec2/) instances backed by [EBS](https://aws.amazon.com/ebs/) storage, optimized for game development workstations with GPU support and [Amazon DCV](https://aws.amazon.com/hpc/dcv/) remote access.

## Module Structure

- `main.tf` - Core VDI infrastructure resources (EC2 instances, launch templates, key pairs)
- `variables.tf` - Input variables and configuration options
- `outputs.tf` - Module outputs for instance details and connection info
- `versions.tf` - Provider requirements and versions
- `locals.tf` - Local values and computed configurations
- `data.tf` - Data sources for AMI discovery and IP detection
- `iam.tf` - IAM roles and instance profiles for VDI instances
- `sg.tf` - Security group configurations for RDP and DCV access
- `adjoin.tf` - Active Directory domain joining configuration and SSM documents

## Prerequisites

Before using this module, ensure you have:

1. An [AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) with appropriate permissions
2. [Terraform](https://www.terraform.io/downloads) installed (>= 1.0)
3. [AWS credentials](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html) configured via environment variables, shared credentials file, or IAM roles
4. Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [Directory Service](https://aws.amazon.com/directoryservice/), [EC2](https://aws.amazon.com/ec2/))
5. **Windows AMI**: Build using [Packer template](../assets/packer/virtual-workstations/windows/windows-server-2025.pkr.hcl)
6. Existing VPC and subnets where VDI instances will be deployed

## Getting Started

### Step 1: Basic Configuration

Configure the module with your VPC and user requirements:

```hcl
module "vdi_workstations" {
  source = "./modules/vdi"

  # Basic Configuration
  project_prefix = "cgd"
  environment    = "dev"
  vpc_id         = "vpc-12345678"
  subnets        = ["subnet-12345678", "subnet-87654321"]

  # User Configuration
  vdi_config = {
    john = {
      instance_type     = "g4dn.2xlarge"
      availability_zone = "us-east-1a"
      subnet_id        = "subnet-12345678"
      volumes = {
        Root = { capacity = 256, type = "gp3", iops = 5000 }
        Code = { capacity = 512, type = "gp3" }
      }
      tags = {
        given_name  = "John"
        family_name = "Doe"
        email       = "john.doe@company.com"
      }
    }
  }
}
```

### Step 2: Deploy Infrastructure

From your Terraform directory, run:

```bash
terraform init
terraform plan
terraform apply
```

This will create:
1. Individual EC2 instances with GPU support
2. [Security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) with RDP and DCV access
3. [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) and instance profiles
4. Key pairs for secure access
5. Launch templates with user-specific configuration

The deployment process typically takes 10-15 minutes depending on the number of users and instance types.

## Module Features

### Infrastructure Components

#### EC2 Instances
- **GPU-Enabled Workstations** using [NVIDIA GRID drivers](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-nvidia-driver.html#nvidia-GRID-driver)
- **Configurable Instance Types** with GPU support (default: g4dn.2xlarge)
- **Individual Launch Templates** with user-specific configuration
- **Auto-Discovery AMI** from [Packer template](../assets/packer/virtual-workstations/windows/windows-server-2025.pkr.hcl)

#### Storage and Security
- **EBS Volumes** with GP3 storage and configurable IOPS per user
- **Encryption Support** with optional [KMS key specification](https://aws.amazon.com/kms/)
- **Security Groups** with intelligent CIDR block management for RDP (3389) and DCV (8443)
- **IAM Integration** with SSM permissions for management

#### Networking and Access
- **Flexible Networking** using existing VPC and subnets
- **Public IP Detection** automatically allows user's IP for secure access
- **Amazon DCV** for high-performance remote access [Amazon DCV](https://aws.amazon.com/hpc/dcv/)
- **RDP Support** for standard Windows remote desktop access

#### Active Directory Integration
- **Optional Domain Joining** via [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-managedinstances.html)
- **Auto-Logon Configuration** for seamless DCV experience
- **User Management** with [AWS DS Data API](https://docs.aws.amazon.com/directoryservicedata/latest/DirectoryServiceDataAPIReference/Welcome.html) (when enabled)
- **Group Membership** automatic assignment to required AD groups

### Usage Patterns

#### Basic VDI Setup (Standalone)

```hcl
module "vdi_workstations" {
  source = "./modules/vdi"

  project_prefix = "cgd"
  environment    = "dev"
  vpc_id         = "vpc-12345678"
  subnets        = ["subnet-12345678"]

  vdi_config = {
    developer = {
      instance_type     = "g4dn.2xlarge"
      availability_zone = "us-east-1a"
      subnet_id        = "subnet-12345678"
      volumes = {
        Root = { capacity = 256, type = "gp3", iops = 5000 }
        Code = { capacity = 512, type = "gp3" }
      }
      join_ad = false  # Standalone workstation
    }
  }
}
```

#### Active Directory Integration (Existing Users)

```hcl
module "vdi_workstations" {
  source = "./modules/vdi"

  project_prefix = "cgd"
  environment    = "dev"
  vpc_id         = "vpc-12345678"
  subnets        = ["subnet-12345678", "subnet-87654321"]

  # AD Configuration
  enable_ad_integration = true
  directory_id          = "d-1234567890"
  directory_name        = "corp.example.com"
  dns_ip_addresses      = ["10.0.1.100", "10.0.1.101"]

  vdi_config = {
    john = {
      instance_type     = "g4dn.2xlarge"
      availability_zone = "us-east-1a"
      subnet_id        = "subnet-12345678"
      volumes = {
        Root = { capacity = 256, type = "gp3", iops = 5000 }
        Code = { capacity = 512, type = "gp3" }
      }
      join_ad = true
      tags = {
        given_name  = "John"
        family_name = "Doe"
        email       = "john.doe@company.com"
      }
    }
  }
}
```

### Adding More Users

To add additional users, simply add new blocks to the `vdi_config` map. Each user gets:

- **Individual EC2 instance** with custom specifications
- **Dedicated launch template** with user-specific configuration
- **Individual security groups** (or shared ones based on configuration)
- **Separate key pairs** with standard EC2 password encryption
- **Custom storage volumes** based on user requirements
- **Optional Active Directory** domain joining per user

### Password Retrieval

#### Via AWS CLI
```bash
# Get encrypted password data and decrypt with private key
aws ec2 get-password-data \
  --instance-id i-1234567890abcdef0 \
  --priv-launch-key /path/to/private-key.pem

# Get private key from Terraform output
terraform output -raw private_keys | jq -r '.["username"]'
```

#### Via AWS Console
1. Go to [EC2 Console](https://console.aws.amazon.com/ec2/)
2. Select your VDI instance
3. Actions → Security → Get Windows Password
4. Upload the private key file to decrypt the password

#### Programmatically (PowerShell)
```powershell
# Get instance password using AWS CLI from PowerShell
$instanceId = "i-1234567890abcdef0"
$privateKeyPath = "C:\path\to\private-key.pem"

aws ec2 get-password-data --instance-id $instanceId --priv-launch-key $privateKeyPath
```

## Customization Options

### Infrastructure Customization

The module can be customized by:
- **Storage Configuration**: Adjust volume sizes, types, and IOPS per user
- **Network Security**: Modify CIDR blocks and security group rules
- **AMI Selection**: Use auto-discovery or specify custom AMI IDs
- **Encryption**: Enable EBS encryption with optional KMS keys

## Troubleshooting

### If the Terraform deployment fails:
1. Run `terraform plan` to check for configuration errors
2. Check the Terraform logs for error messages
3. Verify your VPC and subnets have proper internet connectivity
4. Ensure your AWS credentials have sufficient permissions for EC2, VPC, and Directory Service operations
5. Check that the instance types are available in your selected region
6. Verify the Packer AMI exists and is accessible in your account

### Common Issues:
- **AMI Not Found**: Ensure the Packer AMI with prefix `windows-server-2025` exists in your account
- **Instance Launch Failures**: Check subnet capacity and instance type availability
- **Security Group Issues**: Verify CIDR blocks and port configurations
- **Domain Join Problems**: Ensure AD directory is accessible and SSM agent is running
- **Password Retrieval**: Confirm proper IAM permissions for EC2 password operations

### Active Directory Troubleshooting:
```bash
# List all users in the directory
aws ds-data list-users --directory-id d-1234567890

# Get specific user details
aws ds-data describe-user --directory-id d-1234567890 --sam-account-name username

# Check directory status
aws ds describe-directories --directory-ids d-1234567890
```
## License

See the project's main LICENSE file for license information.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.5.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.5 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.vdi_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.vdi_instance_role](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vdi_basic_access](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.vdi_dcv_license_access](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm_directory_service_access](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm_managed_instance_core](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.vdi_instances](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/instance) | resource |
| [aws_key_pair.vdi_key_pairs](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/key_pair) | resource |
| [aws_launch_template.vdi_launch_templates](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/launch_template) | resource |
| [aws_security_group.vdi_default_sg](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/security_group) | resource |
| [aws_ssm_association.configure_dcv_ad_auth](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/ssm_association) | resource |
| [aws_ssm_association.domain_join](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/ssm_association) | resource |
| [aws_ssm_document.configure_dcv_ad_auth](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/ssm_document) | resource |
| [null_resource.create_ad_users](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [tls_private_key.vdi_keys](https://registry.terraform.io/providers/hashicorp/tls/4.0.5/docs/resources/private_key) | resource |
| [aws_ami.windows_server_2025](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/region) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/vpc) | data source |
| [http_http.user_public_ip](https://registry.terraform.io/providers/hashicorp/http/3.4.5/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ad_admin_password"></a> [ad\_admin\_password](#input\_ad\_admin\_password) | Directory administrator password | `string` | `""` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | Default CIDR blocks allowed for VDI access (can be overridden per user) | `list(string)` | <pre>[<br/>  "10.0.0.0/16"<br/>]</pre> | no |
| <a name="input_ami_prefix"></a> [ami\_prefix](#input\_ami\_prefix) | AMI name prefix for auto-discovery when ami not specified per user | `string` | `"windows-server-2025"` | no |
| <a name="input_auto_detect_public_ip"></a> [auto\_detect\_public\_ip](#input\_auto\_detect\_public\_ip) | Automatically detect and allow user's public IP for access | `bool` | `true` | no |
| <a name="input_directory_id"></a> [directory\_id](#input\_directory\_id) | AWS Managed Microsoft AD directory ID (required if enable\_ad\_integration = true) | `string` | `null` | no |
| <a name="input_directory_name"></a> [directory\_name](#input\_directory\_name) | Fully qualified domain name (FQDN) of the directory | `string` | `null` | no |
| <a name="input_directory_ou"></a> [directory\_ou](#input\_directory\_ou) | Organizational unit (OU) in the directory for computer accounts | `string` | `null` | no |
| <a name="input_dns_ip_addresses"></a> [dns\_ip\_addresses](#input\_dns\_ip\_addresses) | DNS IP addresses for the directory | `list(string)` | `[]` | no |
| <a name="input_ebs_encryption_enabled"></a> [ebs\_encryption\_enabled](#input\_ebs\_encryption\_enabled) | Enable EBS encryption for VDI volumes | `bool` | `false` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | KMS key ID for EBS encryption (if encryption enabled) | `string` | `null` | no |
| <a name="input_enable_ad_integration"></a> [enable\_ad\_integration](#input\_enable\_ad\_integration) | Enable Active Directory integration for domain-joined VDI | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_individual_user_passwords"></a> [individual\_user\_passwords](#input\_individual\_user\_passwords) | Map of individual user passwords for AD users (username -> password) | `map(string)` | `{}` | no |
| <a name="input_manage_ad_users"></a> [manage\_ad\_users](#input\_manage\_ad\_users) | Automatically create AD users (vs using existing users) | `bool` | `false` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | Prefix for resource names | `string` | `"cgd"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnet IDs available for VDI instances (fallback if not specified per user) | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags applied to all resources | `map(string)` | <pre>{<br/>  "iac-management": "CGD-Toolkit",<br/>  "iac-module": "VDI",<br/>  "iac-provider": "Terraform"<br/>}</pre> | no |
| <a name="input_vdi_config"></a> [vdi\_config](#input\_vdi\_config) | Configuration for each VDI user workstation | <pre>map(object({<br/>    # Required - Core compute and networking<br/>    instance_type     = string<br/>    availability_zone = string<br/>    subnet_id         = string<br/><br/>    # Required - Storage configuration<br/>    volumes = map(object({<br/>      capacity   = number<br/>      type       = string<br/>      iops       = optional(number, 3000)<br/>      throughput = optional(number, 125)<br/>    }))<br/><br/>    # Optional - Customization<br/>    ami                      = optional(string)<br/>    iam_instance_profile     = optional(string)<br/>    existing_security_groups = optional(list(string), [])<br/>    allowed_cidr_blocks      = optional(list(string), ["10.0.0.0/16"])<br/>    key_pair_name            = optional(string)<br/>    admin_password           = optional(string)<br/>    tags                     = optional(map(string), {})<br/><br/>    # Boolean Choices (3 total)<br/>    join_ad                        = optional(bool, false) # AD integration vs local users<br/>    create_default_security_groups = optional(bool, true)  # Convenience vs existing SGs<br/>    create_key_pair                = optional(bool, true)  # Convenience vs existing keys<br/>  }))</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where VDI instances will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_instance_profile"></a> [iam\_instance\_profile](#output\_iam\_instance\_profile) | The IAM instance profile name |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | Map of VDI instance IDs |
| <a name="output_private_ips"></a> [private\_ips](#output\_private\_ips) | Map of VDI private IP addresses |
| <a name="output_private_keys"></a> [private\_keys](#output\_private\_keys) | Map of private keys for created key pairs (sensitive) |
| <a name="output_public_ips"></a> [public\_ips](#output\_public\_ips) | Map of VDI public IP addresses |
<!-- END_TF_DOCS -->
