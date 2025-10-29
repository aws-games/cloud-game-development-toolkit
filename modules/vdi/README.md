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
**DNS Requirement**: AWS Client VPN connection required to resolve private DNS names (`username.vdi.internal`)

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

| Account Type                               | Created When     | Password Storage | Scope                | Use Case                   |
| ------------------------------------------ | ---------------- | ---------------- | -------------------- | -------------------------- |
| 🆘 **Administrator** (built-in)            | Windows boot     | EC2 Key Pair     | All workstations     | Emergency break-glass only |
| 🛡️ **Fleet Admin** (`fleet_administrator`) | SSM (if defined) | Secrets Manager  | All workstations     | Fleet management           |
| 🔧 **Local Admin** (`administrator`)       | SSM (if defined) | Secrets Manager  | Assigned workstation | Local administration       |
| 💻 **Standard User** (`user`)              | SSM (if defined) | Secrets Manager  | Assigned workstation | Daily usage                |

**Key Point**: Only the built-in Administrator exists automatically. All other accounts must be explicitly defined in the `users` variable.

## Prerequisites

1. **AWS Account Setup**

   - AWS CLI configured with deployment permissions
   - VPC with public and private subnets
   - Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [EC2](https://aws.amazon.com/ec2/))

2. **Network Planning**
   - **Public connectivity**: User public IP addresses for security group access
   - **Private connectivity**: VPN setup and VPC CIDR planning

## Cost Estimates

⚠️ **Cost Warning**: These examples deploy expensive GPU instances (~$1,430/month per workstation). Review costs before deployment.

**Example Configuration Costs (per workstation/month):**

- **g4dn.4xlarge instance**: ~$1,200/month
- **EBS storage** (300GB root + 2TB projects with 3000 IOPS): ~$230/month
- **Total per workstation**: ~$1,430/month

**3-workstation example total**: ~$4,290/month

**Cost optimization options:**

- Reduce volume sizes for development/testing
- Use smaller instance types (g4dn.xlarge, g4dn.2xlarge)
- Leverage Spot instances for non-production workloads
- Stop instances manually via AWS Console/CLI when not in use (EBS storage costs continue)

**For accurate pricing**: Use the [AWS Pricing Calculator](https://calculator.aws) with your specific requirements and region.

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
```

**VPN Client Requirements:**
- **AWS VPN Client** (recommended): Full compatibility with custom DNS resolution
- **OpenVPN/Other clients**: May require manual configuration for DNS resolution

## Connection Guide

### ⚠️ CRITICAL: Wait for Windows Boot

**After `terraform apply` completes, wait 5-10 minutes for Windows initialization before attempting login.**

During boot, you'll see:

- "Wrong username or password" errors (expected)
- DCV connection failures (expected)
- Certificate warnings (expected)

**Check boot status:**

```bash
aws ec2 get-console-output --instance-id $(terraform output -json connection_info | jq -r '."vdi-001".instance_id') --latest
```

**Ready when you see:**

- `EC2Launch: EC2 Launch has completed`
- User creation script completion
- DCV service startup messages

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
   - **Required for private DNS**: To access workstations via `https://username.vdi.internal:8443`, you must be connected to AWS Client VPN
   - **Private DNS resolution**: Custom DNS names only resolve when connected to the VPN
3. **Open DCV**:
   - **Public**: `https://workstation-public-ip:8443`
   - **Private (VPN required)**: `https://username.vdi.internal:8443` or `https://workstation-private-ip:8443`
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

## Password Management

### Password Details

- **Auto-generated**: 16-character secure passwords (letters + numbers + special characters)
- **Initial storage**: AWS Secrets Manager (source of truth for first login only)
- **User changes**: Users can change passwords in Windows - Secrets Manager will not update without additional configuration/custom logic (out of scope for this module)
- **Lifecycle**: Users can manage passwords in Windows or continue using Secrets Manager passwords

### Force Script Re-execution

**Purpose**: These variables provide convenience automation for common post-deployment tasks, but come with timing limitations due to AWS SSM's asynchronous nature.

```hcl
module "vdi" {
  force_run_user_script    = true  # User creation issues
  force_run_volume_script  = true  # Volume initialization issues
  force_run_software_script = true # Software installation issues
  debug = true                     # Force ALL scripts (nuclear option)
}
```

**Usage**: Set to `true` → apply → **wait 5-10 minutes** → verify results → remove variable → apply again

**Validated Behavior**:

- ✅ **Reliable execution**: SSM scripts consistently run when `force_run_*_script = true` is set
- ✅ **Predictable timing**: Script execution takes 5-10 minutes consistently
- ⚠️ **Asynchronous nature**: Terraform cannot wait for or report script completion status
- ⚠️ **Requires patience**: Not immediate like manual administration

**Alternative: Manual Administration**
For immediate, deterministic results, RDP to the instance as Administrator and run the operations manually. This approach offers:

- ✅ **Immediate execution** - no waiting for SSM
- ✅ **Real-time feedback** - see results and errors immediately
- ✅ **Full control** - handle edge cases and troubleshoot issues directly
- ✅ **Deterministic workflow** - integrates better with CI/CD pipelines requiring predictable timing

## Volume Configuration

### EBS Volume Management

**Volume changes do NOT trigger instance replacement.** Instances continue running during volume operations.

### Required Root Volume

```hcl
volumes = {
  Root = {                    # ← MUST be exactly "Root" (case-sensitive)
    capacity = 256            # ← Root volume automatically gets C: drive
    type = "gp3"
  }
}
```

### Drive Letter Assignment

**Automatic Assignment**: The module uses Windows auto-assignment for all drive letters:

- **Root Volume** → **C:** drive (Windows boot requirement)
- **EBS Volumes** → **Auto-assigned** (typically D:, E:, F:, etc.)
- **Instance Store** → **Auto-assigned** (typically next available letter)

**G4dn Instance Store Sizes**:

- `g4dn.xlarge`: 125GB NVMe SSD (auto-assigned)
- `g4dn.2xlarge`: 225GB NVMe SSD (auto-assigned)
- `g4dn.4xlarge`: 225GB NVMe SSD (auto-assigned)
- `g4dn.8xlarge`: 900GB NVMe SSD (auto-assigned)

**Benefits**:

- ✅ **Simple configuration** - No drive letter conflicts
- ✅ **Windows native behavior** - Uses standard assignment logic
- ✅ **User customizable** - Users can reassign letters via Disk Management
- ✅ **Cost efficiency** - Utilize included instance store

### Volume Change Lifecycle

| Change Type            | Automatic Handling                                    | Data Safety             | User Action Required                                  |
| ---------------------- | ----------------------------------------------------- | ----------------------- | ----------------------------------------------------- |
| **Add Volume**         | ✅ **Reliable** with `force_run_volume_script = true` | ✅ Safe                 | Wait 5-10 minutes after apply                         |
| **Increase Size**      | ✅ **Reliable** with `force_run_volume_script = true` | ✅ Safe                 | Wait for AWS optimization + SSM (5-15 min)            |
| **Reduce Size**        | ❌ **BLOCKED BY AWS**                                 | ⚠️ **Not Supported**    | See Volume Size Reduction                             |
| **Remove Volume**      | ✅ **Immediate and reliable**                         | ❌ **Volume data lost** | None (drive letters cleaned up)                       |
| **Change Volume Type** | ✅ Auto-applied                                       | ✅ Safe                 | Wait for optimization (5-15 min typical, up to 6 hrs) |
| **Rename Volume**      | ✅ Terraform only                                     | ✅ Safe                 | None                                                  |

### ⚠️ Volume Size Reduction - NOT SUPPORTED

**AWS Limitation**: EBS volumes cannot be reduced in size. This is an AWS platform limitation, not a module limitation.

**What Happens**: If you reduce volume capacity in Terraform (e.g., 500GB → 200GB):

```bash
terraform apply
# ❌ Error: InvalidParameterValue: Cannot decrease volume size from 500 to 200
# ❌ The apply will FAIL IMMEDIATELY - no waiting required
```

**Fail-Fast Behavior**:

- ✅ **Terraform validates volume sizes** before making AWS API calls
- ✅ **Error appears within seconds** of running `terraform apply`
- ✅ **No resources are modified** when size reduction is attempted
- ✅ **Clear error message** explains the limitation

**Workaround for Size Reduction**:

1. **Create new smaller volume** in Terraform config
2. **Manually migrate data** from old to new volume via RDP
3. **Remove old volume** from Terraform config
4. **Apply changes** - old volume will be deleted

### ⚠️ Volume Modification Limitations

**AWS has TWO separate limitations that BOTH must be satisfied:**

#### 1. Modification State Limitation

**Requirement**: Wait for current modification to complete optimization.
**Duration**: 5-15 minutes typically, up to 6 hours for large volumes.

**Check State**:

```bash
aws ec2 describe-volumes-modifications --volume-id vol-1234567890abcdef0
```

**States**:

- `optimizing`: Volume being modified (wait required)
- `completed`: Optimization finished (but rate limit may still apply)
- `failed`: Modification failed (can retry)

#### 2. Rate Limit (THE REAL BLOCKER)

**AWS Platform Constraint**: Exactly 6 hours between ANY volume modifications, regardless of optimization state.

**What Happens**:

```bash
terraform apply
# ❌ Error: VolumeModificationRateExceeded:
# ❌ Wait at least 6 hours between modifications per EBS volume
```

**Critical Facts**:

- This is a **hard-coded AWS platform limitation**, NOT a service quota
- Cannot be increased through Service Quotas console
- Cannot be overridden by AWS Support
- Even if `describe-volumes-modifications` shows "completed", the 6-hour timer still applies
- Timer starts from the **previous modification start time**, not completion time

**No Workaround**: You MUST wait the full 6 hours. There are no exceptions.

**Example Error Message**:

```
Error: updating EBS Volume (vol-1234567890abcdef0): InvalidParameterValue:
Cannot decrease volume size from 500 to 200
```

### Volume Naming & Drive Letter Assignment

- **Terraform names** ("Root", "Projects", "Cache") are organizational only
- **Windows sees** drive letters and volume labels set by initialization script
- **"Root" is special** - handled by `root_block_device`, everything else uses `ebs_block_device`
- **All volumes** - Use Windows auto-assignment (typically D:, E:, F:, etc.)
- **Volume labels** - Instance store labeled "Ephemeral", EBS volumes labeled "Data"
- **Users can reassign** - Use Windows Disk Management to change letters after deployment

**Typical Drive Layout Example**:

```
C: = Root EBS (300GB) - Windows OS
D: = Data (2TB) - EBS volume (auto-assigned)
E: = Data (200GB) - EBS volume (auto-assigned)
F: = Ephemeral (225GB) - Instance store (auto-assigned, lost on stop)
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

**Drive Letter Issues**

- Check drive assignment: `Get-Disk | Format-Table Number, Size, BusType`
- Force drive reassignment: Set `force_run_volume_script = true` and apply

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
- Check user creation status: `aws ssm get-parameter --name "/{project}/{workstation}/users/{username}/status_user_creation"`
- Force retry: Set `force_run_user_script = true`

**Volume Initialization Issues**

- Check volume status: `aws ssm get-parameter --name "/{project}/{workstation}/volume_status"`
- Check volume messages: `aws ssm get-parameter --name "/{project}/{workstation}/volume_message"`
- Force retry: Set `force_run_volume_script = true`

**Software Installation Problems**

- Check software status: `aws ssm get-parameter --name "/{project}/{workstation}/software_status"`
- Check failed packages: `aws ssm get-parameter --name "/{project}/{workstation}/software_message"`
- Force retry: Set `force_run_software_script = true`

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



## Contributing

See the [Contributing Guidelines](../../CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../../../LICENSE) file for details.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13 |
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.5.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.59.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.5 |

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
| [aws_ebs_volume.workstation_volumes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
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
| [aws_ssm_association.volume_initialization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.create_vdi_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_ssm_document.initialize_volumes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_ssm_document.install_software](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_ssm_parameter.vdi_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_volume_attachment.workstation_volume_attachments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
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
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.workstation_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_capacity_reservation_preference"></a> [capacity\_reservation\_preference](#input\_capacity\_reservation\_preference) | Capacity reservation preference for EC2 instances | `string` | `null` | no |
| <a name="input_client_vpn_config"></a> [client\_vpn\_config](#input\_client\_vpn\_config) | Client VPN configuration for private connectivity | <pre>object({<br/>    client_cidr_block       = optional(string, "192.168.0.0/16")<br/>    generate_client_configs = optional(bool, true)<br/>    split_tunnel            = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_create_client_vpn"></a> [create\_client\_vpn](#input\_create\_client\_vpn) | Create AWS Client VPN endpoint infrastructure (VPN endpoint, certificates, S3 bucket for configs) | `bool` | `false` | no |
| <a name="input_create_default_security_groups"></a> [create\_default\_security\_groups](#input\_create\_default\_security\_groups) | Create default security groups for VDI workstations | `bool` | `true` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | Enable debug mode to force re-run all VDI scripts and accelerate testing. Set to true to trigger, false for normal operation.<br><br>⚠️  WARNING: Volume script changes can cause data access issues on existing systems:<br>- Changing drive letters may break application shortcuts and saved paths<br>- Users may temporarily lose access to data until they update their shortcuts<br>- Consider notifying users before making drive letter changes<br>- New volumes and disk initialization are always safe | `bool` | `false` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | KMS key ID for EBS encryption (if encryption enabled) | `string` | `null` | no |
| <a name="input_enable_centralized_logging"></a> [enable\_centralized\_logging](#input\_enable\_centralized\_logging) | Enable centralized logging with CloudWatch log groups following CGD Toolkit patterns | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_force_run_software_script"></a> [force\_run\_software\_script](#input\_force\_run\_software\_script) | Force software installation script to re-execute. Uses timestamp() which causes Terraform plans to always show changes.<br><br>⚠️ WARNING: Set to true only when needed, then immediately set back to false to avoid constant plan changes.<br><br>When to use:<br>- Software installation failed and needs retry<br>- Adding new software packages<br>- Chocolatey package issues requiring reinstallation<br><br>Usage:<br>1. Set force\_run\_software\_script = true<br>2. Run terraform apply<br>3. Remove force\_run\_software\_script (or set to false)<br>4. Run terraform apply again | `bool` | `false` | no |
| <a name="input_force_run_user_script"></a> [force\_run\_user\_script](#input\_force\_run\_user\_script) | Force user creation script to re-execute. Uses timestamp() which causes Terraform plans to always show changes.<br><br>⚠️ WARNING: Set to true only when needed, then immediately set back to false to avoid constant plan changes.<br><br>When to use:<br>- User creation failed and needs retry<br>- User configuration changes not applied<br>- DCV session issues requiring user recreation<br><br>Usage:<br>1. Set force\_run\_user\_script = true<br>2. Run terraform apply<br>3. Remove force\_run\_user\_script (or set to false)<br>4. Run terraform apply again | `bool` | `false` | no |
| <a name="input_force_run_volume_script"></a> [force\_run\_volume\_script](#input\_force\_run\_volume\_script) | Force volume initialization script to re-execute. Uses timestamp() which causes Terraform plans to always show changes.<br><br>⚠️ WARNING: Set to true only when needed, then immediately set back to false to avoid constant plan changes.<br><br>When to use:<br>- Adding volumes that aren't being initialized automatically<br>- Removing volumes and need to clean up drive letters<br>- Volume configuration changes that didn't trigger automatically<br>- RAW disks that need formatting<br><br>Usage:<br>1. Set force\_run\_volume\_script = true<br>2. Run terraform apply<br>3. Remove force\_run\_volume\_script (or set to false)<br>4. Run terraform apply again | `bool` | `false` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `30` | no |
<<<<<<< HEAD
| <a name="input_presets"></a> [presets](#input\_presets) | Configuration blueprints defining instance types and named volumes with Windows drive mapping.<br><br>**KEY BECOMES PRESET NAME**: The map key (e.g., "ue-developer") becomes the preset name referenced by workstations.<br><br>Presets provide reusable configurations that can be referenced by multiple workstations via preset\_key.<br><br>Example:<br>presets = {<br>  "ue-developer" = {           # ← This key becomes the preset name<br>    instance\_type = "g4dn.2xlarge"<br>    gpu\_enabled   = true<br>    volumes = {<br>      Root = { capacity = 256, type = "gp3" }  # Root volume automatically gets C:<br>      Projects = { capacity = 1024, type = "gp3", windows\_drive = "Z:" }  # Specify drive letter<br>      Cache = { capacity = 500, type = "gp3" }  # Auto-assigned high-alphabet letter (Y:, X:, etc.)<br>    }<br>  }<br>  "basic-workstation" = {      # ← Another preset name<br>    instance\_type = "g4dn.xlarge"<br>    gpu\_enabled   = true<br>    volumes = {<br>      Root = { capacity = 200, type = "gp3" }  # Root volume automatically gets C:<br>      UserData = { capacity = 500, type = "gp3" }  # Auto-assigned high-alphabet letter<br>    }<br>  }<br>}<br><br># Referenced by workstations:<br>workstations = {<br>  "alice-ws" = {<br>    preset\_key = "ue-developer"      # ← References preset by key<br>  }<br>}<br><br>Valid volume types: "gp2", "gp3", "io1", "io2"<br>Drive letters are auto-assigned by Windows (typically C: for root, D:, E:, F:, etc. for additional volumes).<br><br>additional\_policy\_arns: List of additional IAM policy ARNs to attach to the VDI instance role.<br>Example: ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::123456789012:policy/MyCustomPolicy"] | <pre>map(object({<br>    # Core compute configuration<br>    instance_type = string<br>    ami           = optional(string, null)<br><br>    # Hardware configuration<br>    gpu_enabled = optional(bool, true)<br><br>    # Named volumes with auto-assigned drive letters<br>    volumes = map(object({<br>      capacity   = number<br>      type       = string<br>      iops       = optional(number, 3000)<br>      throughput = optional(number, 125)<br>      encrypted  = optional(bool, true)<br>    }))<br><br>    # Optional configuration<br>    iam_instance_profile   = optional(string, null)<br>    additional_policy_arns = optional(list(string), []) # Additional IAM policy ARNs to attach to the VDI instance role<br>    software_packages      = optional(list(string), null)<br>    tags                   = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | Prefix for resource names | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IaC": "Terraform",<br>  "ModuleBy": "CGD-Toolkit",<br>  "ModuleName": "terraform-aws-vdi",<br>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi",<br>  "RootModuleName": "-"<br>}</pre> | no |
| <a name="input_users"></a> [users](#input\_users) | Local Windows user accounts with Windows group types and network connectivity (managed via Secrets Manager)<br><br>**KEY BECOMES WINDOWS USERNAME**: The map key (e.g., "john-doe") becomes the actual Windows username created on VDI instances.<br><br>type options (Windows groups):<br>- "fleet\_administrator": User added to Windows Administrators group, created on ALL workstations (fleet management)<br>- "administrator": User added to Windows Administrators group, created only on assigned workstation<br>- "user": User added to Windows Users group, created only on assigned workstation<br><br>use\_client\_vpn options (VPN access):<br>- false: User accesses VDI via public internet or external VPN (default)<br>- true: User accesses VDI via module's Client VPN (generates VPN config)<br><br>Example:<br>users = {<br>  "vdiadmin" = {              # ← This key becomes Windows username "vdiadmin"<br>    given\_name = "VDI"<br>    family\_name = "Administrator"<br>    email = "admin@example.com"<br>    type = "fleet\_administrator" # Windows Administrators group on ALL workstations<br>    use\_client\_vpn = false      # Accesses via public internet/external VPN<br>  }<br>  "alice" = {                 # ← Public connectivity user<br>    given\_name = "Alice"<br>    family\_name = "Smith"<br>    email = "alice@example.com"<br>    type = "user"               # Windows Users group<br>    use\_client\_vpn = false      # Accesses via public internet (allowed\_cidr\_blocks)<br>  }<br>  "bob" = {                   # ← Private connectivity user<br>    given\_name = "Bob"<br>    family\_name = "Johnson"<br>    email = "bob@example.com"<br>    type = "user"               # Windows Users group<br>    use\_client\_vpn = true       # Accesses via module's Client VPN<br>  }<br>}<br><br># User assignment is now direct:<br># assigned\_user = "naruto-uzumaki"  # References users{} key directly in workstation | <pre>map(object({<br>    given_name     = string<br>    family_name    = string<br>    email          = string<br>    type           = optional(string, "user") # "administrator" or "user" (Windows group)<br>    use_client_vpn = optional(bool, false)    # Whether this user connects via module's Client VPN<br>    tags           = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where VDI instances will be deployed | `string` | n/a | yes |
| <a name="input_workstations"></a> [workstations](#input\_workstations) | Physical infrastructure instances with template references and placement configuration.<br><br>**KEY BECOMES WORKSTATION NAME**: The map key (e.g., "alice-workstation") becomes the workstation identifier used throughout the module.<br><br>Workstations inherit configuration from templates via preset\_key reference.<br><br>Example:<br>workstations = {<br>  # Public connectivity - user accesses via internet<br>  "alice-workstation" = {<br>    preset\_key = "ue-developer"<br>    subnet\_id = "subnet-public-123"     # Public subnet<br>    security\_groups = ["sg-vdi-public"]<br>    assigned\_user = "alice"<br>    allowed\_cidr\_blocks = ["203.0.113.1/32"]  # Alice's home IP<br>  }<br>  # Private connectivity - user accesses via VPN<br>  "bob-workstation" = {<br>    preset\_key = "basic-workstation"<br>    subnet\_id = "subnet-private-456"    # Private subnet<br>    security\_groups = ["sg-vdi-private"]<br>    assigned\_user = "bob"<br>    # No allowed\_cidr\_blocks - accessed via Client VPN<br>  }<br>  # Additional volumes at workstation level<br>  "dev-workstation" = {<br>    preset\_key = "basic-workstation"<br>    subnet\_id = "subnet-private-789"<br>    security\_groups = ["sg-vdi-private"]<br>    volumes = {<br>      ExtraStorage = { capacity = 2000, type = "gp3", windows\_drive = "Y:" }<br>    }<br>  }<br>}<br><br># User assignment is now direct:<br># assigned\_user = "alice"  # References users{} key directly in workstation<br><br>Drive letters are auto-assigned by Windows. Users can reassign them via Disk Management if needed.<br><br>additional\_policy\_arns: List of additional IAM policy ARNs to attach to the VDI instance role.<br>Example: ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::123456789012:policy/MyCustomPolicy"] | <pre>map(object({<br>    # Preset reference (optional - can use direct config instead)<br>    preset_key = optional(string, null)<br><br>    # Infrastructure placement<br>    subnet_id       = string<br>    security_groups = list(string)<br>    assigned_user   = optional(string, null) # User assigned to this workstation (for administrator/user types only)<br><br>    # Direct configuration (used when preset_key is null or as overrides)<br>    ami           = optional(string, null)<br>    instance_type = optional(string, null)<br>    gpu_enabled   = optional(bool, null)<br>    volumes = optional(map(object({<br>      capacity   = number<br>      type       = string<br>      iops       = optional(number, 3000)<br>      throughput = optional(number, 125)<br>      encrypted  = optional(bool, true)<br>    })), null)<br>    iam_instance_profile   = optional(string, null)<br>    additional_policy_arns = optional(list(string), []) # Additional IAM policy ARNs to attach to the VDI instance role<br>    software_packages      = optional(list(string), null)<br><br>    # Optional overrides<br>    allowed_cidr_blocks             = optional(list(string), null)<br>    capacity_reservation_preference = optional(string, null)<br>    tags                            = optional(map(string), null)<br>  }))</pre> | `{}` | no |
=======
| <a name="input_presets"></a> [presets](#input\_presets) | Configuration blueprints defining instance types and named volumes with Windows drive mapping.<br/><br/>**KEY BECOMES PRESET NAME**: The map key (e.g., "ue-developer") becomes the preset name referenced by workstations.<br/><br/>Presets provide reusable configurations that can be referenced by multiple workstations via preset\_key.<br/><br/>Example:<br/>presets = {<br/>  "ue-developer" = {           # ← This key becomes the preset name<br/>    instance\_type = "g4dn.2xlarge"<br/>    gpu\_enabled   = true<br/>    volumes = {<br/>      Root = { capacity = 256, type = "gp3", windows\_drive = "C:" }<br/>      Projects = { capacity = 1024, type = "gp3", windows\_drive = "D:" }<br/>    }<br/>  }<br/>  "basic-workstation" = {      # ← Another preset name<br/>    instance\_type = "g4dn.xlarge"<br/>    gpu\_enabled   = true<br/>  }<br/>}<br/><br/># Referenced by workstations:<br/>workstations = {<br/>  "alice-ws" = {<br/>    preset\_key = "ue-developer"      # ← References preset by key<br/>  }<br/>}<br/><br/>Valid volume types: "gp2", "gp3", "io1", "io2"<br/>Windows drives: "C:", "D:", "E:", etc. | <pre>map(object({<br/>    # Core compute configuration<br/>    instance_type = string<br/>    ami           = optional(string, null)<br/><br/>    # Hardware configuration<br/>    gpu_enabled = optional(bool, true)<br/><br/>    # Named volumes with Windows drive mapping<br/>    volumes = map(object({<br/>      capacity      = number<br/>      type          = string<br/>      windows_drive = string<br/>      iops          = optional(number, 3000)<br/>      throughput    = optional(number, 125)<br/>      encrypted     = optional(bool, true)<br/>    }))<br/><br/>    # Optional configuration<br/>    iam_instance_profile = optional(string, null)<br/>    software_packages    = optional(list(string), null)<br/>    tags                 = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | Prefix for resource names | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "terraform-aws-vdi",<br/>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi",<br/>  "RootModuleName": "-"<br/>}</pre> | no |
| <a name="input_users"></a> [users](#input\_users) | Local Windows user accounts with Windows group types and network connectivity (managed via Secrets Manager)<br/><br/>**KEY BECOMES WINDOWS USERNAME**: The map key (e.g., "john-doe") becomes the actual Windows username created on VDI instances.<br/><br/>type options (Windows groups):<br/>- "fleet\_administrator": User added to Windows Administrators group, created on ALL workstations (fleet management)<br/>- "administrator": User added to Windows Administrators group, created only on assigned workstation<br/>- "user": User added to Windows Users group, created only on assigned workstation<br/><br/>use\_client\_vpn options (VPN access):<br/>- false: User accesses VDI via public internet or external VPN (default)<br/>- true: User accesses VDI via module's Client VPN (generates VPN config)<br/><br/>Example:<br/>users = {<br/>  "vdiadmin" = {              # ← This key becomes Windows username "vdiadmin"<br/>    given\_name = "VDI"<br/>    family\_name = "Administrator"<br/>    email = "admin@company.com"<br/>    type = "fleet\_administrator" # Windows Administrators group on ALL workstations<br/>  }<br/>  "naruto-uzumaki" = {         # ← This key becomes Windows username "naruto-uzumaki"<br/>    given\_name = "Naruto"<br/>    family\_name = "Uzumaki"<br/>    email = "naruto@konoha.com"<br/>    type = "user"               # Windows Users group<br/>  }<br/>}<br/><br/># User assignment is now direct:<br/># assigned\_user = "naruto-uzumaki"  # References users{} key directly in workstation | <pre>map(object({<br/>    given_name     = string<br/>    family_name    = string<br/>    email          = string<br/>    type           = optional(string, "user") # "administrator" or "user" (Windows group)<br/>    use_client_vpn = optional(bool, false)    # Whether this user connects via module's Client VPN<br/>    tags           = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where VDI instances will be deployed | `string` | n/a | yes |
| <a name="input_workstations"></a> [workstations](#input\_workstations) | Physical infrastructure instances with template references and placement configuration.<br/><br/>**KEY BECOMES WORKSTATION NAME**: The map key (e.g., "alice-workstation") becomes the workstation identifier used throughout the module.<br/><br/>Workstations inherit configuration from templates via preset\_key reference.<br/><br/>Example:<br/>workstations = {<br/>  "alice-workstation" = {        # ← This key becomes the workstation name<br/>    preset\_key = "ue-developer"    # ← References templates{} key<br/>    subnet\_id = "subnet-123"<br/>    availability\_zone = "us-east-1a"<br/>    security\_groups = ["sg-456"]<br/>    assigned\_user = "alice"  # User assigned to this workstation<br/>    allowed\_cidr\_blocks = ["203.0.113.1/32"]<br/>  }<br/>  "vdi-001" = {                  # ← Another workstation name<br/>    preset\_key = "basic-workstation"<br/>    subnet\_id = "subnet-456"<br/>  }<br/>}<br/><br/># User assignment is now direct:<br/># assigned\_user = "alice"  # References users{} key directly in workstation | <pre>map(object({<br/>    # Preset reference (optional - can use direct config instead)<br/>    preset_key = optional(string, null)<br/><br/>    # Infrastructure placement<br/>    subnet_id       = string<br/>    security_groups = list(string)<br/>    assigned_user   = optional(string, null) # User assigned to this workstation (for administrator/user types only)<br/><br/>    # Direct configuration (used when preset_key is null or as overrides)<br/>    ami           = optional(string, null)<br/>    instance_type = optional(string, null)<br/>    gpu_enabled   = optional(bool, null)<br/>    volumes = optional(map(object({<br/>      capacity      = number<br/>      type          = string<br/>      windows_drive = string<br/>      iops          = optional(number, 3000)<br/>      throughput    = optional(number, 125)<br/>      encrypted     = optional(bool, true)<br/>    })), null)<br/>    iam_instance_profile = optional(string, null)<br/>    software_packages    = optional(list(string), null)<br/><br/>    # Optional overrides<br/>    allowed_cidr_blocks             = optional(list(string), null)<br/>    capacity_reservation_preference = optional(string, null)<br/>    tags                            = optional(map(string), null)<br/>  }))</pre> | `{}` | no |
>>>>>>> origin/main

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

## Known Limitations

### Volume Size Reduction

**Issue:** EBS volumes cannot be reduced in size (AWS platform limitation).

**Behavior:** Terraform will fail immediately with clear error message - no waiting required.

**Workaround:** Create new smaller volume, migrate data manually, remove old volume.

### Dynamic Volume Addition

**Two Approaches Available:**

#### Option 1: SSM Automation (Reliable)

**Best for**: Most use cases - reliable automation with predictable timing

1. Add volumes to Terraform configuration
2. Set `force_run_volume_script = true`
3. Run `terraform apply`
4. **Wait 5-10 minutes** for SSM volume script to execute
5. Verify volumes are initialized via RDP
6. Set `force_run_volume_script = false` and apply again

**Validated Results**:

- ✅ **Consistently works** across add/resize/delete operations
- ✅ **Predictable timing** - 5-10 minutes for script execution
- ✅ **Proper cleanup** - drive letters managed automatically

**Trade-offs**: Requires patience for SSM execution, but reliable when `force_run_volume_script = true` is used.

#### Option 2: Manual Administration (Deterministic)

**Best for**: Production environments requiring predictable timing

1. Add volumes to Terraform configuration
2. Run `terraform apply` (volumes created but uninitialized)
3. **Immediately** RDP to instance as Administrator
4. Run PowerShell commands to initialize volumes
5. **Complete in under 2 minutes** with full control

**Trade-offs**: Requires manual steps but provides immediate, predictable results.

**Troubleshooting SSM Volume Script:**
To determine if the script ran and what happened:

```bash
# Get instance ID
INSTANCE_ID=$(terraform output -json connection_info | jq -r '."vdi-001".instance_id')

# Check if SSM association executed
aws ssm list-command-invocations --instance-id $INSTANCE_ID --filters Key=DocumentName,Values=cgd-dev-initialize-volumes

# Get detailed execution results
aws ssm get-command-invocation --command-id <COMMAND_ID> --instance-id $INSTANCE_ID

# Check volume script status in SSM parameters
aws ssm get-parameter --name "/cgd/vdi-001/volume_status" --query 'Parameter.Value' --output text
aws ssm get-parameter --name "/cgd/vdi-001/volume_message" --query 'Parameter.Value' --output text
```

**Manual Initialization (if script failed):**

```powershell
# Initialize any RAW disks
Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } |
Initialize-Disk -PartitionStyle MBR -PassThru |
New-Partition -AssignDriveLetter -UseMaximumSize |
Format-Volume -FileSystem NTFS -Confirm:$false
```

### Volume Resize Troubleshooting

**Issue:** Volume increased in AWS but partition not extended to use full space.

**Check Current State:**

```powershell
# Check disk sizes vs partition sizes
Get-Disk | Format-Table Number, Size, BusType
Get-Partition | Format-Table DiskNumber, DriveLetter, Size
```

**Manual Partition Extension:**

```powershell
# Extend partition to use full disk (replace F: with your drive letter)
$DriveLetter = "F"
$Partition = Get-Partition -DriveLetter $DriveLetter
$MaxSize = (Get-PartitionSupportedSize -DriveLetter $DriveLetter).SizeMax
Resize-Partition -DriveLetter $DriveLetter -Size $MaxSize
```

**Troubleshoot SSM Volume Resize:**
Same SSM troubleshooting commands as above - the volume script handles both initialization and resize operations.

## Volume Management Summary

**Based on comprehensive testing, the VDI module's volume management is reliable when used correctly:**

### ✅ **What Works Reliably:**

- **Volume Addition**: Consistent with `force_run_volume_script = true` (5-10 min)
- **Volume Resize**: Reliable with proper AWS timing constraints (6-hour rule)
- **Volume Deletion**: Immediate and reliable with automatic cleanup
- **Drive Letter Management**: Automatic assignment and cleanup via SSM

### ⏱️ **Timing Expectations:**

- **EBS Operations**: Immediate (create, attach, detach, delete)
- **SSM Script Execution**: 5-10 minutes consistently
- **AWS Volume Modifications**: Subject to 6-hour rate limits

### 🛠️ **Best Practices:**

1. **Always use `force_run_volume_script = true`** when adding/resizing volumes
2. **Wait 5-10 minutes** after `terraform apply` for SSM scripts
3. **Check AWS volume modification state** before making multiple changes
4. **Use manual PowerShell commands** when immediate results are required
5. **Plan volume changes** around AWS 6-hour rate limits

### 🔧 **Troubleshooting Tools:**

- **SSM command history**: Verify script execution
- **PowerShell disk commands**: Check current state
- **AWS CLI volume status**: Monitor modification progress
- **Manual initialization**: Fallback for immediate control
