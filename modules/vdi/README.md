# VDI (Virtual Desktop Infrastructure) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **ℹ️ Prerequisites**: You need a Windows Server AMI. The examples use Packer-built AMIs from this repo's [Packer templates](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/assets/packer/virtual-workstations) (`lightweight/` and `ue-gamedev/`), but any Windows Server 2019/2022/2025 AMI works. See [Amazon DCV Documentation](https://docs.aws.amazon.com/dcv/) for complete setup guidance.

## Features

- **Complete VDI Infrastructure** - EC2 workstations, security, IAM, and user management
- **Flexible Authentication** - EC2 key pairs (emergency) and Secrets Manager (managed)
- **Security by Default** - Least privilege IAM, encrypted storage, restricted access
- **Dual Connectivity** - Public internet or private VPN access
- **Game Development Ready** - GPU instances, high-performance storage
- **Runtime Software Installation** - Automated via SSM
- **Amazon DCV Integration** - High-performance remote desktop

## Connectivity Patterns

### Public Connectivity
**When**: Workstations in public subnets with Internet Gateway routes
**Access**: Direct internet with IP restrictions

```hcl
workstations = {
  "vdi-001" = {
    preset_key = "my-preset"
    assigned_user = "naruto-uzumaki"
    subnet_id = aws_subnet.public_subnet.id
    allowed_cidr_blocks = ["198.51.100.1/32"]  # Replace with user's public IP
  }
}
```

### Private Connectivity
**When**: Workstations in private subnets with NAT Gateway routes
**Access**: Via VPN, Direct Connect, or Site-to-Site VPN

```hcl
module "vdi" {
  create_client_vpn = true  # Creates Client VPN infrastructure

  users = {
    "naruto-uzumaki" = {
      given_name = "Naruto"
      family_name = "Uzumaki"
      email = "naruto@example.com"
      type = "administrator"
      use_client_vpn = true  # Gets VPN access + certificates
    }
  }

  workstations = {
    "vdi-001" = {
      preset_key = "my-preset"
      assigned_user = "naruto-uzumaki"
      subnet_id = aws_subnet.private_subnet.id
      allowed_cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR only
    }
  }
}
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Remote User   │    │   VPN Client     │    │  VDI Workstation│
│  Web Browser    │───▶│  (Private Mode)  │───▶│   EC2 Instance  │
│                 │    │   .ovpn file     │    │   Windows + DCV │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │ (Public Mode)         │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │         AWS VPC           │
                    │  Security Groups, IAM,    │
                    │  SSM, S3, Secrets Mgr     │
                    └───────────────────────────┘
```

### Account Creation Pattern

| Account Type | Created When | Password Storage | Scope | Use Case |
|-------------|--------------|------------------|-------|----------|
| 🆘 **Administrator** (built-in) | Windows boot | EC2 Key Pair | All workstations | Emergency break-glass only |
| 🛡️ **Fleet Admin** (`fleet_administrator`) | SSM (if defined) | Secrets Manager | All workstations | Fleet management |
| 🔧 **Local Admin** (`administrator`) | SSM (if defined) | Secrets Manager | Assigned workstation | Local administration |
| 💻 **Standard User** (`user`) | SSM (if defined) | Secrets Manager | Assigned workstation | Daily usage |

**Key Point**: Only the built-in Administrator exists automatically. All other accounts must be explicitly defined in the `users` variable.

## Prerequisites

1. **AWS Account Setup**
   - AWS CLI configured with deployment permissions
   - VPC with public and private subnets
   - Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [EC2](https://aws.amazon.com/ec2/))

2. **Network Planning**
   - **Public connectivity**: User public IP addresses for security group access
   - **Private connectivity**: VPN setup and VPC CIDR planning

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples). They provide complete Terraform configuration with VPC setup, security groups, and detailed connection instructions.

