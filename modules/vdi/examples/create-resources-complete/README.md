# VDI Example with Managed Microsoft AD

This example demonstrates how to create a complete VDI environment with [AWS Managed Microsoft AD](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/directory_microsoft_ad.html) integration, including sophisticated user management and secrets handling, in a single `terraform apply`.

## File Structure

- `directory.tf` - Managed Microsoft AD configuration
- `dns.tf` - DNS configuration
- `locals.tf` - User data configuration and local values
- `main.tf` - Main Terraform configuration calling the VDI module
- `outputs.tf` - Output values for connection information
- `variables.tf` - Input variables for the example
- `versions.tf` - Provider requirements and versions
- `vpc.tf` - VPC configuration

## Prerequisites

Before using this Terraform configuration, ensure you have:

1. An [AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) with appropriate permissions
2. [Terraform](https://www.terraform.io/downloads) installed on your local machine (>= 1.0)
3. [AWS credentials](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html) configured either via environment variables, shared credentials file, or IAM roles
4. Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [Directory Service](https://aws.amazon.com/directoryservice/), [EC2](https://aws.amazon.com/ec2/))
5. **Windows AMI**: Build using [Packer template](../../../assets/packer/virtual-workstations/windows/windows-server-2025.pkr.hcl) or provide your own.

## Getting Started

### Step 1: Configure Users

User configuration is managed in the `locals.tf` file. Find the "ADD NEW USERS HERE" section and modify as needed.

**Default Users:**
- **TroyWood**: Senior Developer (g4dn.2xlarge)
- **MerleSmith**: Senior Designer (g4dn.4xlarge)
- **LouPierce**: Senior DevOps (g4dn.4xlarge)

**Instance Types and Monthly Costs:**
- **g4dn.xlarge**: ~$200-300 (Basic tasks, managers)
- **g4dn.2xlarge**: ~$400-500 (Development, analysts)
- **g4dn.4xlarge**: ~$800-1000 (Design, DevOps, high performance)
- **g4dn.8xlarge**: ~$1500-2000 (Data science, ML workloads)

### Step 2: Run Terraform

From this directory, run the following commands:

```bash
terraform init
terraform plan
terraform apply
```

This will start the deployment process, which includes:
1. Creating VPC with public and private subnets
2. Setting up Managed Microsoft AD directory
3. Launching VDI instances with GPU support
4. Creating AD users with individual passwords
5. Configuring [DCV](https://aws.amazon.com/hpc/dcv/) sessions and domain joining

The deployment process may take 25-45 minutes depending on the number of users and AWS service provisioning times.

## Infrastructure Details

### VDI Module Configuration

This example creates a complete VDI environment using the VDI module with the following components:

#### Networking Infrastructure
- [**VPC**](https://aws.amazon.com/vpc/) with public and private subnets across multiple AZs
- [**Internet Gateway**](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) for public subnet internet access
- [**NAT Gateway**](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) for private subnet outbound connectivity
- [**Route Tables**](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html) with proper routing configuration
- [**DHCP Options**](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/dhcp_options_set.html) configured for Active Directory integration

#### Active Directory Integration
- **Managed Microsoft AD** [AWS Directory Service](https://aws.amazon.com/directoryservice/)
  - Standard edition with DS Data API enabled
  - Automatic user creation and management
  - Group membership configuration (Domain Users, Remote Desktop Users)
- **Domain Join** via [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-managedinstances.html)
- **DCV Authentication** configured for AD users

#### VDI Instances
- **GPU-Enabled Workstations** using [NVIDIA GRID drivers](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-nvidia-driver.html#nvidia-GRID-driver)
- **NICE DCV** for high-performance remote access [Amazon DCV](https://aws.amazon.com/hpc/dcv/)
- **Individual Security Groups** with comprehensive AD port coverage
- **EBS Volumes** with GP3 storage and configurable IOPS

#### Secrets Management
- [**AWS Secrets Manager**](https://aws.amazon.com/secrets-manager/) integration for secure credential storage
- **Individual Passwords** per user with unique naming
- **Private Keys** for EC2 password decryption
- **Automatic Cleanup** on resource destruction

### User Management

#### Current Users
- **TroyWood**: Senior Developer (g4dn.2xlarge)
- **MerleSmith**: Senior Designer (g4dn.4xlarge)
- **LouPierce**: Senior DevOps (g4dn.4xlarge)

#### Adding New Users

User configuration is managed in the `locals.tf` file. Find the "ADD NEW USERS HERE" section and copy the template:

```hcl
NewUser = {
  given_name    = "First"
  family_name   = "Last"
  email         = "first.last@company.com"
  role          = "Job Title"
  instance_type = "g4dn.2xlarge"  # See cost guide above
  volumes = {
    Root = { capacity = 256, type = "gp3", iops = 5000 }
    Data = { capacity = 512, type = "gp3" }
  }
}
```

#### What Happens Automatically
Each new user gets:
- **VDI Instance**: Created with specified instance type and storage
- **AD User Account**: Created in Active Directory with proper attributes
- **Individual Password**: Auto-generated and stored in Secrets Manager
- **Private Key**: Generated and stored for password decryption
- **DCV Session**: User-specific session configured for AD authentication
- **Domain Join**: Instance automatically joins the AD domain
- **Auto-Logon**: Configured for seamless Windows login experience

### Password Retrieval

#### Via AWS CLI
```bash
# Get AD admin password
aws secretsmanager get-secret-value \
  --secret-id cgd-vdi-example-ad-admin-password-* \
  --query SecretString --output text | jq -r '.password'

# Get individual user password
aws secretsmanager get-secret-value \
  --secret-id cgd-vdi-example-ad-user-USERNAME-password-* \
  --query SecretString --output text | jq -r '.password'

# Get private key for Windows password decryption
aws secretsmanager get-secret-value \
  --secret-id cgd-vdi-example-vdi-private-key-USERNAME-* \
  --query SecretString --output text | jq -r '.private_key_pem'
```

#### Via AWS Console
1. Go to [AWS Secrets Manager](https://console.aws.amazon.com/secretsmanager/)
2. Find the secret named `cgd-vdi-example-ad-user-{username}-password-{suffix}`
3. Click "Retrieve secret value"
4. Look for the `password` field

#### Programmatically (PowerShell)
```powershell
# From within the instance or with appropriate AWS credentials
$username = "troywood"
$region = "us-east-1"

$secretName = (aws secretsmanager list-secrets --region $region --query "SecretList[?contains(Name, 'cgd-vdi-example-ad-user-$username-password')].Name" --output text)
$secret = aws secretsmanager get-secret-value --region $region --secret-id $secretName --query SecretString --output text | ConvertFrom-Json
$password = $secret.password
```

## Customization Options

### Infrastructure Customization

The deployment can be customized by:
- Modifying instance types for different performance needs
- Adjusting storage volumes and IOPS per user requirements
- Changing VPC CIDR blocks and subnet configurations
- Modifying security group rules and allowed CIDR blocks
- Disabling AD integration for specific users by setting `join_ad = false`

## Troubleshooting

### If the Terraform deployment fails:
1. Run `terraform plan` to check for configuration errors
2. Check the Terraform logs for error messages
3. Verify your VPC and subnets have proper internet connectivity
4. Ensure your AWS credentials have sufficient permissions for Directory Service, EC2, and VPC operations
5. Check that the instance types are available in your selected region
6. Verify the Packer AMI exists and is accessible in your account

### Common Issues:
- **Directory Creation**: Ensure private subnets are in different availability zones
- **User Creation**: Verify DS Data API is enabled and accessible
- **Domain Join**: Check security group rules allow AD traffic (ports 53, 88, 389, 445, etc.)
- **DCV Connection**: Verify security groups allow DCV traffic (port 8443 TCP/UDP)
- **Password Retrieval**: Ensure proper IAM permissions for Secrets Manager access

## License

See the project's main LICENSE file for license information.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vdi"></a> [vdi](#module\_vdi) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_directory_service_directory.managed_ad](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/directory_service_directory) | resource |
| [aws_eip.vdi_nat_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.vdi_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.vdi_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route53_record.vdi_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route_table.vdi_private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.vdi_public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.vdi_private_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.vdi_public_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_secretsmanager_secret.vdi_admin_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.vdi_user_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.vdi_admin_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.vdi_user_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.managed_ad_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.vdi_private_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.vdi_public_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vdi_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_dhcp_options.managed_ad_dhcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options) | resource |
| [aws_vpc_dhcp_options_association.managed_ad_dhcp_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association) | resource |
| [null_resource.enable_ds_data_access](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.validate_directory_name](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.deployment_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.ad_admin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.ad_user_passwords](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.wait_for_directory_ready](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region to deploy resources in | `string` | `"us-east-1"` | no |
| <a name="input_directory_admin_password"></a> [directory\_admin\_password](#input\_directory\_admin\_password) | Optional: Manually specify AD administrator password. If not provided, a secure random password will be generated automatically. | `string` | `null` | no |
| <a name="input_directory_admin_password_secret_name"></a> [directory\_admin\_password\_secret\_name](#input\_directory\_admin\_password\_secret\_name) | Name of the AWS Secrets Manager secret that will store the auto-generated AD administrator password | `string` | `null` | no |
| <a name="input_directory_edition"></a> [directory\_edition](#input\_directory\_edition) | The edition of the Managed Microsoft AD directory (Standard or Enterprise) | `string` | `"Standard"` | no |
| <a name="input_directory_name"></a> [directory\_name](#input\_directory\_name) | Name of AWS Directory Service AD domain. Used as the domain name for Managed Microsoft AD. | `string` | `"corp.joshral.people.aws.dev"` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Optional: Domain name for DNS record (e.g., example.com). If provided, creates vdi.example.com record. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The EC2 instance type for the VDI instance | `string` | `"g4dn.2xlarge"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to VDI module resources | `string` | `"vdi-example"` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | List of CIDR blocks for private subnets (used for Managed AD) | `list(string)` | <pre>[<br>  "10.0.1.0/24",<br>  "10.0.2.0/24"<br>]</pre> | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload | `string` | `"cgd"` | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | List of CIDR blocks for public subnets | `list(string)` | <pre>[<br>  "10.0.101.0/24",<br>  "10.0.102.0/24"<br>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(any)` | <pre>{<br>  "iac-management": "CGD-Toolkit",<br>  "iac-module": "VDI",<br>  "iac-provider": "Terraform"<br>}</pre> | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | The CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_commands"></a> [access\_commands](#output\_access\_commands) | Commands to retrieve credentials and access VDI |
| <a name="output_directory_info"></a> [directory\_info](#output\_directory\_info) | Active Directory connection information |
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Consolidated secrets for VDI access |
| <a name="output_vdi_instances"></a> [vdi\_instances](#output\_vdi\_instances) | VDI instance connection information |
<!-- END_TF_DOCS -->
