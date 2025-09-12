# Multi-AMI VDI Example

## Overview
Demonstrates VDI deployment with **multiple AMI types** for different user roles:
- **UE GameDev AMI**: Pre-built with Visual Studio 2022 + Epic Games Launcher
- **Lightweight AMI**: Basic Windows for general users
- **Custom AMI Integration**: Shows how to use your own Packer-built AMIs

## Architecture

### Multi-AMI Pattern
```
vdi-001 (john-doe)  → UE GameDev AMI    → g4dn.4xlarge (16 vCPU, 64GB, T4 GPU)
vdi-002 (jane-smith) → Lightweight AMI  → m5.large (2 vCPU, 8GB)
```

### User Management
- **Local Windows users** created via EC2 user data (immediate execution)
- **Secrets Manager** stores all passwords
- **Multi-user support**: Admin users on ALL workstations, standard users on assigned workstation

## Prerequisites

### Required AMIs
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
- **2 VDI instances** with different AMIs and instance types
- **VPC + subnet + security groups** for public internet access
- **S3 buckets** for emergency keys and scripts
- **CloudWatch log groups** for centralized logging

### Users (Created via User Data)
- **vdiadmin**: Administrator account on BOTH instances
- **john-doe**: Standard user on vdi-001 (UE GameDev)
- **jane-smith**: Standard user on vdi-002 (Lightweight)

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

# Example: Get john-doe password
aws secretsmanager get-secret-value --secret-id "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:cgd/vdi-001/users/john-doe-XXXXX" --query SecretString --output text | jq -r '.password'
```

### Connect via DCV
1. **vdi-001 (UE GameDev)**: `https://<vdi-001-ip>:8443`
   - Login: `john-doe` + password from Secrets Manager
   - **Pre-installed**: Visual Studio 2022, Epic Games Launcher, Git, Perforce

2. **vdi-002 (Lightweight)**: `https://<vdi-002-ip>:8443`
   - Login: `jane-smith` + password from Secrets Manager
   - **Basic Windows** with DCV only

### Admin Access
- **vdiadmin** account available on BOTH instances
- Use for system administration and troubleshooting

## Key Features

### ✅ Multi-AMI Support
- Different AMIs for different roles (GameDev vs General)
- Automatic AMI discovery via data sources
- Fallback to AWS base AMI if custom AMIs unavailable

### ✅ Infrastructure-Focused
- **No runtime software installation** (unreliable)
- **Custom AMIs** provide consistent, fast boot times
- **Role-based templates** with appropriate instance types

### ✅ Reliable User Creation
- **EC2 user data** creates users immediately at boot
- **No SSM dependencies** or timing issues
- **Idempotent** user creation with error handling

### ✅ Enterprise-Ready
- **Multi-user support** with proper Windows groups
- **Centralized password management** via Secrets Manager
- **Break-glass access** via EC2 key pairs
- **Audit logging** via CloudWatch

## Troubleshooting

### User Creation Issues
Check user data execution logs:
```bash
# Get console output
aws ec2 get-console-output --instance-id <instance-id> --region us-east-1

# Or RDP to instance and check:
# C:\temp\vdi-setup.log
# C:\temp\vdi-setup-complete.txt
```

### AMI Not Found
If custom AMIs aren't built:
1. Build AMIs using Packer templates
2. Or temporarily use AWS base AMI (will need manual software installation)

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.12.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

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
