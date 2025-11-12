# Public Connectivity VDI Example

## Overview
Demonstrates VDI deployment with **public internet access** and **multiple AMI types** for different user roles:
- **Public Internet Access**: Direct connection via Internet Gateway with IP restrictions
- **UE GameDev AMI**: Pre-built with Visual Studio 2022 + Epic Games Launcher
- **Lightweight AMI**: Basic Windows for runtime software installation
- **Multi-User Support**: Different workstation configurations for different roles

## Architecture

### Public Connectivity + Multi-AMI Pattern
```
vdi-001 (naruto-uzumaki)  → UE GameDev AMI    → g4dn.4xlarge (Game Developer)
vdi-002 (sasuke-uchiha)   → Lightweight AMI   → g4dn.xlarge  (DevOps Engineer)
vdi-003 (boruto-uzumaki)  → Lightweight AMI   → g4dn.xlarge  (Junior Developer)
                    ↓
            Public Internet Access
         (Your IP: Security Group Rules)
```

### User Management
- **Local Windows users** created via EC2 user data (immediate execution)
- **Secrets Manager** stores all passwords
- **Multi-user support**: Admin users on ALL workstations, standard users on assigned workstation

## Prerequisites

### Required AMIs
**Note**: This example requires specific custom AMIs because the data sources reference them by name. You can customize the example to use different AMIs by modifying `data.tf`.

Build custom AMIs using Packer templates:

```bash
# Build UE GameDev AMI (45-60 minutes)
cd ../../../../assets/packer/virtual-workstations/ue-gamedev/
packer build windows-server-2025-ue-gamedev.pkr.hcl

# Build Lightweight AMI (20-30 minutes)
cd ../lightweight/
packer build windows-server-2025-lightweight.pkr.hcl
```

### AWS Setup
1. AWS credentials configured
2. Custom AMIs built and available
3. VPC with public subnet

## Deployment

```bash
terraform init
terraform apply
```

## What Gets Created

### Infrastructure
- **3 VDI instances** with different AMIs and configurations
- **VPC + subnet + security groups** for public internet access
- **Internet Gateway** for direct public connectivity
- **S3 buckets** for emergency keys and scripts
- **CloudWatch log groups** for centralized logging

### Users (Created via SSM)
- **vdiadmin**: Fleet administrator account on ALL instances
- **naruto-uzumaki**: Administrator on vdi-001 (UE GameDev workstation)
- **sasuke-uchiha**: Administrator on vdi-002 (DevOps workstation)
- **boruto-uzumaki**: Standard user on vdi-003 (Junior developer workstation)

**Status Tracking**: User creation status tracked in SSM Parameter Store at `/{project}/{workstation}/users/{username}/status_*`

### Authentication
- **Secrets Manager**: All user passwords stored securely
- **EC2 Key Pairs**: Emergency break-glass access
- **DCV Sessions**: Created automatically for assigned users

## Connection

### Get Connection Info
```bash
terraform output connection_info
```

### Get Passwords
```bash
# Get all password retrieval commands
terraform output password_retrieval_commands

# Example: Get naruto-uzumaki password
aws secretsmanager get-secret-value --secret-id "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:cgd/vdi-001/users/naruto-uzumaki-XXXXX" --query SecretString --output text | jq -r '.password'
```

### Connect via DCV (Public Internet)
1. **vdi-001 (UE GameDev)**: `https://<vdi-001-ip>:8443`
   - Login: `naruto-uzumaki` + password from Secrets Manager
   - **Pre-installed**: Visual Studio 2022, Epic Games Launcher, Git, Perforce

2. **vdi-002 (DevOps)**: `https://<vdi-002-ip>:8443`
   - Login: `sasuke-uchiha` + password from Secrets Manager
   - **Runtime installed**: VS Code, Terraform, Docker, Kubernetes CLI

3. **vdi-003 (Junior Dev)**: `https://<vdi-003-ip>:8443`
   - Login: `boruto-uzumaki` + password from Secrets Manager
   - **Basic tools**: VS Code, Git, Notepad++

### Admin Access
- **vdiadmin** account available on BOTH instances
- Use for system administration and troubleshooting

## Key Features

### ✅ Public Internet Connectivity
- **Direct access** via Internet Gateway (no VPN required)
- **IP-based security** with automatic detection of your public IP
- **Cost-effective** for individual developers and small teams
- **Simple setup** - no certificate management or VPN clients

### ✅ Multi-AMI Support
- Different AMIs for different roles (GameDev vs General)
- Automatic AMI discovery via data sources
- **Requires custom AMIs** - build using Packer templates

### ✅ Infrastructure-Focused
- **No runtime software installation** (unreliable)
- **Custom AMIs** provide consistent, fast boot times
- **Role-based templates** with appropriate instance types

### ✅ Reliable User Creation
- **SSM associations** create users with proper timing
- **Status tracking** via SSM Parameter Store
- **Force retry** capability with `force_run_provisioning = "true"`
- **Idempotent** user creation with error handling
- **Simplified passwords** (letters and numbers only)

### ✅ Enterprise-Ready
- **Multi-user support** with proper Windows groups
- **Centralized password management** via Secrets Manager
- **Break-glass access** via EC2 key pairs
- **Audit logging** via CloudWatch
- **ODCR support** for cost optimization with capacity reservations

## Troubleshooting

### User Creation Issues
Check SSM command execution and status:
```bash
# Check SSM command status
aws ssm list-command-invocations --instance-id <instance-id>

# Check user creation status
aws ssm get-parameter --name "/cgd/vdi-001/users/naruto-uzumaki/status_user_creation"

# Force retry user creation
# Set force_run_provisioning = "true" in main.tf and apply
```

### AMI Not Found
If custom AMIs aren't built, Terraform will fail with data source error:
1. **Required**: Build AMIs using Packer templates (see Prerequisites)
2. **No fallback**: Data sources require specific AMI names to exist

### DCV Connection Issues
1. Check security group allows port 8443 from your IP
2. Verify DCV service is running on instance
3. Confirm user was created successfully

## Migration from Software Packages

**BREAKING CHANGE**: Software installation logic removed in favor of custom AMIs.

**Before**: Runtime software installation via SSM
**After**: Pre-built AMIs with software included

**Benefits**:
- ✅ Faster boot times (no installation delays)
- ✅ Reliable deployments (no installation failures)
- ✅ Consistent environments (known software versions)
- ✅ Better user experience (workstations ready immediately)

**Migration Path**:
1. Build custom AMIs with required software
2. Update templates to reference custom AMI IDs
3. Remove software_packages variables from configuration

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
<<<<<<< HEAD
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.0.0 |
=======
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.15.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
>>>>>>> origin/main

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vdi"></a> [vdi](#module\_vdi) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_internet_gateway.vdi_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route_table.vdi_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.vdi_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.vdi_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.vdi_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vdi_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_egress_rule.vdi_all_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_dcv](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_rdp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.vdi_lightweight_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.vdi_ue_gamedev_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_info"></a> [connection\_info](#output\_connection\_info) | VDI connection information |
<!-- END_TF_DOCS -->
