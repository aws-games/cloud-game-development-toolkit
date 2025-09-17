# Local-Only Example

## Overview
Demonstrates VDI deployment with local Windows users and Secrets Manager authentication. No Active Directory complexity.

## Prerequisites
1. AWS credentials configured
2. VPC and subnet for deployment

## Deployment
```bash
terraform init
terraform apply
```

## What Gets Created
- **Local User**: john-doe (Windows local account)
- **VDI Instance**: Single workstation with software packages
- **Authentication**: Secrets Manager with 3 accounts per VDI:
  - Administrator (EC2 key pair - break-glass)
  - VDIAdmin (Secrets Manager - automation)
  - john-doe (Secrets Manager - daily use)

## Connection

### Method 1: Secrets Manager (Recommended)
```bash
# Get secret ARN
SECRET_ARN=$(terraform output -raw secrets_manager | jq -r '."vdi-001".secret_arn')

# Get passwords
aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text | jq
```

### Method 2: EC2 Key Pair (Break-glass)
```bash
# Get private key
terraform output -raw private_keys | jq -r '."vdi-001"' > temp_key.pem
chmod 600 temp_key.pem

# Get Administrator password
INSTANCE_ID=$(terraform output -raw vdi_connection_info | jq -r '."vdi-001".instance_id')
aws ec2 get-password-data --instance-id $INSTANCE_ID --priv-launch-key temp_key.pem
```

### Connect via DCV
1. Get instance IP: `terraform output vdi_connection_info`
2. Open browser: `https://<instance-ip>:8443`
3. Login with retrieved credentials

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.12.0 |

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