**Available Examples:**
- **[Public Connectivity](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples/public-connectivity)** - Direct internet access with IP restrictions
- **[Private Connectivity](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples/private-connectivity)** - AWS Client VPN with internal DNS

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/aws-games/cloud-game-development-toolkit.git
cd cloud-game-development-toolkit
```

### 2. Choose AMI
**Option A**: Use any Windows Server AMI
**Option B**: Build UE GameDev AMI for game development:
```bash
cd assets/packer/virtual-workstations/ue-gamedev/
packer build windows-server-2025-ue-gamedev.pkr.hcl
```

### 3. Deploy Example
```bash
cd modules/vdi/examples/public-connectivity/  # or private-connectivity/
terraform init
terraform plan
terraform apply
```

### 4. Get Connection Info
```bash
terraform output connection_info
```

### 5. Connect (Private Only)
For private connectivity, download VPN config:
```bash
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/your-username/your-username.ovpn ~/Downloads/
# Connect with AWS VPN Client or OpenVPN
```

## Connection Guide

### Get Credentials
```bash
# Get connection info
terraform output connection_info

# Get user password from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id "cgd/vdi-001/users/your-username" \
  --query SecretString --output text | jq .
```

### Connect via DCV
1. **Download [DCV Client](https://download.nice-dcv.com/)** (recommended) or use web browser
2. **Connect to VPN** (private connectivity only)
3. **Open DCV**: `https://workstation-ip:8443` or `https://username.vdi.internal:8443`
4. **Accept certificate warning** (self-signed certificates)
5. **Login** with credentials from Secrets Manager

### Emergency Access
```bash
# Get Administrator password
terraform output -json private_keys | jq -r '."vdi-001"' > temp_key.pem
chmod 600 temp_key.pem
aws ec2 get-password-data \
  --instance-id $(terraform output -json connection_info | jq -r '."vdi-001".instance_id') \
  --priv-launch-key temp_key.pem --query 'PasswordData' --output text
rm temp_key.pem
```

## Advanced Configuration

### On-Demand Capacity Reservations (ODCR)
Optimize costs by leveraging existing capacity reservations:

```hcl
# Module-level default (applies to all workstations)
module "vdi" {
  capacity_reservation_preference = "open"  # Use ODCR if available

  workstations = {
    "ws1" = { subnet_id = "subnet-123" }  # Inherits "open"
    "ws2" = { subnet_id = "subnet-456" }  # Inherits "open"
  }
}

# Per-workstation control
workstations = {
  "prod-ws" = {
    capacity_reservation_preference = "open"  # Use ODCR
    subnet_id = "subnet-123"
  }
  "dev-ws" = {
    capacity_reservation_preference = "none"  # Regular On-Demand
    subnet_id = "subnet-456"
  }
}
```

**Options:**

- `"open"`: Use ODCR if available, fall back to On-Demand
- `"none"`: Never use ODCR, always On-Demand
- `null`: Default AWS behavior (no capacity reservation)

