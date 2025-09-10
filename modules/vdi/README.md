# VDI (Virtual Desktop Infrastructure) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **⚠️ CRITICAL AMI REQUIREMENT**
>
> **You MUST build a Windows AMI using Packer before using this module.** Without a properly configured AMI, instance deployment will fail. Follow the [Packer AMI Build Guide](../../assets/packer/virtual-workstations/windows/README.md) to create the required Windows Server 2025 AMI with DCV and development tools.
>
> **📖 For complete VDI setup and configuration guidance, see the [Amazon DCV Documentation](https://docs.aws.amazon.com/dcv/).**

## Version Requirements

Consult the `versions.tf` file for requirements

**Critical Version Dependencies:**

- **Terraform >= 1.0** - Required for modern Terraform features and AWS provider compatibility
- **AWS Provider >= 6.0** - Required for enhanced security group rules and modern AWS resource support
- **Random Provider >= 3.0** - Required for password generation and secret management
- **TLS Provider >= 4.0** - Required for key pair generation and certificate management

**VDI Application Requirements:**

- **Windows Server 2025 AMI** - Built with Packer template including DCV, NVIDIA drivers, and development tools
- **GPU Instance Types** - g4dn.xlarge or larger recommended for game development workloads

These version requirements enable the security patterns and multi-user capabilities used throughout this module.

## Features

- **Complete VDI Infrastructure** - Single module deploys EC2 workstations, security groups, IAM roles, and user management
- **Flexible Authentication** - EC2 key pairs (break-glass) and Secrets Manager (managed) for secure access
- **Security by Default** - Least privilege IAM, encrypted storage, restricted network access
- **Flexible Connectivity** - Public internet access or private VPN-only access patterns
- **Game Development Optimized** - GPU instances, high-performance storage, development tool integration
- **Runtime Software Installation** - Predefined packages plus custom scripts via SSM automation
- **Amazon DCV Ready** - Pre-configured high-performance remote desktop with QUIC protocol support

## Connectivity Patterns

### Public Connectivity (Default)

**Best for**: Solo developers, small teams, development environments

**How it works**: Direct internet access with IP-based security restrictions

```hcl
users = {
  "john-doe" = {
    connectivity_type = "public"  # Default - direct internet access
  }
}

workstations = {
  "vdi-001" = {
    subnet_id = aws_subnet.public_subnet.id
    allowed_cidr_blocks = ["203.0.113.1/32"]  # User's public IP
  }
}
```

**Connection**: `https://54.123.45.67:8443` or `rdp://54.123.45.67:3389`

### Private Connectivity with AWS Client VPN

**Best for**: Enterprise environments, security-conscious deployments, distributed teams

**How it works**: VPN tunnel to private VDI instances with internal DNS

```hcl
module "vdi" {
  enable_private_connectivity = true  # Creates VPN infrastructure
  
  users = {
    "john-doe" = {
      connectivity_type = "private"  # Gets VPN access + certificates
    }
  }
  
  workstations = {
    "vdi-001" = {
      subnet_id = aws_subnet.private_subnet.id
      allowed_cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
    }
  }
}
```

**Connection**: Connect to VPN → `https://john-doe.vdi.internal:8443`

**What gets created automatically**:
- **Client VPN Endpoint** - Shared by all private users (~$73/month)
- **Per-User Certificates** - Unique certificate per private user
- **S3 Certificate Storage** - Complete .ovpn files ready for distribution
- **Internal DNS** - Clean names like `john-doe.vdi.internal`

**Advantages of Private Connectivity**:
- ✅ **Enhanced Security** - No public internet exposure
- ✅ **IP Management Simplification** - No more tracking user public IPs
- ✅ **Clean DNS Names** - `john-doe.vdi.internal` instead of IP addresses
- ✅ **Mixed Connectivity** - Some users private, others public

## Architecture

**Core Components:**

- **EC2 Workstations**: GPU-enabled instances with game development tools and DCV remote access
- **Secrets Manager**: Automatic password generation and rotation for user accounts
- **Security Groups**: Least privilege network access with user-specific IP restrictions
- **IAM Roles**: SSM permissions for management and optional AWS service access
- **SSM Automation**: Runtime software installation and configuration management
- **S3 Storage**: Custom script hosting and emergency key backup
- **Client VPN** (Optional): Secure private access with per-user certificates

### Account Creation Pattern

**Every VDI instance automatically gets exactly 3 accounts:**

| Account | Created When | Password Storage | Use Case |
|---------|-------------|------------------|----------|
| **Administrator** | Windows boot | EC2 Key Pair (encrypted) | Break-glass emergency access |
| **VDIAdmin** | User data script | Secrets Manager | Automation, SSM management |
| **Assigned User** | User data script | Secrets Manager | Daily VDI usage |

## Prerequisites

### Required Access & Tools

1. **AWS Account Setup**
   - AWS CLI configured with deployment permissions
   - VPC with public and private subnets
   - Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [EC2](https://aws.amazon.com/ec2/))

2. **Windows AMI Requirements** (CRITICAL ⚠️)
   - Must build Windows Server 2025 AMI using [Packer template](../../assets/packer/virtual-workstations/windows/README.md)
   - AMI must include DCV, NVIDIA drivers, and development tools
   - Without proper AMI, instance deployment will fail

3. **Network Planning**
   - User public IP addresses for security group access (public connectivity)
   - OR VPN setup for private connectivity
   - VPC CIDR planning for internal access

### Getting User Public IP Addresses

**For Public Connectivity**, collect each user's public IP address:

- **Current IP**: Visit `https://checkip.amazonaws.com/` or run `curl https://checkip.amazonaws.com/`
- **Office Network**: Get the office public IP from your network administrator
- **Home Users**: Each user should check their home public IP

**For Private Connectivity**, this is not needed - users connect via VPN.

## Examples

For a quickstart, please review the [examples](examples/). They provide complete Terraform configuration with VPC setup, security groups, and detailed connection instructions.

**Available Examples:**

- **[Public Connectivity](examples/public-connectivity/)** - Direct internet access with IP restrictions
- **[Private Connectivity](examples/private-connectivity/)** - AWS Client VPN with internal DNS

Each example includes complete infrastructure setup and connection instructions.

## Deployment Instructions

### Step 1: Build Windows AMI with Packer

**CRITICAL**: You must build a Windows AMI before deploying VDI workstations.

```bash
# Navigate to Packer directory
cd assets/packer/virtual-workstations/windows/lightweight/

# Build AMI (20-30 minutes)
packer build windows-server-2025-lightweight.pkr.hcl

# Note the AMI ID from the output
# Example: ami-0123456789abcdef0
```

**The AMI will be named**: `vdi-lightweight-windows-server-2025-YYYY-MM-DD-HH-MM-SS`

### Step 2: Configure the Module

**Public Connectivity Example:**

```terraform
module "vdi" {
  source = "./modules/vdi"

  # Core Configuration
  project_prefix = "gamedev"
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Templates (Reusable Configurations)
  templates = {
    "developer" = {
      instance_type = "g4dn.2xlarge"
      software_packages = ["visual-studio-2022", "git", "unreal-engine-5.3"]
      volumes = {
        Root = { capacity = 256, type = "gp3" }
        Projects = { capacity = 1024, type = "gp3" }
      }
    }
  }

  # Workstations (Infrastructure Placement)
  workstations = {
    "vdi-001" = {
      template_key = "developer"
      subnet_id = aws_subnet.public_subnet.id
      availability_zone = "us-east-1a"
    }
  }

  # Users (Authentication & Identity)
  users = {
    "john-doe" = {
      given_name = "John"
      family_name = "Doe"
      email = "john@company.com"
      connectivity_type = "public"
    }
  }

  # Assignments (User-to-Workstation Mapping)
  workstation_assignments = {
    "vdi-001" = {
      user = "john-doe"
      user_source = "local"
    }
  }

  # Security Configuration
  allowed_cidr_blocks = ["203.0.113.1/32"]  # User's public IP
}
```

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs for connection details
terraform output connection_info
```

### Step 4: Validate Deployment

**Check installation progress:**
```bash
# Replace with your instance ID from terraform output
INSTANCE_ID="i-0123456789abcdef0"

# Check user creation and software installation status
aws ssm list-command-invocations \
  --instance-id $INSTANCE_ID \
  --query 'CommandInvocations[?contains(Comment,`Immediate`)].{Status:Status,Document:DocumentName}' \
  --output table
```

**Connect and verify users:**
```powershell
# After connecting via DCV/RDP, verify users exist
Get-LocalUser | Where-Object { $_.Name -notin @('Administrator', 'Guest', 'DefaultAccount', 'WDAGUtilityAccount') }

# Check DCV sessions have correct ownership
& "C:\Program Files\NICE\DCV\Server\bin\dcv.exe" list-sessions

# Verify software installation
choco --version  # Should show Chocolatey version
git --version    # Should show Git version
```

## Verification & Testing

### Quick Verification Steps

**1. Check instance status:**

```bash
# Verify instances are running
aws ec2 describe-instances --filters "Name=tag:Project,Values=gamedev" --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'
```

**2. Test DCV connectivity:**

```bash
# Test DCV port accessibility
curl -k https://<workstation-public-ip>:8443
# Should return DCV login page HTML
```

**3. Get Administrator password:**

```bash
# Set your workstation name
WORKSTATION_NAME="vdi-001"

# Get password using Terraform output + AWS CLI
terraform output -json private_keys | jq -r ".\"$WORKSTATION_NAME\"" > temp_key.pem
chmod 600 temp_key.pem
aws ec2 get-password-data \
  --instance-id $(terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") \
  --priv-launch-key temp_key.pem \
  --query 'PasswordData' \
  --output text
rm temp_key.pem
```

**4. Connect via DCV:**

- Open browser to `https://<workstation-ip>:8443`
- Accept certificate warning (self-signed certificates)
- Login with `Administrator` and retrieved password
- Verify Windows desktop loads and is responsive

## Client Connection Guide

### Amazon DCV Client Setup

**1. Download DCV Client:**

Download from [https://download.nice-dcv.com/](https://download.nice-dcv.com/) for your operating system.

**2. Connection Configuration:**

```
Server: https://<workstation-ip>:8443
Username: Administrator (or assigned user)
Password: <from-secrets-manager>
```

**3. For Private Connectivity:**

1. Import .ovpn file from S3 into VPN client
2. Connect to VPN
3. Access via internal DNS: `https://john-doe.vdi.internal:8443`

### Remote Desktop Protocol (RDP)

**Windows Built-in RDP:**

1. Open Remote Desktop Connection (mstsc)
2. Enter workstation IP address
3. Use Administrator credentials

## Architecture Details

### 5-Tier VDI Architecture

**The VDI module uses a flexible 5-tier architecture for maximum reusability and customization:**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Templates     │───▶│   Workstations   │───▶│   Assignments   │
│ (Reusable Base) │    │ (Infrastructure) │    │ (User Mapping)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │      Users      │              │
         │              │ (Authentication)│              │
         │              └─────────────────┘              │
         │                       │                       │
         │              ┌─────────────────┐              │
         └─────────────▶│ Software Pkgs   │◀─────────────┘
                        │ (Runtime Install)│
                        └─────────────────┘
```

#### **Tier 1: Templates** (Reusable Configurations)
```hcl
templates = {
  "ue-developer" = {
    instance_type = "g4dn.2xlarge"
    software_packages = ["chocolatey", "visual-studio-2022", "unreal-engine-5.3"]
    volumes = { Root = { capacity = 256 }, Projects = { capacity = 1024 } }
  }
}
```

#### **Tier 2: Workstations** (Infrastructure Placement)
```hcl
workstations = {
  "alice-workstation" = {
    template_key = "ue-developer"  # Inherits from template
    subnet_id = "subnet-123"
    availability_zone = "us-east-1a"
  }
}
```

#### **Tier 3: Users** (Authentication & Identity)
```hcl
users = {
  "alice" = {
    given_name = "Alice"
    family_name = "Smith"
    email = "alice@company.com"
    connectivity_type = "private"  # or "public"
  }
}
```

#### **Tier 4: Assignments** (User-to-Workstation Mapping)
```hcl
workstation_assignments = {
  "alice-assignment" = {
    user = "alice"
    workstation = "alice-workstation"
    user_source = "local"  # or "ad" for Active Directory
  }
}
```

#### **Tier 5: Software Packages** (Runtime Installation)
```hcl
# Available packages: chocolatey, visual-studio-2022, git, unreal-engine-5.3, perforce
# Plus custom scripts for team-specific tools
```

### Password Management & Account Creation

**Every VDI instance automatically gets exactly 3 accounts:**

| Account | Created When | Password Storage | Password Rotation | Use Case |
|---------|-------------|------------------|-------------------|----------|
| **Administrator** | Windows boot | EC2 Key Pair (encrypted) | Never (emergency only) | Break-glass emergency access |
| **VDIAdmin** | User data script | Secrets Manager | Manual only | Automation, SSM management |
| **Assigned User** | User data script | Secrets Manager | Automatic on instance replacement | Daily VDI usage |

**Account Creation Timeline:**
```
Instance Launch
       ↓
1. Windows boots → Administrator account exists (built-in)
       ↓
2. EC2Launch runs → Administrator password generated & encrypted
       ↓
3. User data script runs → VDIAdmin + john-doe accounts created
       ↓
4. Passwords stored → Secrets Manager entries created
       ↓
5. DCV sessions created → One session per account
       ↓
Ready for use (all 3 accounts functional)
```

**Password Storage Locations:**

| Account | Storage Method | Location | Retrieval Method |
|---------|---------------|----------|------------------|
| **Administrator** | EC2 Key Pair | AWS EC2 Service | `aws ec2 get-password-data` + private key |
| **VDIAdmin** | Secrets Manager | `/{project}/workstations/{workstation}/vdiadmin-password` | `aws secretsmanager get-secret-value` |
| **john-doe** | Secrets Manager | `/{project}/users/john-doe` | `aws secretsmanager get-secret-value` |

### DCV Session Management

**Windows DCV Limitation**: ONE console session per Windows instance (architectural constraint)

**VDI Module Session Strategy:**
```powershell
# Boot-time session creation (via User Data):
dcv create-session --owner=Administrator administrator-session
dcv create-session --owner=VDIAdmin vdiadmin-session  
dcv create-session --owner=john-doe john-doe-session

# Admin fleet access (if enable_admin_fleet_access = true)
dcv share-session --user Administrator --permissions=full john-doe-session
```

**Session Management Commands:**
```powershell
# List all sessions
dcv list-sessions

# Share session with admin (troubleshooting)
dcv share-session --user Administrator --permissions=full john-doe-session

# Remove admin access (restore privacy)
dcv unshare-session --user Administrator john-doe-session

# Close session
dcv close-session john-doe-session
```

## AMI Building with Packer

**The VDI module requires a Windows Server 2025 AMI built with Packer.**

### **Lightweight Template (Recommended)**

**Build the AMI:**
```bash
cd assets/packer/virtual-workstations/windows/lightweight/
packer build windows-server-2025-lightweight.pkr.hcl
```

**What's included:**
- ✅ Windows Server 2025 base
- ✅ Amazon DCV remote desktop
- ✅ NVIDIA GRID drivers (GPU instances)
- ✅ AWS CLI and PowerShell modules
- ✅ Git, Chocolatey package manager
- ✅ SSM agent for remote management

**Benefits:**
- **Fast build time** - 20-30 minutes
- **Flexible software** - Install what you need via SSM
- **Smaller disk usage** - ~80GB base
- **Easy testing** - Quick to rebuild and test changes

**Software installation** happens at runtime via SSM, giving you flexibility to choose different packages per workstation.

## Advanced Software Installation

### **Runtime Software Installation via SSM**

**Available Software Packages:**

| Package Name | Installs | Runtime |
|--------------|----------|----------|
| `"chocolatey"` | Chocolatey package manager | ~5 minutes |
| `"visual-studio-2022"` | Visual Studio 2022 Community | ~45 minutes |
| `"git"` | Git version control | ~5 minutes |
| `"unreal-engine-5.3"` | Unreal Engine 5.3 + Epic Games Launcher | ~30 minutes |
| `"perforce"` | Perforce client tools (P4, P4V, P4Admin) | ~10 minutes |

### **Configuration Methods**

**Method 1: Using Templates (Recommended)**
```hcl
templates = {
  "ue-dev" = {
    instance_type = "g4dn.2xlarge"
    software_packages = [
      "chocolatey",
      "visual-studio-2022", 
      "git",
      "unreal-engine-5.3"
    ]
  }
}
```

**Method 2: Template Inheritance with Customization**
```hcl
workstations = {
  "bob-workstation" = {
    template_key = "ue-dev"  # Inherits base packages
    
    # Add additional packages
    software_packages_additions = ["perforce"]
    
    # Remove packages Bob doesn't need
    software_packages_exclusions = ["visual-studio-2022"]
    # Final packages: chocolatey, git, unreal-engine-5.3, perforce
  }
}
```

**Installation Timeline:**
```
Instance Launch → Windows boots (2-3 minutes) → User accounts created (2-5 minutes) 
→ Software packages installed (5-60 minutes) → DCV sessions created → Ready for use
```

**Total deployment time**: 10-70 minutes depending on software packages selected.

## Troubleshooting

### Common Issues

#### 1. Instance Launch Failures

**Symptoms**: Instances fail to start, "AMI not found" errors

**Solutions**:
- Verify Windows AMI exists: `aws ec2 describe-images --owners self --filters "Name=name,Values=*windows-server-2025*"`
- Check AMI is in correct region
- Ensure Packer build completed successfully

#### 2. Connection Timeouts

**Symptoms**: DCV/RDP connections timeout or refuse

**Solutions**:
- Check security group allows your IP: `curl https://checkip.amazonaws.com/`
- Verify instance is running: `aws ec2 describe-instances`
- Test port connectivity: `telnet <instance-ip> 8443`

#### 3. Password Retrieval Issues

**Symptoms**: Cannot decrypt Administrator password

**Solutions**:
- Wait 5-10 minutes after instance launch for password generation
- Use S3 backup key if Terraform output fails:
  ```bash
  aws s3 cp s3://<bucket>/emergency-keys/<workstation>/<key>.pem ./backup-key.pem
  ```

#### 4. DCV "Connecting" Spinner

**Symptoms**: DCV web client shows connecting but never loads desktop

**Solutions**:
- Connect via SSM Session Manager: `aws ssm start-session --target <instance-id>`
- Check DCV sessions: `dcv list-sessions`
- Restart DCV service: `Restart-Service dcvserver`

#### 5. User Data Not Executing on Windows Server 2025 (MAJOR EC2 ISSUE)

**Symptoms**: 
- Console output shows "User data format: unrecognized" for ALL user data formats
- Only Administrator, Guest, DefaultAccount exist (no VDI users created)
- EC2Launch v2 logs show: "fork/exec C:\Windows\System32\wbem\wmic.exe: The system cannot find the file specified"

**Root Cause**: **MULTIPLE BROKEN USER DATA FORMATS** on Windows Server 2025 + EC2Launch v2:
- ❌ `<powershell>` tags → "User data format: unrecognized"
- ❌ `#ps1_sysnative` header → "User data format: unrecognized" 
- ❌ EC2Launch v2 YAML format → "User data format: unrecognized"
- ❌ `<script>` tags → "User data format: unrecognized"

**This is a MAJOR AWS EC2 issue affecting ALL Windows Server 2025 instances.**

**VDI Module Solution - Hybrid Approach**:

1. **Minimal User Data** (WMIC fix + SSM trigger):
   ```yaml
   version: 1.0
   tasks:
     - task: executeScript
       inputs:
         type: powershell
         content: |
           # Fix WMIC dependency
           DISM /Online /Add-Capability /CapabilityName:WMIC~~~~
           
           # Trigger SSM immediately (no race conditions)
           aws ssm send-command --instance-ids $InstanceID --document-name "create-vdi-users"
   ```

2. **Complex Logic in SSM Document** (always reliable):
   - All user creation logic moved to SSM document
   - Instance triggers SSM on itself when ready
   - Avoids race conditions (EC2 → SSM vs SSM → EC2)

**Why This Works**:
- **User Data**: Only does 2 simple things (WMIC fix + trigger SSM)
- **SSM Document**: Contains all complex logic (always reliable)
- **Immediate Execution**: User data triggers SSM instantly when instance is ready
- **No Race Conditions**: Instance triggers SSM on itself, guaranteed ready

**Timing Advantage**:
- ❌ **Previous**: Terraform → SSM send-command → "Instance not ready yet"
- ✅ **Now**: EC2 boots → User data → SSM send-command → "Instance ready, execute immediately"

**Reference**: AWS re:Post community solution by nsekulov (May 2024) + hybrid approach

#### 6. User Accounts Not Created (Legacy SSM Issues)

**Symptoms**: Only Administrator, Guest, DefaultAccount exist (after WMIC fix applied)

**Cause**: SSM user creation command failed

**Check status:**
```bash
# Check if user creation succeeded
aws ssm list-command-invocations \
  --instance-id $INSTANCE_ID \
  --query 'CommandInvocations[?contains(DocumentName,`setup-dcv-users-sessions`)].{Status:Status,StatusDetails:StatusDetails}'
```

**Manual fix:**
```bash
# Retry user creation if failed
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "cgd-dev-setup-dcv-users-sessions" \
  --parameters "WorkstationKey=vdi-001,AssignedUser=john-doe,UserSource=local,ProjectPrefix=cgd"
```

#### 7. DCV Sessions Owned by SYSTEM

**Symptoms**: `dcv list-sessions` shows `(owner:SYSTEM)` instead of assigned user

**Fix**: Recreate sessions with correct ownership
```powershell
# Close existing sessions
dcv close-session console

# Recreate with correct owner
dcv create-session --owner john-doe john-doe-session
```

#### 8. SSM Association Parameter Passing Issues (CRITICAL)

**Symptoms**: 
- SSM associations show "Success" status but users aren't created
- PowerShell scripts receive empty/null parameters
- Manual `send-command` works but Terraform associations don't

**Root Cause**: **SSM associations and send-command use different parameter passing mechanisms**
- `send-command`: Server-side parameter substitution with `{{ ParameterName }}`
- `associations`: Client-side parameter passing requiring explicit script parameter handling

**The Solution - Two-Step SSM Document Approach**:

```hcl
# CORRECT: Two-step approach avoids PowerShell escaping hell
mainSteps = [
  {
    action = "aws:runPowerShellScript"
    name   = "writeScript"
    inputs = {
      runCommand = [
        "New-Item -ItemType Directory -Path 'C:\\temp' -Force",
        "Set-Content -Path 'C:\\temp\\vdi-script.ps1' -Value @'\n${file("${path.module}/script.ps1")}\n'@"
      ]
    }
  },
  {
    action = "aws:runPowerShellScript"
    name   = "executeScript"
    inputs = {
      runCommand = [
        "powershell.exe -ExecutionPolicy Unrestricted -File 'C:\\temp\\vdi-script.ps1' -WorkstationKey '{{ WorkstationKey }}' -AssignedUser '{{ AssignedUser }}'"
      ]
    }
  }
]
```

**PowerShell Script Requirements**:
```powershell
# REQUIRED: param() block at start of script
param(
    [string]$WorkstationKey,
    [string]$AssignedUser,
    [string]$ProjectPrefix,
    [string]$Region
)

# Complex AWS CLI commands work normally when not embedded in command lines
$AllSecrets = aws secretsmanager list-secrets --region $Region --query "SecretList[?starts_with(Name, '$ProjectPrefix/$WorkstationKey/users/')].Name" --output text
```

**Why This Works**:
1. **Step 1**: Write script to temp file using PowerShell here-string - no escaping issues
2. **Step 2**: Execute script file with clean parameter passing - no embedded quote conflicts
3. **Parameters**: `{{ ParameterName }}` works perfectly in simple command context
4. **Script**: Complex AWS CLI commands with quotes no longer embedded in command line

**Failed Approaches (Don't Use)**:
- ❌ `{{ ParameterName }}` in embedded script (works with send-command only)
- ❌ `$env:SSM_ParameterName` environment variables (wrong approach)
- ❌ Single-line PowerShell command embedding (escaping nightmare)
- ❌ Complex command-line escaping (parsing errors)

**Testing Strategy**:
```bash
# Test manual parameter passing first
& script.ps1 -WorkstationKey "vdi-001" -AssignedUser "john-doe"

# Use send-command for quick testing (different mechanism)
aws ssm send-command --document-name "doc" --parameters "WorkstationKey=vdi-001"

# Check association execution history
aws ssm list-command-invocations --instance-id i-123 --max-items 3

# Get detailed error output
aws ssm get-command-invocation --command-id cmd-123 --instance-id i-123
```

#### 9. First Boot Timing and Race Conditions

**Problem**: SSM associations may trigger before instances are ready to receive commands

**Solution**: Use `time_sleep` resource to ensure SSM agent is ready

```hcl
# Wait for SSM agent to be ready
resource "time_sleep" "wait_for_ssm_agent" {
  depends_on      = [aws_instance.workstations]
  create_duration = "300s"  # 5-minute delay
}

# SSM association depends on the wait
resource "aws_ssm_association" "vdi_user_creation" {
  depends_on = [time_sleep.wait_for_ssm_agent]
  # ... rest of configuration
}
```

**Alternative - Instance Self-Triggering**:
```yaml
# In user data - instance triggers SSM on itself when ready
version: 1.0
tasks:
  - task: executeScript
    inputs:
      type: powershell
      content: |
        # Wait for instance to be fully ready
        Start-Sleep -Seconds 60
        
        # Trigger SSM document on self
        $InstanceId = (Invoke-RestMethod -Uri 'http://169.254.169.254/latest/meta-data/instance-id')
        aws ssm send-command --instance-ids $InstanceId --document-name "create-vdi-users"
```

**Benefits of Self-Triggering**:
- ✅ No race conditions - instance triggers when ready
- ✅ Immediate execution - no waiting for association schedule
- ✅ Guaranteed timing - instance knows when it's ready

#### 10. Private Connectivity Issues

**VPN Connection Fails:**
- Verify .ovpn file downloaded from correct S3 folder
- Check VPN client supports AWS Client VPN
- Ensure certificates are valid and not expired

**Internal DNS Not Resolving:**
```bash
# Test DNS resolution after VPN connection
nslookup john-doe.vdi.internal
# Should resolve to private IP (10.0.x.x)
```

**Certificate Issues:**
```bash
# Check certificate validity
openssl x509 -in john-doe.crt -text -noout
# Verify dates and subject
```

### Debug Commands

```bash
# Check current IP
curl https://checkip.amazonaws.com/

# Test basic connectivity
telnet <instance-ip> 8443  # DCV
telnet <instance-ip> 3389  # RDP

# Connect via SSM (no network access needed)
aws ssm start-session --target <instance-id>

# For private connectivity - test VPN
ping john-doe.vdi.internal
nslookup john-doe.vdi.internal

# Check VPN client logs
# Location varies by client (AWS VPN Client, OpenVPN, etc.)
```

### Password Retrieval Methods

**Method 1: Terraform Output + AWS CLI (Primary)**
```bash
# Get Administrator password
WORKSTATION_NAME="vdi-001"
terraform output -json private_keys | jq -r ".\"$WORKSTATION_NAME\"" > temp_key.pem
chmod 600 temp_key.pem
aws ec2 get-password-data \
  --instance-id $(terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") \
  --priv-launch-key temp_key.pem \
  --query 'PasswordData' \
  --output text
rm temp_key.pem
```

**Method 2: S3 Backup Key (If Terraform fails)**
```bash
# Use S3 backup key
BUCKET_NAME="cgd-vdi-emergency-keys-xxxxx"
aws s3 cp s3://$BUCKET_NAME/emergency-keys/$WORKSTATION_NAME/cgd-dev-$WORKSTATION_NAME-private-key.pem ./backup-key.pem
chmod 600 backup-key.pem
aws ec2 get-password-data --instance-id [instance-id] --priv-launch-key backup-key.pem --query 'PasswordData' --output text
rm backup-key.pem
```

**Method 3: Get User Passwords (Secrets Manager)**
```bash
# Get VDIAdmin password
aws secretsmanager get-secret-value \
  --secret-id "cgd/workstations/vdi-001/vdiadmin-password" \
  --query SecretString --output text | jq -r '.password'

# Get assigned user password
aws secretsmanager get-secret-value \
  --secret-id "cgd/users/john-doe" \
  --query SecretString --output text | jq -r '.password'
```

## Administrator Access to Private VDI

**For private connectivity deployments, administrators have multiple access options:**

### Option 1: AWS Systems Manager Fleet Manager (Recommended)

1. Go to **EC2 Console → Fleet Manager**
2. Select your VDI instance
3. Click **"Connect with Remote Desktop"**
4. Access full Windows desktop in browser

**Advantages**: No VPN setup required, works through AWS infrastructure, full GUI access

### Option 2: Add Admin as VPN User (Optional)

```hcl
users = {
  "admin-john" = {
    given_name = "John"
    family_name = "Admin"
    email = "john.admin@company.com"
    connectivity_type = "private"  # Gets VPN access
  }
}
```

## VDI Connection Methods

**AWS provides built-in DNS resolution for all EC2 instances - no custom DNS setup required.**

### Public Access (Internet)
```bash
# Direct IP connection
rdp://54.123.45.67:3389
https://54.123.45.67:8443

# AWS public DNS (automatic)
rdp://ec2-54-123-45-67.us-east-1.compute.amazonaws.com:3389
https://ec2-54-123-45-67.us-east-1.compute.amazonaws.com:8443
```

### Private Access (VPN/VPC)
```bash
# Direct private IP connection
rdp://10.0.1.100:3389
https://10.0.1.100:8443

# AWS private DNS (automatic)
rdp://ip-10-0-1-100.us-east-1.compute.internal:3389
https://ip-10-0-1-100.us-east-1.compute.internal:8443

# Custom internal DNS (private connectivity)
rdp://john-doe.vdi.internal:3389
https://john-doe.vdi.internal:8443
```

**Prerequisites for DNS names:**
- **VPC DNS hostnames enabled** - `enable_dns_hostnames = true` (included in examples)
- **VPC DNS support enabled** - `enable_dns_support = true` (enabled by default)

**Connection clients automatically resolve these DNS names to the appropriate IP addresses.**

## Deployment Patterns

### Solo Developer Deployment

**When to Use**: Individual developers, prototyping/MVP projects, learning and experimentation

**Benefits**: Lower cost (single instance), simple management, automatic IP detection, fast deployment

### Small Team Deployment

**When to Use**: Teams of 2-10 developers, distributed remote teams, project-based work

**Benefits**: Individual workstation customization, user-specific security, flexible instance sizing, independent scaling

### Enterprise Deployment

**When to Use**: Large teams (10+ developers), corporate environments, compliance requirements

**Benefits**: Private connectivity with VPN, centralized certificate management, policy enforcement, audit capabilities

## Software Installation

The VDI module supports flexible software installation through SSM documents that run after instance launch.

### Available Software Packages

- `"chocolatey"` - Package manager (usually pre-installed)
- `"visual-studio-2022"` - IDE with game development workloads (~45 minutes)
- `"git"` - Version control (usually pre-installed)
- `"unreal-engine-5.3"` - Game engine (~30 minutes)
- `"perforce"` - Game industry VCS (~10 minutes)

### Configuration Example

```hcl
templates = {
  "game-developer" = {
    instance_type = "g4dn.2xlarge"
    software_packages = [
      "chocolatey",
      "visual-studio-2022",
      "git",
      "unreal-engine-5.3"
    ]
  }
}
```

**Total deployment time**: 10-70 minutes depending on software packages selected.

## User Personas

### DevOps Team (Infrastructure Provisioners)

**Responsibilities**: Deploy and manage VDI infrastructure, build AMIs, configure networking

**Access Requirements**: Full AWS account access, Terraform deployment permissions, office/VPN network access

### Game Developers (Service Consumers)

**Responsibilities**: Use VDI workstations for development, install development tools, manage project files

**Access Requirements**: Workstation access only, DCV/RDP client software, Administrator access to assigned workstation

## ⏰ VDI Installation Progress Tracking

**VDI workstations require 5-15 minutes for user creation and basic software, plus 30-60 minutes for large software packages.**

### Installation Timeline:
1. ✅ **Terraform completes** (2-5 minutes) - Infrastructure created
2. ✅ **Users + Basic Software** (5-15 minutes) - Immediate installation via retry scripts
3. ⏳ **Large Software** (30-60 minutes) - Background installation via SSM associations
4. ✅ **VDI fully ready** - All authentication and software functional

### Real-Time Progress Tracking Options

#### **Option 1: For End Users (On VDI Desktop)**

**Auto-Updating Status File:**
- **Location**: Desktop file "VDI Installation Status.txt"
- **Updates**: Every 5 minutes automatically
- **Usage**: Double-click to view current status

**Real-Time Status Script:**
- **Location**: Desktop file "Check VDI Status.ps1"
- **Usage**: 
  ```powershell
  # One-time check
  .\"Check VDI Status.ps1"
  
  # Continuous monitoring (refreshes every 30 seconds)
  .\"Check VDI Status.ps1" -Watch
  ```

**What Users See:**
```
VDI Installation Status - 2024-01-15 10:30:15
==================================================
✅ Users: Ready (3 users created)
   - VDIAdmin (Enabled: True)
   - john-doe (Enabled: True)

✅ Chocolatey: Installed
✅ Git: Installed  
⏳ UnrealEngine: Installing...
⏳ VisualStudio: Installing...

✅ DCV Sessions: Ready
   - john-doe-session (owner: john-doe)

⏳ VDI IN PROGRESS - 2/4 software, 2 users

Last checked: 10:30:15
Refreshing in 30 seconds... (Ctrl+C to stop)
```

#### **Option 2: For Administrators (Terraform Deployers)**

**Real-Time Status Check:**
```bash
# Check current installation status
aws ssm list-command-invocations \
  --instance-id i-0123456789 \
  --query 'CommandInvocations[?contains(Comment,`Immediate`)].{Status:Status,Document:DocumentName,StartTime:RequestedDateTime}' \
  --output table
```

**Output Shows:**
```
Status      Document                    StartTime
Success     setup-dcv-users-sessions    2024-01-15T10:25:00Z
Success     setup-chocolatey           2024-01-15T10:26:00Z  
InProgress  install-git                2024-01-15T10:27:00Z
Failed      install-unreal-engine      2024-01-15T10:28:00Z
```

**For Detailed Error Information:**
```bash
aws ssm get-command-invocation --command-id cmd-123 --instance-id i-123
```

#### **Option 3: AWS Console Monitoring**

**SSM Console:**
- Go to **Systems Manager → Run Command**
- Filter by instance ID to see all command executions
- View real-time status and detailed logs

**CloudWatch Dashboard (Optional):**
```bash
# Create monitoring dashboard
terraform output status_check_commands
# Run the dashboard_command from the output
```

### Status Indicators Explained

- ✅ **Ready**: Component installed and verified
- ⏳ **In Progress**: Installation currently running
- ❌ **Failed**: Installation failed (check logs for details)

### Key Benefits of New Approach

- **Immediate User Access**: Users + basic tools ready in 5-15 minutes
- **Background Large Software**: Unreal Engine, Visual Studio install while you work
- **Real-Time Visibility**: Multiple ways to track progress
- **No More Guessing**: Clear status indicators for every component
- **Deterministic Status**: Know exactly when VDI is fully ready

## Security & Access Patterns

For detailed configuration options and deployment patterns, see the [examples](examples/) directory:

- **Public Access**: Internet-accessible with IP restrictions
- **Private Access**: VPN-only with private DNS and certificate authentication
- **Mixed Access**: Some users public, others private in same deployment

## Known Limitations

### Resource Lifecycle Management

**EC2 Emergency Keys**: When instances are recreated, new private keys overwrite old keys in S3 at the same path. Previous keys are lost and cannot be used to decrypt old Administrator passwords.

**VDIAdmin Secrets**: Managed by SSM scripts rather than Terraform. When instances are destroyed, VDIAdmin secrets remain in Secrets Manager and must be manually cleaned up.

**Impact**: 
- Lost emergency access to previous instance Administrator accounts
- Accumulation of orphaned VDIAdmin secrets over time
- Inconsistent resource lifecycle management

**Workarounds**: 
- For production deployments, enable S3 versioning on the emergency keys bucket to preserve old keys
- Manually delete orphaned VDIAdmin secrets: `aws secretsmanager delete-secret --secret-id cgd/[workstation]/users/vdiadmin`
- Consider using AWS Systems Manager Session Manager for emergency access instead of RDP

**Future**: These limitations will be addressed in a future major version with breaking changes to ensure consistent resource lifecycle management.

## Contributing

See the [Contributing Guidelines](../../../CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../../../LICENSE) file for details.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|------------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.0.5 |

## Providers

| Name | Version |
|------|------------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.5.0 |
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
| [aws_instance.vdi_workstations](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/instance) | resource |
| [aws_key_pair.vdi_key_pairs](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/key_pair) | resource |
| [aws_launch_template.vdi_launch_templates](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/launch_template) | resource |
| [aws_security_group.vdi_default_sg](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/security_group) | resource |
| [aws_ssm_association.configure_dcv_ad_auth](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/ssm_association) | resource |
| [aws_ssm_association.domain_join](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/ssm_association) | resource |
| [aws_ssm_document.configure_dcv_ad_auth](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/ssm_document) | resource |
| [aws_vpc_security_group_egress_rule.vdi_all_outbound](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_ad_dynamic_rpc](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_ad_ports](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_dcv_https](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_dcv_https_additional](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_dcv_quic](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_dcv_quic_additional](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_https](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_https_additional](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_rdp](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vdi_rdp_additional](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [null_resource.create_ad_users](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [tls_private_key.vdi_keys](https://registry.terraform.io/providers/hashicorp/tls/4.0.5/docs/resources/private_key) | resource |
| [aws_ami.windows_server_2025](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/region) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ad_admin_password"></a> [ad\_admin\_password](#input\_ad\_admin\_password) | Directory administrator password | `string` | `""` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | Default CIDR blocks allowed for VDI access (can be overridden per user) | `list(string)` | <pre>[<br/>  "10.0.0.0/16"<br/>]</pre> | no |
| <a name="input_ami_prefix"></a> [ami\_prefix](#input\_ami\_prefix) | AMI name prefix for auto-discovery when ami not specified per user | `string` | `"windows-server-2025"` | no |
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
| <a name="input_user_public_ips"></a> [user\_public\_ips](#input\_user\_public\_ips) | Map of usernames to their public IP addresses for security group access | `map(string)` | `{}` | no |
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