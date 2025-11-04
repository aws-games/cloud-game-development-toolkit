# Private Connectivity VDI Example

## Overview
Demonstrates VDI deployment with **private network access** via AWS Client VPN:
- **Private Network Access**: AWS Client VPN with certificate-based authentication
- **Internal DNS**: Custom domain names for easy connection
- **Multi-User VPN**: Each user gets their own .ovpn configuration file
- **Enterprise Security**: No public internet exposure, VPC-only access

## Prerequisites
1. AWS credentials configured
2. VPN client software (AWS VPN Client or OpenVPN)
3. **Custom AMIs built using Packer templates** (required for this example)

**Note**: This example requires specific custom AMIs because the data sources reference them by name. You can customize the example to use different AMIs by modifying `data.tf`.

## Deployment
```bash
terraform init
terraform apply
```

## What Gets Created
- **3 VDI instances** in private subnets (no public IPs)
- **AWS Client VPN endpoint** with certificate-based authentication
- **Private DNS zone** (cgd.vdi.internal) for easy connection
- **VPN certificates** and .ovpn files for each user
- **NAT Gateway** for outbound internet access (Windows updates, software downloads)

## Connection (Private VPN Access)

### Step 1: Download VPN Configuration
```bash
# Get VPN configs bucket
terraform output vpn_configs_bucket

# Download your .ovpn file
# macOS/Linux:
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/naruto-uzumaki/naruto-uzumaki.ovpn ~/Downloads/

# Windows (PowerShell):
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/naruto-uzumaki/naruto-uzumaki.ovpn $env:USERPROFILE\Downloads\

# Windows (Command Prompt):
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/naruto-uzumaki/naruto-uzumaki.ovpn %USERPROFILE%\Downloads\
```

### Step 2: Connect to VPN
1. **AWS VPN Client** (recommended): Import .ovpn file
2. **OpenVPN**: Use .ovpn file with any OpenVPN client
3. **Wait 2-3 minutes** for VPN connection to establish

### Step 3: Get User Passwords
```bash
# Get connection info
terraform output connection_info

# Get user password from Secrets Manager
aws secretsmanager get-secret-value --secret-id "cgd/vdi-001/users/naruto-uzumaki" --query SecretString --output text | jq -r '.password'
```

### Step 4: Connect via DCV (Private DNS)
1. **vdi-001 (UE GameDev)**: `https://naruto-uzumaki.cgd.vdi.internal:8443`
2. **vdi-002 (DevOps)**: `https://sasuke-uchiha.cgd.vdi.internal:8443`
3. **vdi-003 (Junior Dev)**: `https://boruto-uzumaki.cgd.vdi.internal:8443`

**Alternative**: Use private IPs directly if DNS doesn't resolve

## Software Packages
- Chocolatey (package manager)
- Visual Studio 2022 Community
- Git
- Perforce client tools

Check installation progress via CloudWatch logs or SSM status commands in outputs.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.17.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vdi"></a> [vdi](#module\_vdi) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_eip.nat_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.vdi_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.vdi_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.vdi_private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.vdi_public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.vdi_private_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.vdi_public_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.vdi_private_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.vdi_private_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.vdi_public_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vdi_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_egress_rule.vdi_all_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_dcv](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_rdp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.vdi_lightweight_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.vdi_ue_gamedev_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_info"></a> [connection\_info](#output\_connection\_info) | VDI connection information |
<!-- END_TF_DOCS -->