### Software Installation
**Available packages**: Any valid [Chocolatey package](https://community.chocolatey.org/packages). Common examples: `git`, `vscode`, `notepadplusplus`, `7zip`

```hcl
presets = {
  "ue-dev" = {
    instance_type = "g4dn.2xlarge"
    software_packages = ["git", "vscode", "notepadplusplus"]
  }
}
```

### AMI Building
```bash
# Lightweight AMI (20-30 minutes)
cd assets/packer/virtual-workstations/windows/lightweight/
packer build windows-server-2025-lightweight.pkr.hcl

# UE GameDev AMI (45-60 minutes) - includes Visual Studio, Epic Games Launcher
cd assets/packer/virtual-workstations/ue-gamedev/
packer build windows-server-2025-ue-gamedev.pkr.hcl
```

## Troubleshooting

### Common Issues

**Instance Launch Failures**
- Verify AMI exists: `aws ec2 describe-images --owners self --filters "Name=name,Values=*windows-server-2025*"`
- Check AMI is in correct region
- Ensure Packer build completed successfully

**Connection Timeouts**
- Check security group allows your IP: `curl https://checkip.amazonaws.com/`
- Verify instance is running: `aws ec2 describe-instances`
- Test port connectivity: `telnet <instance-ip> 8443`

**Password Retrieval Issues**
- Wait 5-10 minutes after instance launch for password generation
- Use S3 backup key if Terraform output fails

**DCV "Connecting" Spinner**
- Connect via SSM: `aws ssm start-session --target <instance-id>`
- Check DCV sessions: `dcv list-sessions`
- Restart DCV service: `Restart-Service dcvserver`

**VPN Connection Issues**
- Check VPN endpoint DNS resolves: `nslookup [endpoint].prod.clientvpn.us-east-1.amazonaws.com`
- Wait 5-15 minutes for AWS to activate endpoint
- Check for CIDR conflicts with local network
- Disconnect from other VPNs

**User Accounts Not Created**
- Check SSM command status: `aws ssm list-command-invocations --instance-id <id>`
- Retry user creation: `aws ssm send-command --document-name "setup-dcv-users-sessions"`

### Debug Commands
```bash
# Basic connectivity
curl https://checkip.amazonaws.com/
telnet <instance-ip> 8443

# SSM access (no network needed)
aws ssm start-session --target <instance-id>

# VPN testing
ping naruto-uzumaki.vdi.internal
nslookup naruto-uzumaki.vdi.internal
```

### Password Retrieval
```bash
# Administrator password
terraform output -json private_keys | jq -r '."vdi-001"' > temp_key.pem
aws ec2 get-password-data --instance-id <id> --priv-launch-key temp_key.pem

# User passwords
aws secretsmanager get-secret-value --secret-id "cgd/users/naruto-uzumaki"
```
## Known Limitations

- **EC2 Emergency Keys**: Recreated instances overwrite old keys in S3 - previous keys are lost
- **VDIAdmin Secrets**: Managed by SSM, not Terraform - orphaned secrets accumulate over time
- **Resource Lifecycle**: Inconsistent cleanup between Terraform-managed and SSM-managed resources

**Workarounds**: Enable S3 versioning, manually clean up secrets, use SSM Session Manager for emergency access

## Contributing

See the [Contributing Guidelines](../../CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../../../LICENSE) file for details.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.14.1 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.57.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.client_vpn_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.client_vpn_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_cloudwatch_log_group.client_vpn_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.vdi_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.client_vpn_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_ec2_client_vpn_authorization_rule.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_authorization_rule) | resource |
| [aws_ec2_client_vpn_endpoint.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint) | resource |
| [aws_ec2_client_vpn_network_association.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_network_association) | resource |
| [aws_eip.workstation_eips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_instance_profile.vdi_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.vdi_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vdi_instance_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.vdi_cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.vdi_ssm_managed_instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.workstations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_key_pair.workstation_keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_route53_record.user_dns_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone.vdi_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_s3_bucket.keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.scripts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.vpn_configs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.scripts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.vpn_configs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.scripts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.scripts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.emergency_private_keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.user_ca_certificates](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.user_certificates](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.user_private_keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.vpn_client_configs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.workstation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_association.software_installation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_association.vdi_user_creation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.create_vdi_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_ssm_document.install_software](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_security_group_egress_rule.all_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.dcv_https_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.dcv_quic_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.rdp_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.rdp_access_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [awscc_secretsmanager_secret.user_passwords](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.wait_for_ssm_agent](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [tls_cert_request.client_vpn_server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_cert_request.client_vpn_users](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.client_vpn_server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_locally_signed_cert.client_vpn_users](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.client_vpn_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.client_vpn_server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.client_vpn_users](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.workstation_keys](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.client_vpn_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_iam_policy_document.vdi_instance_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_subnet.workstation_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_capacity_reservation_preference"></a> [capacity\_reservation\_preference](#input\_capacity\_reservation\_preference) | Capacity reservation preference for EC2 instances | `string` | `null` | no |
| <a name="input_client_vpn_config"></a> [client\_vpn\_config](#input\_client\_vpn\_config) | Client VPN configuration for private connectivity | <pre>object({<br/>    client_cidr_block       = optional(string, "192.168.0.0/16")<br/>    generate_client_configs = optional(bool, true)<br/>    split_tunnel            = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_create_client_vpn"></a> [create\_client\_vpn](#input\_create\_client\_vpn) | Create AWS Client VPN endpoint infrastructure (VPN endpoint, certificates, S3 bucket for configs) | `bool` | `false` | no |
| <a name="input_create_default_security_groups"></a> [create\_default\_security\_groups](#input\_create\_default\_security\_groups) | Create default security groups for VDI workstations | `bool` | `true` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | KMS key ID for EBS encryption (if encryption enabled) | `string` | `null` | no |
| <a name="input_enable_centralized_logging"></a> [enable\_centralized\_logging](#input\_enable\_centralized\_logging) | Enable centralized logging with CloudWatch log groups following CGD Toolkit patterns | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `30` | no |
| <a name="input_presets"></a> [presets](#input\_presets) | Configuration blueprints defining instance types and named volumes with Windows drive mapping.<br/><br/>**KEY BECOMES PRESET NAME**: The map key (e.g., "ue-developer") becomes the preset name referenced by workstations.<br/><br/>Presets provide reusable configurations that can be referenced by multiple workstations via preset\_key.<br/><br/>Example:<br/>presets = {<br/>  "ue-developer" = {           # ← This key becomes the preset name<br/>    instance\_type = "g4dn.2xlarge"<br/>    gpu\_enabled   = true<br/>    volumes = {<br/>      Root = { capacity = 256, type = "gp3", windows\_drive = "C:" }<br/>      Projects = { capacity = 1024, type = "gp3", windows\_drive = "D:" }<br/>    }<br/>  }<br/>  "basic-workstation" = {      # ← Another preset name<br/>    instance\_type = "g4dn.xlarge"<br/>    gpu\_enabled   = true<br/>  }<br/>}<br/><br/># Referenced by workstations:<br/>workstations = {<br/>  "alice-ws" = {<br/>    preset\_key = "ue-developer"      # ← References preset by key<br/>  }<br/>}<br/><br/>Valid volume types: "gp2", "gp3", "io1", "io2"<br/>Windows drives: "C:", "D:", "E:", etc. | <pre>map(object({<br/>    # Core compute configuration<br/>    instance_type = string<br/>    ami           = optional(string, null)<br/><br/>    # Hardware configuration<br/>    gpu_enabled = optional(bool, true)<br/><br/>    # Named volumes with Windows drive mapping<br/>    volumes = map(object({<br/>      capacity      = number<br/>      type          = string<br/>      windows_drive = string<br/>      iops          = optional(number, 3000)<br/>      throughput    = optional(number, 125)<br/>      encrypted     = optional(bool, true)<br/>    }))<br/><br/>    # Optional configuration<br/>    iam_instance_profile = optional(string, null)<br/>    software_packages    = optional(list(string), null)<br/>    tags                 = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | Prefix for resource names | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "terraform-aws-vdi",<br/>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi",<br/>  "RootModuleName": "-"<br/>}</pre> | no |
| <a name="input_users"></a> [users](#input\_users) | Local Windows user accounts with Windows group types and network connectivity (managed via Secrets Manager)<br/><br/>**KEY BECOMES WINDOWS USERNAME**: The map key (e.g., "john-doe") becomes the actual Windows username created on VDI instances.<br/><br/>type options (Windows groups):<br/>- "fleet\_administrator": User added to Windows Administrators group, created on ALL workstations (fleet management)<br/>- "administrator": User added to Windows Administrators group, created only on assigned workstation<br/>- "user": User added to Windows Users group, created only on assigned workstation<br/><br/>use\_client\_vpn options (VPN access):<br/>- false: User accesses VDI via public internet or external VPN (default)<br/>- true: User accesses VDI via module's Client VPN (generates VPN config)<br/><br/>Example:<br/>users = {<br/>  "vdiadmin" = {              # ← This key becomes Windows username "vdiadmin"<br/>    given\_name = "VDI"<br/>    family\_name = "Administrator"<br/>    email = "admin@company.com"<br/>    type = "fleet\_administrator" # Windows Administrators group on ALL workstations<br/>  }<br/>  "naruto-uzumaki" = {         # ← This key becomes Windows username "naruto-uzumaki"<br/>    given\_name = "Naruto"<br/>    family\_name = "Uzumaki"<br/>    email = "naruto@konoha.com"<br/>    type = "user"               # Windows Users group<br/>  }<br/>}<br/><br/># User assignment is now direct:<br/># assigned\_user = "naruto-uzumaki"  # References users{} key directly in workstation | <pre>map(object({<br/>    given_name     = string<br/>    family_name    = string<br/>    email          = string<br/>    type           = optional(string, "user") # "administrator" or "user" (Windows group)<br/>    use_client_vpn = optional(bool, false)    # Whether this user connects via module's Client VPN<br/>    tags           = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where VDI instances will be deployed | `string` | n/a | yes |
| <a name="input_workstations"></a> [workstations](#input\_workstations) | Physical infrastructure instances with template references and placement configuration.<br/><br/>**KEY BECOMES WORKSTATION NAME**: The map key (e.g., "alice-workstation") becomes the workstation identifier used throughout the module.<br/><br/>Workstations inherit configuration from templates via preset\_key reference.<br/><br/>Example:<br/>workstations = {<br/>  "alice-workstation" = {        # ← This key becomes the workstation name<br/>    preset\_key = "ue-developer"    # ← References templates{} key<br/>    subnet\_id = "subnet-123"<br/>    availability\_zone = "us-east-1a"<br/>    security\_groups = ["sg-456"]<br/>    assigned\_user = "alice"  # User assigned to this workstation<br/>    allowed\_cidr\_blocks = ["203.0.113.1/32"]<br/>  }<br/>  "vdi-001" = {                  # ← Another workstation name<br/>    preset\_key = "basic-workstation"<br/>    subnet\_id = "subnet-456"<br/>  }<br/>}<br/><br/># User assignment is now direct:<br/># assigned\_user = "alice"  # References users{} key directly in workstation | <pre>map(object({<br/>    # Preset reference (optional - can use direct config instead)<br/>    preset_key = optional(string, null)<br/><br/>    # Infrastructure placement<br/>    subnet_id       = string<br/>    security_groups = list(string)<br/>    assigned_user   = optional(string, null) # User assigned to this workstation (for administrator/user types only)<br/><br/>    # Direct configuration (used when preset_key is null or as overrides)<br/>    ami           = optional(string, null)<br/>    instance_type = optional(string, null)<br/>    gpu_enabled   = optional(bool, null)<br/>    volumes = optional(map(object({<br/>      capacity      = number<br/>      type          = string<br/>      windows_drive = string<br/>      iops          = optional(number, 3000)<br/>      throughput    = optional(number, 125)<br/>      encrypted     = optional(bool, true)<br/>    })), null)<br/>    iam_instance_profile = optional(string, null)<br/>    software_packages    = optional(list(string), null)<br/><br/>    # Optional overrides<br/>    allowed_cidr_blocks             = optional(list(string), null)<br/>    capacity_reservation_preference = optional(string, null)<br/>    tags                            = optional(map(string), null)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | AMI ID used for workstations |
| <a name="output_connection_info"></a> [connection\_info](#output\_connection\_info) | Complete connection information for VDI workstations |
| <a name="output_emergency_key_paths"></a> [emergency\_key\_paths](#output\_emergency\_key\_paths) | S3 paths for emergency private keys |
| <a name="output_private_keys"></a> [private\_keys](#output\_private\_keys) | Private keys for emergency access (sensitive) |
| <a name="output_private_zone_id"></a> [private\_zone\_id](#output\_private\_zone\_id) | Private hosted zone ID for creating additional VPC associations |
| <a name="output_private_zone_name"></a> [private\_zone\_name](#output\_private\_zone\_name) | Private hosted zone name |
| <a name="output_public_ips"></a> [public\_ips](#output\_public\_ips) | Map of workstation public IP addresses |
| <a name="output_vpn_configs_bucket"></a> [vpn\_configs\_bucket](#output\_vpn\_configs\_bucket) | S3 bucket name for VPN configuration files |
<!-- END_TF_DOCS -->
