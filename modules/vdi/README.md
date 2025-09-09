# VDI (Virtual Desktop Infrastructure) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **⚠️ CRITICAL WINDOWS DCV LIMITATION**
>
> **Windows DCV supports only ONE console session per instance.** This is an architectural constraint, not a configuration issue. For true multi-user VDI:
> - **Linux DCV**: Supports multiple virtual sessions per instance
> - **Amazon WorkSpaces**: Managed multi-user VDI service
> - **Multiple Windows instances**: One instance per user
>
> **This module implements shared session access** - admins can join user sessions for support, or use RDP for independent access.
>
> **⚠️ AMI REQUIREMENT**
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
- **Active Directory** (Optional) - AWS Managed Microsoft AD for enterprise environments

These version requirements enable the security patterns and multi-user capabilities used throughout this module.

## Features

- **Complete VDI Infrastructure** - Single module deploys EC2 workstations, security groups, IAM roles, and optional Active Directory integration
- **5-Tier VDI Architecture** - Templates, workstations, users, assignments, and software packages for maximum flexibility
- **Multi-Tier Authentication** - EC2 key pairs (break-glass), Secrets Manager (managed), and Active Directory (enterprise)
- **Dual Admin Account Pattern** - Administrator (emergency access) + VDIAdmin (daily operations) for security best practices
- **Security by Default** - Least privilege IAM, encrypted storage, restricted network access with proper security group rules
- **Flexible Team Scaling** - Solo developer to medium team support with role-based workstation assignment
- **Game Development Optimized** - GPU instances, high-performance storage, development tool integration
- **Runtime Software Installation** - 5 predefined packages plus custom scripts via SSM automation
- **Multiple Access Patterns** - Public IP, private DNS, or hybrid access with VPN support
- **Active Directory Integration** - Optional AWS Managed Microsoft AD with automatic user provisioning
- **Amazon DCV Ready** - Pre-configured high-performance remote desktop with QUIC protocol support

## Architecture

**Core Components:**

- **EC2 Workstations**: GPU-enabled instances with game development tools and DCV remote access
- **Secrets Manager**: Automatic password generation and rotation for Administrator accounts
- **Security Groups**: Least privilege network access with user-specific IP restrictions
- **IAM Roles**: SSM permissions for management and optional AWS service access
- **Active Directory**: Optional AWS Managed Microsoft AD for enterprise user management
- **SSM Automation**: Runtime software installation and configuration management
- **S3 Storage**: Custom script hosting and emergency key backup

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

## Authentication Methods

### **Authentication Matrix (Automatic)**

**Authentication method is automatically determined by user configuration:**

| User Type | Admin Accounts | User Accounts | Use Case |
|-----------|----------------|---------------|----------|
| **Local Users** (`user_source = "local"`) | EC2 keys + Secrets Manager | Secrets Manager | Solo developers, small teams (2-10 users) |
| **AD Users** (`user_source = "ad"`) | EC2 keys + Secrets Manager | Active Directory | Enterprise teams (10+ users), compliance |

**Key Benefits:**
- ✅ **No configuration needed** - authentication method inferred from user types
- ✅ **Admin accounts always get both** - EC2 keys (break-glass) + Secrets Manager (convenience)
- ✅ **User accounts follow their type** - local users use Secrets Manager, AD users use AD
- ✅ **Consistent security** - break-glass access always available via EC2 key pairs

### **Local Users (Secrets Manager)**
**Best for**: Teams of 2-10 users, managed environments, automated operations

**Configuration:**
```hcl
users = {
  "john-doe" = {
    given_name  = "John"
    family_name = "Doe"
    email       = "john@company.com"
  }
}

workstation_assignments = {
  "vdi-001" = {
    user        = "john-doe"
    user_source = "local"  # Triggers Secrets Manager authentication
  }
}
```

**Result**: EC2 keys + Secrets Manager for admins, Secrets Manager for users

### **AD Users (Active Directory)**
**Best for**: Teams of 10+ users, corporate environments, compliance requirements

**Configuration:**
```hcl
ad_users = {
  "jane-smith" = {
    given_name       = "Jane"
    family_name      = "Smith"
    email            = "jane@company.com"
    group_membership = ["developers"]
  }
}

workstation_assignments = {
  "vdi-002" = {
    user        = "jane-smith"
    user_source = "ad"  # Triggers Active Directory authentication
  }
}
```

**Result**: EC2 keys + Secrets Manager for admins, Active Directory for users

## Account Creation & Password Management

### **CRITICAL: What Accounts Get Created, When, and Where**

**Every VDI instance automatically gets exactly 3 accounts:**

| Account | Created When | Created Where | Password Storage | Password Rotation | Use Case |
|---------|-------------|---------------|------------------|-------------------|----------|
| **Administrator** | Windows boot | Built-in Windows | EC2 Key Pair (encrypted) | Never (emergency only) | Break-glass emergency access |
| **VDIAdmin** | User data script | Runtime (PowerShell) | Secrets Manager | Manual only | Automation, SSM management |
| **Assigned User** | User data script | Runtime (PowerShell) | Secrets Manager or AD | Automatic on instance replacement | Daily VDI usage |

### **Account Creation Timeline**

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

### **Password Storage Locations**

| Account | Storage Method | Location | Retrieval Method |
|---------|---------------|----------|------------------|
| **Administrator** | EC2 Key Pair | AWS EC2 Service | `aws ec2 get-password-data` + private key |
| **VDIAdmin** | Secrets Manager | `/{project}/workstations/{workstation}/vdiadmin-password` | `aws secretsmanager get-secret-value` |
| **john-doe** | Secrets Manager | `/{project}/users/john-doe` | `aws secretsmanager get-secret-value` |

### **Password Rotation Behavior**

**When Instance is Replaced (AMI updates, instance type changes, etc.):**

| Account | What Happens | Why |
|---------|-------------|-----|
| **Administrator** | NEW password generated | New Windows installation = new built-in account |
| **VDIAdmin** | NEW password generated | Tied to instance lifecycle (random_password keeper) |
| **john-doe** | NEW password generated | Tied to instance lifecycle (random_password keeper) |

**Key Point**: Same private key decrypts NEW Administrator password, but Secrets Manager passwords are completely regenerated.

### **Account Permissions & Groups**

| Account | Local Groups | Capabilities | Admin Rights |
|---------|-------------|-------------|-------------|
| **Administrator** | Administrators, Remote Desktop Users | Full system control | Yes (built-in) |
| **VDIAdmin** | Administrators, Remote Desktop Users | Full system control | Yes (added by script) |
| **john-doe** | Users, Remote Desktop Users | Standard user access | No (regular user) |

### **Why This 3-Account Pattern**

- **Administrator**: Emergency access that always works (Windows built-in, never changes)
- **VDIAdmin**: Managed admin for automation (consistent naming, Secrets Manager)
- **Assigned User**: Individual user account (appropriate auth method: Secrets Manager or AD)

**Security Benefits:**
- ✅ **Separate purposes**: Emergency vs operational vs user access
- ✅ **Clear audit trail**: Different accounts for different access types
- ✅ **Reliability**: Break-glass always available (Administrator)
- ✅ **Flexibility**: Users get appropriate authentication (local or AD)

## Prerequisites

### Required Access & Tools

1. **AWS Account Setup**
   - AWS CLI configured with deployment permissions
   - VPC with public and private subnets
   - Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [Directory Service](https://aws.amazon.com/directoryservice/), [EC2](https://aws.amazon.com/ec2/))

2. **Windows AMI Requirements** (CRITICAL ⚠️)
   - Must build Windows Server 2025 AMI using [Packer template](../../assets/packer/virtual-workstations/windows/README.md)
   - AMI must include DCV, NVIDIA drivers, and development tools
   - Without proper AMI, instance deployment will fail
   - **Choose your Packer approach** - See [Packer Template Options](#packer-template-options) below

3. **Network Planning**
   - User public IP addresses for security group access
   - VPC CIDR planning for internal access
   - Optional: Active Directory integration for enterprise environments

### Software Installation Prerequisites

**For Runtime Software Installation:**
- **S3 Bucket Access** - Module creates bucket for custom script storage
- **SSM Permissions** - Instances need SSM access for software installation
- **Internet Connectivity** - Required for downloading software packages
- **Custom Scripts** - PowerShell scripts for team-specific tools (optional)

## Packer Template Options

**Choose the right Packer template based on your priorities:**

| Factor | **Game-Dev Template** | **Lightweight Template + SSM** |
|--------|----------------------|--------------------------------|
| **Build Time** | 45+ minutes | 20 minutes |
| **Boot Time** | 2-3 minutes | 5-10 minutes |
| **Deployment Speed** | Fast (everything pre-installed) | Slower (installs at runtime) |
| **Flexibility** | Fixed software versions | Choose versions at deployment |
| **Disk Space** | ~150GB (everything included) | ~80GB base + runtime growth |
| **Failure Risk** | High (long build, more points of failure) | Lower build risk, runtime risk instead |
| **Customization** | Rebuild AMI for changes | Change SSM parameters |
| **Cost** | Higher storage costs | Lower storage, higher compute during install |
| **Use Case** | Production workloads, consistent environments | Development, testing, flexible requirements |

### **Choose Game-Dev Template When:**
- **Production VDI environments** - Need maximum reliability and performance
- **Consistent software requirements** - Same tools across all workstations
- **Fast boot times critical** - Users need immediate access
- **Cost of rebuild time acceptable** - Can afford 45+ minute builds for changes

### **Choose Lightweight + SSM When:**
- **Development/testing environments** - Frequent changes and experimentation
- **Flexible software requirements** - Different tools per workstation or project
- **Faster iteration needed** - Want to test AMI changes quickly
- **Variable team needs** - Different users need different software configurations

### **Template Locations:**

**Game-Dev Template (Full Install):**
```bash
cd assets/packer/virtual-workstations/windows/game-dev/
packer build windows-server-2025.pkr.hcl
```

**Lightweight Template (Runtime Install):**
```bash
cd assets/packer/virtual-workstations/windows/lightweight/
packer build windows-server-2025-lightweight.pkr.hcl
```

**Both templates include:**
- ✅ Windows Server 2025 base
- ✅ Amazon DCV remote desktop
- ✅ NVIDIA GRID drivers (GPU instances)
- ✅ PowerShell modules for AWS management
- ✅ SSM agent for remote management

**Game-Dev template additionally includes:**
- ✅ Visual Studio 2022 Community (game dev workloads)
- ✅ Git version control
- ✅ Unreal Engine 5.3 (Epic Games Launcher)
- ✅ Perforce client tools (P4, P4V, P4Admin)
- ✅ Development utilities and tools

**Lightweight template uses runtime installation for:**
- 🔄 Software packages installed via SSM during deployment
- 🔄 Configurable software versions per workstation
- 🔄 Optional software based on user requirements

**Recommendation:** Use **lightweight** for maximum flexibility, or **specialized** templates for faster deployment of known configurations.

### Active Directory Integration (Advanced)

**This module focuses on local user management with Secrets Manager.** All AMIs are pre-configured with Active Directory management tools for users who want to integrate with existing AD infrastructure.

#### **AD-Ready Components (Pre-installed in all AMIs):**
- ✅ **RSAT-AD-PowerShell** - Active Directory PowerShell module
- ✅ **AD Users & Computers** - GUI management tools
- ✅ **DNS management tools** - For domain integration
- ✅ **Domain join capability** - Windows Server 2025 native support
- ✅ **DCV system authentication** - Works with domain accounts

#### **User-Managed AD Integration:**

For Active Directory integration, users can:

1. **Deploy VDI module** with local users (gets AD-ready instances)
2. **Set up Active Directory** separately (AWS Managed AD, on-premises, etc.)
3. **Domain join instances** using standard Windows/AWS tools:
   ```powershell
   # Via PowerShell on instance
   Add-Computer -DomainName "company.local" -Credential (Get-Credential)
   
   # Via AWS SSM from anywhere
   aws ssm send-command --document-name "AWS-JoinDirectoryServiceDomain" \
     --parameters "directoryId=d-123,directoryName=company.local"
   ```
4. **Manage AD users** with pre-installed tools:
   ```powershell
   # AD PowerShell module is pre-installed and auto-imported
   New-ADUser -Name "john-doe" -GivenName "John" -Surname "Doe"
   Add-ADGroupMember -Identity "Remote Desktop Users" -Members "john-doe"
   ```
5. **Create DCV sessions** for domain users:
   ```powershell
   dcv create-session --owner "COMPANY\john-doe" john-session
   ```

#### **Why Separate AD Management?**

- ✅ **Flexibility** - Works with any AD setup (AWS Managed AD, on-premises, hybrid)
- ✅ **Simplicity** - VDI module focuses on infrastructure, not identity management
- ✅ **Enterprise compatibility** - Integrates with existing AD infrastructure
- ✅ **Cost control** - Users choose their AD approach and costs

**Note:** Future versions may include IAM Identity Center integration for enhanced SSO capabilities.

### AMI Management and Updates

#### **Using New AMIs with Existing Deployments**

**After building a new AMI, update your VDI deployment:**

**Option 1: Auto-discovery (uses data source to find latest AMI)**
```hcl
module "vdi" {
  ami_prefix = "vdi-lightweight-windows-server-2025"  # Finds latest matching AMI
}
```

**Option 2: Specific AMI ID (recommended for production)**
```hcl
module "vdi" {
  # ami = "ami-0d22cd2c73f6b623"  # Use specific AMI ID from Packer output
}
```

**Force instance recreation with new AMI:**
```bash
# Taint instances to force recreation
terraform taint 'module.vdi.aws_instance.workstations["vdi-001"]'
terraform taint 'module.vdi.aws_instance.workstations["vdi-002"]'

# Apply to recreate with new AMI
terraform apply
```

**⚠️ Warning:** Tainting instances will destroy and recreate them. Ensure users save their work first.

#### **Building Custom AMIs**

**⚠️ IMPORTANT: You must clone the entire CGD Toolkit repository to build AMIs**

Packer templates use shared infrastructure scripts and cannot be used standalone without customization.

**Required Setup:**
```bash
# Clone the complete repository
git clone https://github.com/aws-games/cloud-game-development-toolkit.git
cd cloud-game-development-toolkit
```

**Template Locations:**

```bash
# Lightweight AMI (base tools only)
cd assets/packer/virtual-workstations/lightweight/
packer build windows-server-2025-lightweight.pkr.hcl

# UE GameDev AMI (full development stack)  
cd assets/packer/virtual-workstations/ue-gamedev/
packer build windows-server-2025-ue-gamedev.pkr.hcl

# Artists AMI (creative tools) - Coming Soon
# cd assets/packer/virtual-workstations/artists/
```

**All templates include shared base infrastructure:**
- ✅ Windows Server 2025 base
- ✅ Amazon DCV remote desktop  
- ✅ NVIDIA GRID drivers (GPU instances)
- ✅ AWS CLI and PowerShell modules
- ✅ Git, Perforce, Python, Chocolatey
- ✅ **Active Directory management tools** (RSAT-AD-PowerShell, AD Users & Computers)
- ✅ **Domain join ready** (all tools pre-installed for AD integration)

### VDI Customization Strategy

**VDI instances are customized through a 3-step process:**

#### **Step 1: Choose Your AMI**

**Option A: Lightweight AMI (Recommended for Flexibility)**
- **Base tools:** Windows Server 2025 + DCV + AWS CLI + Git + Perforce + Python + Chocolatey
- **Software installed:** Via runtime `software_packages` configuration
- **Boot time:** ~3-5 minutes + software installation time
- **Use case:** Development, testing, flexible requirements

**Option B: Purpose-Built AMIs (Fast Boot)**
- **[UE GameDev AMI](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/assets/packer/virtual-workstations/ue-gamedev)** - Includes Visual Studio + Unreal Engine
- **[Artists AMI](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/assets/packer/virtual-workstations/artists)** - Includes creative tools (planned)
- **Boot time:** ~2-3 minutes (software pre-installed)
- **Use case:** Production environments, stable requirements

#### **Step 2: Define Templates (Reusable Configurations)**

```hcl
templates = {
  "developer" = {
    instance_type = "g4dn.xlarge"
    software_packages = ["visual-studio-2022", "unreal-engine-5.3"]
    volumes = {
      "Root" = { capacity = 100, type = "gp3" }
      "Projects" = { capacity = 500, type = "gp3", windows_drive = "D:" }
    }
  }
  "artist" = {
    instance_type = "g4dn.2xlarge"
    software_packages = ["blender", "maya", "photoshop"]
    volumes = {
      "Root" = { capacity = 100, type = "gp3" }
      "Assets" = { capacity = 1000, type = "gp3", windows_drive = "D:" }
    }
  }
}
```

#### **Step 3: Assign Workstations to Users**

```hcl
workstation_assignments = {
  "vdi-001" = {
    user = "john-doe"
    template_key = "developer"  # References template above
  }
  "vdi-002" = {
    user = "jane-artist"
    template_key = "artist"     # References template above
  }
}
```

#### **Available Runtime Software Packages:**
- `"chocolatey"` - Package manager (usually pre-installed)
- `"git"` - Version control (usually pre-installed)
- `"perforce"` - Game industry VCS (usually pre-installed)
- `"visual-studio-2022"` - IDE with game development workloads
- `"unreal-engine-5.3"` - Game engine
- `"blender"` - 3D modeling and animation
- `"maya"` - Professional 3D software

#### **Software Conflict Handling:**

**If AMI already includes software you're trying to install:**
- **Chocolatey packages:** Usually skip if already installed
- **Manual installers:** May fail or reinstall
- **Best practice:** Use lightweight AMI + runtime packages for maximum control

**Example conflict scenarios:**
```hcl
# ❌ Potential conflict: UE GameDev AMI already has Visual Studio
templates = {
  "developer" = {
    software_packages = ["visual-studio-2022"]  # May conflict with pre-installed version
  }
}

# ✅ Better approach: Use lightweight AMI or omit conflicting packages
templates = {
  "developer" = {
    software_packages = ["unreal-engine-5.3"]  # Only install what's not in AMI
  }
}
```

### Getting User Public IP Addresses

Before deployment, collect each user's public IP address:

- **Current IP**: Visit `https://checkip.amazonaws.com/` or run `curl https://checkip.amazonaws.com/`
- **Office Network**: Get the office public IP from your network administrator
- **Home Users**: Each user should check their home public IP
- **Static IPs**: Use static IPs if available from ISP

**Terraform Automation**: The module examples show how to automatically fetch your current IP using a Terraform data source, eliminating manual IP collection for solo developers.

**Note**: The security groups will allow access from both the specified public IP and the VPC CIDR block for maximum flexibility.

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples). They provide a good reference for not only the ways to declare and customize the module configuration, but how to provision and reference the infrastructure mentioned in the prerequisites. As mentioned earlier, we avoid creating infrastructure that is more general (e.g. VPCs, Subnets, Security Groups, etc.) as this can be highly nuanced. All examples show sample configurations of these resources created external to the module, but please customize based on your own needs.

This module provides examples organized by team size and access patterns:

**Available Examples:**

- **[Local Only](examples/local-only/)** - Demonstrates 5-tier architecture with local user authentication, templates, inheritance, and software packages
- **[Managed AD](examples/managed-ad/)** - Active Directory integration with AWS Managed Microsoft AD for enterprise environments

Each example includes complete Terraform configuration with VPC setup, security groups, and detailed connection instructions.

## ⏰ IMPORTANT: Initial Setup Timing

**VDI workstations require 15-30 minutes to become fully functional after deployment.**

### What happens during deployment:
1. ✅ **Terraform completes** (2-5 minutes) - Infrastructure created
2. ⏳ **SSM setup begins** (5-30 minutes) - User accounts and software installation
3. ✅ **VDI ready** - All authentication and software functional

### For immediate setup (development/testing):
```bash
# Get association IDs and trigger immediately
aws ssm start-associations-once --association-ids $(aws ssm describe-associations --query 'Associations[?contains(Name, `cgd-dev-setup-dcv-users-sessions`)].AssociationId' --output text)
```

### Check setup status:
```bash
aws ssm list-command-invocations --instance-id [INSTANCE_ID] --max-results 5
```

**This is normal AWS SSM behavior** - associations execute on AWS's schedule (5-30 minutes) for reliability. The manual trigger provides immediate execution when needed for development/testing.

## Deployment Instructions

### Step 1: Declare and configure the module

Note, this is just a condensed sample. See the examples for the related required infrastructure.

**5-Tier Architecture Example**

```terraform
module "vdi" {
  source = "../../"

  # Core Configuration
  project_prefix = "cgd"
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Tier 1: Templates (Reusable Configurations)
  templates = {
    "ue-developer" = {
      instance_type = "g4dn.2xlarge"
      gpu_enabled   = true
      software_packages = [
        "chocolatey",
        "visual-studio-2022",
        "git",
        "unreal-engine-5.3"
      ]
      # custom_scripts = ["scripts/setup-team-tools.ps1"]  # Add your own scripts here
      volumes = {
        Root = { capacity = 256, type = "gp3" }
        Projects = { capacity = 1024, type = "gp3" }
      }
    }
  }

  # Tier 2: Workstations (Infrastructure Placement)
  workstations = {
    "alice-workstation" = {
      template_key = "ue-developer"  # Inherits from template
      subnet_id = aws_subnet.private_subnets[0].id
      availability_zone = "us-east-1a"
    }
    "bob-workstation" = {
      template_key = "ue-developer"
      subnet_id = aws_subnet.private_subnets[1].id
      availability_zone = "us-east-1b"
      # Override template settings
      software_packages_additions = ["perforce"]
      software_packages_exclusions = ["unreal-engine-5.3"]
    }
  }

  # Tier 3: Users (Authentication & Identity)
  users = {
    "alice" = {
      given_name = "Alice"
      family_name = "Smith"
      email = "alice@company.com"
    }
    "bob" = {
      given_name = "Bob"
      family_name = "Jones"
      email = "bob@company.com"
    }
  }

  # Tier 4: Assignments (User-to-Workstation Mapping)
  workstation_assignments = {
    "alice-assignment" = {
      user = "alice"
      workstation = "alice-workstation"
      user_source = "local"
    }
    "bob-assignment" = {
      user = "bob"
      workstation = "bob-workstation"
      user_source = "local"
    }
  }

  # Security Configuration
  allowed_cidr_blocks = [data.http.my_ip.response_body + "/32"]
}
```

### Step 2: Deploy Infrastructure

> **⚠️ IMPORTANT**
>
> Ensure you have built the required Windows AMI using Packer before deployment. Without a properly configured AMI, instance deployment will fail.

```sh
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs for connection details
# terraform output vdi_connection_info
```

## Verification & Testing

### Quick Verification Steps

**1. Check instance status:**

```bash
# Verify instances are running
aws ec2 describe-instances --filters "Name=tag:Project,Values=cgd" --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],State:State.Name,IP:PublicIpAddress}'
```

**2. Test RDP connectivity:**

```bash
# Test RDP port (Windows)
telnet <instance-public-ip> 3389

# Test RDP port (Linux/macOS)
nc -zv <instance-public-ip> 3389
```

**3. Test DCV connectivity:**

```bash
# Test DCV port
nc -zv <instance-public-ip> 8443
```

### **Password Lifecycle During Instance Replacement**

**CRITICAL BEHAVIOR**: When instances are replaced, ALL passwords change but access methods stay the same.

**What Happens:**
```
Old Instance Destroyed
         ↓
New Instance Created (same AMI, new Windows installation)
         ↓
Administrator: NEW password (decrypt with SAME private key)
VDIAdmin: NEW password (stored in SAME Secrets Manager location)
john-doe: NEW password (stored in SAME Secrets Manager location)
         ↓
All accounts work immediately with new passwords
```

**User Impact:**
- ✅ **Same retrieval methods work** (same commands, same locations)
- ✅ **No configuration changes needed** (same Secrets Manager ARNs)
- ✅ **Automatic password updates** (tied to instance lifecycle)
- ⚠️ **Must get new passwords** (old passwords won't work)

**Why Passwords Must Regenerate:**
- New Windows installation = completely new user accounts
- Old passwords belong to destroyed Windows accounts
- Automatic regeneration ensures immediate access to new accounts

### **Password Retrieval by Account Type**

**⚠️ IMPORTANT: Each account type has different retrieval methods**

**Method 1: Terraform Output (Primary)**

```bash
# 1. List available workstations
terraform output -json vdi_connection_info | jq 'keys[]'

# 2. Set your workstation name (replace with your actual workstation key)
WORKSTATION_NAME="my-workstation"  # Change this to your workstation name

# 3. Get private key and decrypt Windows password
terraform output -json private_keys | jq -r ".\"$WORKSTATION_NAME\"" > temp_key.pem
chmod 600 temp_key.pem

# 4. Decrypt Administrator password
aws ec2 get-password-data \
  --instance-id $(terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") \
  --priv-launch-key temp_key.pem \
  --query 'PasswordData' \
  --output text

# 5. Clean up temporary key file
rm temp_key.pem
```

**Method 2: S3 Backup Key (If Terraform fails)**

```bash
# 1. Find your S3 bucket name
terraform output -json | grep emergency-keys

# 2. Set your workstation and bucket names
WORKSTATION_NAME="my-workstation"  # Change this to your workstation name
BUCKET_NAME="cgd-vdi-emergency-keys-xxxxx"  # From step 1

# 3. Download backup private key from S3
aws s3 cp s3://$BUCKET_NAME/emergency-keys/$WORKSTATION_NAME/cgd-dev-$WORKSTATION_NAME-private-key.pem ./backup-key.pem
chmod 600 backup-key.pem

# 4. Decrypt Administrator password with backup key
aws ec2 get-password-data \
  --instance-id $(terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") \
  --priv-launch-key backup-key.pem \
  --query 'PasswordData' \
  --output text

# 5. Clean up backup key file
rm backup-key.pem
```

**One-liner version (Method 1):**
```bash
WORKSTATION_NAME="my-workstation" && terraform output -json private_keys | jq -r ".\"$WORKSTATION_NAME\"" > temp_key.pem && chmod 600 temp_key.pem && aws ec2 get-password-data --instance-id $(terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") --priv-launch-key temp_key.pem --query 'PasswordData' --output text && rm temp_key.pem
```

**Method 3: Get VDIAdmin Password (Secrets Manager)**

```bash
# Get VDIAdmin password
WORKSTATION_NAME="my-workstation"
PROJECT_PREFIX="cgd"  # Your project prefix

aws secretsmanager get-secret-value \
  --secret-id "$PROJECT_PREFIX/workstations/$WORKSTATION_NAME/vdiadmin-password" \
  --query SecretString --output text | jq -r '.password'
```

**Method 4: Get User Password (Secrets Manager)**

```bash
# Get assigned user password (john-doe)
USER_NAME="john-doe"
PROJECT_PREFIX="cgd"  # Your project prefix

aws secretsmanager get-secret-value \
  --secret-id "$PROJECT_PREFIX/users/$USER_NAME" \
  --query SecretString --output text | jq -r '.password'
```

### Connection Testing

**RDP Connection (Windows):**

1. Open Remote Desktop Connection
2. Enter instance public IP or DNS name
3. Use Administrator username and retrieved password
4. Connect and verify desktop loads

**DCV Connection (All Platforms):**

1. Download [DCV Client](https://download.nice-dcv.com/)
2. Connect to `https://<instance-ip>:8443`
3. Use Administrator credentials
4. Verify high-performance desktop experience

## Active Directory Integration

### **How AD Integration Works**

**The VDI module provides flexible AD integration:**

1. **Optional at deployment** - Set `enable_ad_integration = true/false`
2. **Can be added later** - Domain join existing instances via SSM
3. **Automatic user management** - Creates AD users and adds to groups
4. **RSAT tools included** - GUI management from any domain-joined instance

### **AD Integration Modes**

#### **Mode 1: No AD (Default)**
```hcl
module "vdi" {
  source = "./modules/vdi"
  
  enable_ad_integration = false  # Set in module block
  
  workstation_assignments = {
    "developer-workstation" = {
      user        = "developer"
      user_source = "local"  # Local authentication only
    }
  }
}
```
**Result**: Local Windows accounts only (Administrator, VDIAdmin, assigned user)

#### **Mode 2: Full AD Integration**
```hcl
module "vdi" {
  source = "./modules/vdi"
  
  enable_ad_integration = true           # Set in module block
  directory_id         = "d-1234567890"  # Your Managed AD
  directory_name       = "corp.company.com"
  
  ad_users = {
    "john-doe" = {
      given_name = "John"
      family_name = "Doe"
      email = "john@company.com"
    }
  }
  
  workstation_assignments = {
    "developer-workstation" = {
      user        = "john-doe"
      user_source = "ad"  # Domain authentication
    }
  }
}
```
**Result**: Domain-joined instance + AD users + local admin accounts

### **AD User and Group Management**

**When `enable_ad_integration = true`, the module automatically:**

1. **Creates AD Users** (if `manage_ad_users = true`)
   ```
   john-doe@corp.company.com
   jane-smith@corp.company.com
   ```

2. **Creates AD Groups**
   ```
   VDI-Admins          # For VDI administrative access
   VDI-Users           # For regular VDI users
   Domain Admins       # Built-in AD group (exists by default)
   ```

3. **Assigns Group Memberships**
   ```
   Administrator → Domain Admins + VDI-Admins
   VDIAdmin     → VDI-Admins
   john-doe     → VDI-Users
   ```

### **Domain Admin vs VDI Admin**

**Two levels of administrative access:**

| Account Type | Scope | Can Manage | RSAT Access |
|--------------|-------|------------|-------------|
| **Domain Admins** | Entire AD domain | All AD users, computers, policies | Full AD management |
| **VDI-Admins** | VDI instances only | VDI-specific resources | Limited AD management |
| **VDI-Users** | Assigned workstation | Own workstation only | No AD management |

### **RSAT Tools Access Control**

**RSAT respects AD permissions automatically:**

```powershell
# Domain Admin can manage everything
Import-Module ActiveDirectory
Get-ADUser -Filter *  # Shows all domain users
New-ADUser -Name "newuser" -Enabled $true  # Can create users

# VDI-Admin has limited permissions
Get-ADUser -Filter *  # Shows users they have permission to see
New-ADUser -Name "newuser"  # May fail (insufficient permissions)

# Regular user has no AD management access
Get-ADUser -Filter *  # Access denied
```

### **Adding AD Integration Later**

**If you deployed without AD initially, you can add it:**

1. **Update Terraform configuration:**
   ```hcl
   enable_ad_integration = true
   directory_id = "d-1234567890"
   ```

2. **Apply changes:**
   ```bash
   terraform apply
   ```

3. **Domain join existing instances:**
   ```bash
   # Via SSM Run Command
   aws ssm send-command --instance-ids i-1234567890abcdef0 \
     --document-name "AWS-JoinDirectoryServiceDomain" \
     --parameters directoryId=d-1234567890,directoryName=corp.company.com
   ```

### **Manual AD Management (AWS Console)**

**You can also manage AD users manually:**

1. **AWS Console** → Directory Service → Your directory → "User management"
2. **Create users** and assign to groups
3. **RSAT tools** will see these users automatically
4. **VDI module** will recognize existing AD users

**Group naming requirements:**
- **Domain Admins** - Exact name required (built-in AD group)
- **VDI-Admins** - Custom group (module creates if doesn't exist)
- **VDI-Users** - Custom group (module creates if doesn't exist)

### **Authentication Flow**

**For domain-joined instances:**

```
User connects to DCV → Windows login screen
                    ↓
            Enter credentials:
            • CORP\john-doe
            • john-doe@corp.company.com  
            • john.doe (if on domain)
                    ↓
            Windows validates against Managed AD
                    ↓
            DCV session starts with domain user context
```

**For RSAT management:**

```
Admin opens "Active Directory Users and Computers"
                    ↓
            Connects to: corp.company.com
                    ↓
            Uses current domain credentials
                    ↓
            Shows/manages users based on AD permissions
```

## Amazon DCV Session Management

> **📖 For complete DCV setup and configuration guidance, see the [Amazon DCV Documentation](https://docs.aws.amazon.com/dcv/).**

### **CRITICAL: Windows vs Linux DCV Architecture**

**Windows DCV Limitation**: 
- **ONE console session per Windows instance** (architectural constraint)
- **Multiple users can SHARE the same session** (collaboration model)
- **Cannot create multiple independent sessions** (unlike Linux)

**Linux DCV Capability**:
- **Multiple virtual sessions per Linux instance** (true multi-user)
- **Each user gets independent desktop** (isolation model)
- **Scales to many users per instance** (cost-effective)

**This module implements the Windows shared session model** with admin collaboration capabilities.

```powershell
# ✅ CORRECT: One session per Windows user account
dcv create-session --owner=Administrator administrator-session
dcv create-session --owner=VDIAdmin vdiadmin-session  
dcv create-session --owner=john-doe john-doe-session

# ❌ WRONG: Multiple sessions for same user (will fail)
dcv create-session --owner=Administrator admin-session
dcv create-session --owner=Administrator another-session  # FAILS!
```

### **Session vs Session Shares**
- **Session**: The actual desktop environment (only 1 per Windows user)
- **Session Share**: Permission to connect to an existing session (unlimited)

### **VDI Module Session Strategy**

**Boot-Time Session Creation** (via User Data):
```powershell
# Creates one session per user account on each VDI instance:
dcv create-session --owner=Administrator administrator-session
dcv create-session --owner=VDIAdmin vdiadmin-session  
dcv create-session --owner=john-doe john-doe-session
dcv create-session --owner=DomainAdmin domainadmin-session  # If AD enabled

# Admin fleet access (if enable_admin_fleet_access = true)
dcv share-session --user Administrator --permissions=full john-doe-session
dcv share-session --user VDIAdmin --permissions=full john-doe-session
dcv share-session --user DomainAdmin --permissions=full john-doe-session
```

### **Session Ownership & Permissions Matrix**

| Account | Session Owner | Can Create Sessions | Can Share Sessions | Fleet Access |
|---------|---------------|-------------------|-------------------|-------------|
| **Administrator** | ✅ administrator-session | ✅ Any session | ✅ Own sessions | ✅ All VDI instances |
| **VDIAdmin** | ✅ vdiadmin-session | ✅ User sessions | ✅ Own sessions | ✅ All VDI instances |
| **DomainAdmin** | ✅ domainadmin-session | ✅ AD user sessions | ✅ Own sessions | ✅ All VDI instances |
| **john-doe** | ✅ john-doe-session | ✅ Own session only | ✅ Own session only | ❌ Instance-specific |

### **DCV Session Management Variables**

```hcl
# Control admin fleet access
enable_admin_fleet_access = true  # Default: true

# Session permission configuration
dcv_session_permissions = {
  admin_default_permissions = "full"  # "view" or "full"
  user_can_share_session   = false   # Allow users to share their sessions
  auto_create_user_session = true    # Create session for assigned user at boot
}
```

### **Session Selection in DCV Client**

**DCV Web Interface Flow:**
```
User connects to: https://vdi-instance:8443

Login page appears:
┌─────────────────────────────┐
│ Username: john-doe          │
│ Password: ********          │
│ [Login]                     │
└─────────────────────────────┘

After login, session list appears:
┌─────────────────────────────┐
│ Available Sessions:         │
│ ○ john-doe-session          │ ← User's own session
│ ○ administrator-session     │ ← Shared admin session (if granted)
│ [Connect]                   │
└─────────────────────────────┘
```

### **Session Management Scenarios**

#### **Scenario 1: Normal User Access**
```powershell
# User connects to their own session
# URL: https://vdi-instance:8443
# Login: john-doe / password
# Selects: john-doe-session
```

#### **Scenario 2: Admin Troubleshooting (User Present)**
```powershell
# Admin joins user's existing session (both can see/control)
dcv share-session --user Administrator --permissions=full john-doe-session

# Admin connects to same session
# URL: https://vdi-instance:8443  
# Login: Administrator / password
# Selects: john-doe-session (shared)

# Both user and admin can control simultaneously
# User sees admin helping (transparency)
```

#### **Scenario 3: Admin Needs Privacy**
```powershell
# Temporarily remove user access
dcv unshare-session --user john-doe john-doe-session

# Admin works alone on user's session
# Re-share when done
dcv share-session --user john-doe --permissions=full john-doe-session
```

#### **Scenario 4: Emergency Admin Access**
```powershell
# Admin uses their own session for sensitive work
# URL: https://vdi-instance:8443
# Login: Administrator / password  
# Selects: administrator-session

# Or creates emergency session (kills user session on Windows)
dcv close-session john-doe-session
dcv create-session --owner=Administrator emergency-session
```

### **RDP vs DCV Coexistence**

**YES** - Different protocols can run simultaneously:
```powershell
# DCV session (GPU-accelerated, port 8443)
dcv create-session --owner=Administrator vdi-session

# RDP session (separate, port 3389) 
# Admin can RDP as VDIAdmin while user uses DCV as john-doe
```

**Multi-Account Strategy:**
```
Administrator → DCV session owner + RDP access
VDIAdmin     → RDP access only (admin tasks)
john-doe     → DCV session share only (daily work)
```

### **Session Management Commands**

**Run via SSM Session Manager** (no RDP needed):
```bash
# Connect to instance
aws ssm start-session --target i-1234567890abcdef0

# Then run DCV commands in PowerShell
```

**Common DCV Commands:**
```powershell
# List all sessions
dcv list-sessions

# Create session
dcv create-session --owner=john-doe john-doe-session

# Share session with admin (troubleshooting)
dcv share-session --user Administrator --permissions=full john-doe-session

# Remove admin access (restore privacy)
dcv unshare-session --user Administrator john-doe-session

# Close session
dcv close-session john-doe-session

# Check session permissions
dcv list-permissions john-doe-session
```

**Automation via SSM Run Command:**
```bash
# Share user session with admin across fleet
aws ssm send-command --instance-ids i-1234567890abcdef0 \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["dcv share-session --user Administrator --permissions=full john-doe-session"]'
```

### **Session Naming Convention**

**Pattern**: `{username}-session`

**Examples:**
- `administrator-session` - Break-glass admin session
- `vdiadmin-session` - Automation admin session  
- `john-doe-session` - End user session
- `domainadmin-session` - Domain admin session (if AD enabled)

### **Fleet Management at Scale**

**Instance Targeting:**
```bash
# Target specific instance via Instance ID
aws ssm start-session --target i-1234567890abcdef0

# Target by tags (all VDI instances)
aws ec2 describe-instances --filters "Name=tag:VDI-User,Values=john-doe"

# Bulk session operations
aws ssm send-command --targets "Key=tag:Project,Values=cgd-vdi" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["dcv list-sessions"]'
```

**Admin Fleet Access Control:**
```hcl
# Enable admins to access ALL VDI instances (default)
enable_admin_fleet_access = true

# Disable for instance-specific access only
enable_admin_fleet_access = false
```

### **Session Security & Permissions**

**Permission Levels:**
```powershell
# View only (can see, cannot control)
dcv share-session --user john-doe --permissions=view administrator-session

# Full control (can control desktop)  
dcv share-session --user john-doe --permissions=full administrator-session

# Default if not specified: FULL permissions
dcv share-session --user john-doe administrator-session  # Defaults to full
```

**Security Best Practices:**
- **User sessions**: Owned by end users, shared with admins for support
- **Admin sessions**: Owned by admins, not shared with users
- **Emergency access**: Administrator can always override (session owner)
- **Audit trail**: All session operations logged in Windows Event Log

### **Troubleshooting DCV Sessions**

#### **"No Sessions Available" Error**
**Cause**: Session doesn't exist or wrong ownership

**Solution**:
```powershell
# Check existing sessions
dcv list-sessions

# Create missing session
dcv create-session --owner=john-doe john-doe-session

# Fix ownership (close and recreate)
dcv close-session console
dcv create-session --owner=Administrator administrator-session
```

#### **Session Won't Start**
**Cause**: DCV service issues or display driver problems

**Solution**:
```powershell
# Check DCV service
Get-Service dcvserver
Restart-Service dcvserver -Force

# Check display drivers (GPU vs virtual)
Get-WmiObject Win32_VideoController | Select-Object Name, Status

# Check DCV logs
Get-Content "C:\ProgramData\NICE\DCV\log\server.log" -Tail 50
```

#### **Authentication Failed**
**Cause**: Wrong credentials or account issues

**Solution**:
```powershell
# Check account status
net user Administrator

# Unlock account if needed
net user Administrator /active:yes

# For domain accounts, use proper format:
# DOMAIN\username or username@domain.com
```

### **Packer vs Runtime Session Creation**

**❌ OLD APPROACH (Packer creates sessions)**:
```powershell
# Packer template creates session during AMI build
dcv create-session --owner=Administrator admin-console
# Problem: Session owned by temporary Packer user
```

**✅ NEW APPROACH (Runtime creates sessions)**:
```powershell
# Packer: Install DCV service only (no sessions)
Set-Service -Name dcvserver -StartupType Automatic

# User Data: Create sessions for actual users
dcv create-session --owner=Administrator administrator-session
dcv create-session --owner=john-doe john-doe-session
```

**Benefits of Runtime Session Creation:**
- **Proper ownership**: Sessions owned by actual user accounts
- **Clean AMIs**: No session state pollution in AMI
- **Flexible assignment**: Sessions created based on workstation assignment
- **Admin sharing**: Automatic fleet access configuration

## Client Connection Guide

### Amazon DCV Client Setup

**1. Download DCV Client:**

Download the appropriate DCV client for your operating system from [https://download.nice-dcv.com/](https://download.nice-dcv.com/)

- **Windows**: DCV Client for Windows
- **macOS**: DCV Client for macOS  
- **Linux**: DCV Client for Linux

**2. Connection Configuration:**

```
Server: https://<workstation-ip>:8443
Username: Administrator (or assigned user)
Password: <from-secrets-manager>
```

**3. Performance Optimization:**

- Enable hardware acceleration in DCV client
- Use wired connection for best performance
- Configure quality settings based on bandwidth

### Remote Desktop Protocol (RDP)

**Windows Built-in RDP:**

1. Open Remote Desktop Connection (mstsc)
2. Enter workstation IP address
3. Use Administrator credentials
4. Save connection for future use

**Third-party RDP Clients:**

- **macOS**: Microsoft Remote Desktop
- **Linux**: Remmina, FreeRDP
- **Mobile**: RD Client (iOS/Android)

## Troubleshooting

### Common Issues

#### 1. Instance Launch Failures

**Symptoms**: Instances fail to start, "AMI not found" errors

**Solutions**:

1. Verify Windows AMI exists: `aws ec2 describe-images --owners self --filters "Name=name,Values=cgd-windows-server-2025-*"`
2. Check AMI is in correct region
3. Ensure Packer build completed successfully
4. Verify AMI has required tags

#### 2. Connection Timeouts

**Symptoms**: RDP/DCV connections timeout or refuse

**Solutions**:

1. Check security group allows your IP: `curl https://checkip.amazonaws.com/`
2. Verify instance is running: `aws ec2 describe-instances`
3. Check Windows firewall settings via SSM
4. Ensure DCV service is running

#### 3. Password Retrieval Issues

**Symptoms**: Cannot access Secrets Manager passwords

**Solutions**:

1. Verify IAM permissions for Secrets Manager
2. Check secret exists: `aws secretsmanager list-secrets`
3. Ensure secret is in correct region
4. Wait for password generation to complete

### Debug Commands

```bash
# Check current IP
curl https://checkip.amazonaws.com/

# List VDI instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=cgd"

# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id>

# Connect via SSM (if configured)
aws ssm start-session --target <instance-id>

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>
```

## User Personas

### DevOps Team (Infrastructure Provisioners)

**Responsibilities:**

- Deploy and manage VDI infrastructure
- Build and maintain Windows AMIs
- Configure networking and security
- Handle user access and permissions
- Monitor infrastructure health

**Access Requirements:**

- Full AWS account access
- Terraform deployment permissions
- AMI building capabilities
- Office/VPN network access

### Game Developers (Service Consumers)

**Responsibilities:**

- Use VDI workstations for development
- Install and configure development tools
- Manage project files and assets
- Report performance issues

**Access Requirements:**

- Workstation access only (not backend infrastructure)
- DCV/RDP client software
- Administrator access to assigned workstation

## Deployment Patterns

### Solo Developer Deployment

**When to Use:**

- Individual developers
- Prototyping/MVP projects
- Learning and experimentation
- Budget-conscious deployments

**Benefits:**

- Lower cost (single instance)
- Simple management
- Automatic IP detection
- Fast deployment

### Small Team Deployment

**When to Use:**

- Teams of 2-10 developers
- Distributed remote teams
- Project-based work
- Mixed skill levels (dev/art/design)

**Benefits:**

- Individual workstation customization
- User-specific security
- Flexible instance sizing
- Independent scaling

### Enterprise Deployment

**When to Use:**

- Large teams (10+ developers)
- Corporate environments
- Compliance requirements
- Centralized user management

**Benefits:**

- Active Directory integration
- Centralized authentication
- Policy enforcement
- Audit capabilities

## Security & Access Patterns

For detailed configuration options and deployment patterns, see the [examples](examples/) directory:

- **Public Access**: Internet-accessible with IP restrictions
- **Private Access**: VPN-only with private DNS
- **Hybrid Access**: Both public and private access available
- **Active Directory**: Enterprise authentication and authorization

### VDI Connection Methods

**AWS provides built-in DNS resolution for all EC2 instances - no custom DNS setup required.**

#### Public Access (Internet)
```bash
# Direct IP connection
rdp://54.123.45.67:3389
https://54.123.45.67:8443

# AWS public DNS (automatic)
rdp://ec2-54-123-45-67.us-east-1.compute.amazonaws.com:3389
https://ec2-54-123-45-67.us-east-1.compute.amazonaws.com:8443
```

#### Private Access (VPN/VPC)
```bash
# Direct private IP connection
rdp://10.0.1.100:3389
https://10.0.1.100:8443

# AWS private DNS (automatic)
rdp://ip-10-0-1-100.us-east-1.compute.internal:3389
https://ip-10-0-1-100.us-east-1.compute.internal:8443
```

**Prerequisites for DNS names:**
- **VPC DNS hostnames enabled** - `enable_dns_hostnames = true` (included in examples)
- **VPC DNS support enabled** - `enable_dns_support = true` (enabled by default)

**Connection clients automatically resolve these DNS names to the appropriate IP addresses.**

## Centralized Logging

### Overview

The VDI module provides centralized logging with a simple on/off switch. All logs flow to a single log group for easy management and dashboard creation.

### Configuration

#### Enable Logging (Recommended)
```hcl
enable_centralized_logging = true
log_retention_days         = 30  # Optional, defaults to 30 days
```

#### Disable Logging
```hcl
enable_centralized_logging = false
```

### Where to Find Logs

**CloudWatch Log Group:**
- Navigate to CloudWatch → Log Groups
- Search for: `/cgd/vdi/logs`
- Contains all VDI logs: SSM execution, software installation, user management, DCV sessions

### Log Stream Examples

```
ssm-execution-i-1234567890abcdef0-2024-01-15-10-30-00    # SSM command execution
software-install-i-1234567890abcdef0-2024-01-15-10-45-00  # Software installation logs
user-management-i-1234567890abcdef0-2024-01-15-11-00-00   # User account creation
dcv-sessions-i-1234567890abcdef0-2024-01-15-11-15-00      # DCV session management
```

### Dashboard Integration

**CloudWatch Insights Queries:**
```sql
-- Software installation logs only
fields @timestamp, @message
| filter @logStream like /software-install/
| sort @timestamp desc

-- User management logs only  
fields @timestamp, @message
| filter @logStream like /user-management/
| sort @timestamp desc

-- Error logs across all components
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
```

**Benefits:**
- **Single location** for all logs
- **Rich metadata** in log stream names for filtering
- **Cost effective** - One log group, configurable retention
- **Dashboard ready** - Easy integration with Grafana, CloudWatch, etc.
- **Module separation** - Each CGD Toolkit module gets its own log group

### Future Enhancements

- **Log separation** - Automatic filtering of different log types
- **Additional log sources** - Windows Event Logs, DCV service logs
- **Enhanced shipping** - More comprehensive log collection

### Recommended: Private Connectivity with AWS Client VPN

**Why Private Access is Better for Game Development VDI:**

**IP Management Simplification:**
- **Problem**: Developers have dynamic public IPs that change frequently - this becomes an extreme pain to manage for geographically distributed teams
- **Solution**: AWS Client VPN gives users consistent internal IPs (e.g., `172.31.0.0/22`)
- **Benefit**: Network admins allow entire VPC CIDR range instead of managing individual IPs

**Security Benefits:**
- **Network isolation**: VDI instances in private subnets, no direct internet exposure
- **Centralized access control**: One VPN endpoint controls all VDI access
- **Certificate-based authentication**: More secure than IP-based restrictions

**Operational Simplicity:**
```hcl
# Simple security group rule - allow entire VPC
allowed_cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR

# Instead of managing individual IPs:
# allowed_cidr_blocks = ["203.0.113.1/32", "198.51.100.5/32", ...]
```

**User Experience:**
1. Connect to AWS Client VPN once
2. Access any VDI workstation at private IP
3. No IP changes to manage
4. Works with DCV, RDP, and all game development tools

See the [private-access example](examples/private-access/) for complete AWS Client VPN integration.

**Connection Examples:**
- **DCV Client**: Use HTTPS URLs above
- **RDP Client**: Use RDP URLs above  
- **Bookmark connections**: Save in your preferred client for easy access

g Users)

```hcl
module "vdi_workstations" {
  source = "./modules/vdi"

  # Add extracted user IPs
  user_public_ips = local.user_public_ips

  # General Configuration
  project_prefix = var.project_prefix
  environment    = var.environment

  # Networking - Use the VPC and subnets created in vpc.tf
  vpc_id  = aws_vpc.vdi_vpc.id
  subnets = aws_subnet.vdi_public_subnet[*].id

  # Dynamic VDI configuration - automatically generated from vdi_user_data in locals.tf
  # Users, passwords, secrets, and AD accounts are all created automatically
  vdi_config = {
    for username, user_data in local.vdi_user_data : username => merge(
      local.vdi_user_defaults,
      {
        # User-specific overrides
        instance_type = lookup(user_data, "instance_type", var.instance_type)
        volumes       = user_data.volumes

        # Dynamic tags from user data
        tags = merge(local.common_tags, {
          given_name  = user_data.given_name
          family_name = user_data.family_name
          email       = user_data.email
          role        = user_data.role
        })
      }
    )
  }

  # Active Directory Configuration (always enabled in this example)
  enable_ad_integration = true
  directory_id          = aws_directory_service_directory.managed_ad.id
  directory_name        = local.directory_name
  dns_ip_addresses      = aws_directory_service_directory.managed_ad.dns_ip_addresses
  ad_admin_password     = local.ad_admin_password

  # Enable automatic AD user management and DCV configuration
  manage_ad_users = true

  # Individual AD user passwords
  individual_user_passwords = {
    for user, password in random_password.ad_user_passwords : user => password.result
  }
}
```

## Examples

For a quickstart, please review the [examples](examples/). They provide a good reference for not only the ways to declare and customize the module configuration, but how to provision and reference the infrastructure mentioned in the prerequisites. As mentioned earlier, we avoid creating infrastructure that is more general (e.g. VPCs, Subnets, Security Groups, etc.) as this can be highly nuanced. All examples show sample configurations of these resources created external to the module, but please customize based on your own needs.

This module provides examples organized by authentication method:

**Available Examples:**

- **[Local Only](examples/local-only/)** - Demonstrates 5-tier architecture with local user authentication, templates, inheritance, and software packages
- **[Managed AD](examples/managed-ad/)** - Active Directory integration with AWS Managed Microsoft AD for enterprise environments

Each example includes complete Terraform configuration with VPC setup, security groups, and detailed connection instructions.

## Software Installation

### **Runtime Software Installation via SSM**

The VDI module supports flexible software installation through SSM documents that run after instance launch.

#### **Available Software Packages**

| Package Name | Installs | SSM Document | Runtime |
|--------------|----------|--------------|----------|
| `"chocolatey"` | Chocolatey package manager | `setup-chocolatey.ps1` | ~5 minutes |
| `"visual-studio-2022"` | Visual Studio 2022 Community | `install-visual-studio.ps1` | ~45 minutes |
| `"git"` | Git version control | `install-git.ps1` | ~5 minutes |
| `"unreal-engine-5.3"` | Unreal Engine 5.3 + Epic Games Launcher | `install-unreal-engine.ps1` | ~30 minutes |
| `"perforce"` | Perforce client tools (P4, P4V, P4Admin) | `install-perforce.ps1` | ~10 minutes |

#### **Configuration Methods**

##### **Method 1: Using Templates (Recommended)**
```hcl
templates = {
  "ue-dev" = {
    instance_type = "g4dn.2xlarge"
    gpu_enabled   = true
    software_packages = [
      "chocolatey",
      "visual-studio-2022", 
      "git",
      "unreal-engine-5.3"
    ]
    custom_scripts = [
      "setup-team-tools.ps1",  # Your custom script (local file)
      "s3://company-bucket/configure-ue-settings.ps1"  # Direct S3 URL
    ]
    volumes = {
      Root = { capacity = 256, type = "gp3" }
      Projects = { capacity = 1024, type = "gp3" }
    }
  }
}

workstations = {
  "alice-workstation" = {
    template_key = "ue-dev"  # Inherits all software packages
    subnet_id = "subnet-123"
    availability_zone = "us-east-1a"
  }
}
```

##### **Method 2: Template Inheritance with Customization**
```hcl
# Template defines base configuration
templates = {
  "ue-dev" = {
    instance_type = "g4dn.2xlarge"
    software_packages = ["chocolatey", "git", "visual-studio-2022"]
    volumes = { Root = { capacity = 256 } }
  }
}

workstations = {
  "bob-workstation" = {
    template_key = "ue-dev"  # Inherits: instance_type, volumes, and base software packages
    
    # Add additional packages to template's base packages
    software_packages_additions = ["perforce"]
    
    # Remove packages Bob doesn't need from template
    software_packages_exclusions = ["visual-studio-2022"]
    # Final packages: chocolatey, git, perforce
    
    subnet_id = "subnet-456"
    availability_zone = "us-east-1b"
  }
}
```

##### **Method 3: Direct Per-Workstation**
```hcl
workstations = {
  "carol-workstation" = {
    instance_type = "g4dn.xlarge"
    gpu_enabled   = true
    
    # Software packages directly on workstation
    software_packages = [
      "chocolatey",
      "git",
      "perforce"  # Carol only needs Perforce, not UE
    ]
    
    # custom_scripts = ["setup-perforce-workspace.ps1"]  # Add your own scripts here
    
    subnet_id = "subnet-789"
    availability_zone = "us-east-1c"
  }
}
```

#### **Custom Scripts**

**Purpose**: Run your own PowerShell scripts after standard software installation.

##### **Script Location Options**

**Local Files (Recommended)**:
```hcl
custom_scripts = [
  "scripts/setup-team-tools.ps1",           # Relative to terraform root
  "/company/shared/configure-vpn.ps1",       # Absolute local path
]
```

**Direct S3 URLs**:
```hcl
custom_scripts = [
  "s3://company-scripts/shared/install-licenses.ps1",  # Direct S3 reference
  "s3://team-bucket/setup/configure-build-tools.ps1"
]
```

**Mixed Approach**:
```hcl
custom_scripts = [
  "scripts/local-setup.ps1",                          # Local file (uploaded automatically)
  "s3://company-scripts/shared/company-tools.ps1"      # Direct S3 URL
]
```

##### **Prerequisites**

**For Local Scripts**:
- Scripts must exist at specified paths relative to `terraform apply` directory
- Scripts must be PowerShell (.ps1) files
- Scripts are automatically uploaded to module's S3 bucket during deployment

**For S3 Scripts**:
- Scripts must already exist in S3 at specified URLs
- VDI instances must have S3 read access to those buckets (configure IAM accordingly)
- Use `s3://bucket-name/path/to/script.ps1` format

**For All Scripts**:
- Scripts run with Administrator privileges
- Scripts should handle errors gracefully (`try/catch` blocks recommended)
- Scripts execute after software packages installation
- All output logged to CloudWatch for troubleshooting

##### **Example Custom Script**
```powershell
# scripts/setup-team-tools.ps1
$ErrorActionPreference = "Stop"

try {
    Write-Host "Installing team-specific tools..."
    
    # Install additional Chocolatey packages
    choco install notepadplusplus -y
    choco install 7zip -y
    
    # Configure Unreal Engine project settings
    $UEConfigPath = "$env:USERPROFILE\Documents\Unreal Projects"
    New-Item -Path $UEConfigPath -ItemType Directory -Force
    
    # Set up Perforce workspace
    Write-Host "Configuring Perforce workspace..."
    p4 set P4PORT=perforce.company.com:1666
    p4 set P4USER=$env:USERNAME
    
    Write-Host "Team tools setup completed successfully"
} catch {
    Write-Error "Team tools setup failed: $_"
    exit 1
}
```

##### **Execution Process**
1. **Local scripts**: Automatically uploaded to S3 during `terraform apply`
2. **All scripts**: Downloaded to `C:\temp\` on VDI instance
3. **Execution**: Scripts run in order specified, with Administrator privileges
4. **Logging**: All output captured in CloudWatch logs for troubleshooting
5. **Error handling**: Failed scripts stop execution and log errors

#### **Installation Timeline**

```
Instance Launch
       ↓
1. Windows boots (2-3 minutes)
       ↓
2. User accounts created via SSM (2-5 minutes)
       ↓
3. Software packages installed (5-60 minutes depending on packages)
       ↓
4. Custom scripts executed (varies)
       ↓
5. DCV sessions created
       ↓
Ready for use
```

**Total deployment time**: 10-70 minutes depending on software packages selected.

#### **Troubleshooting Software Installation**

**Check Installation Status**:
```bash
# View SSM command execution
aws ssm list-command-invocations --instance-id i-1234567890abcdef0

# Check specific installation logs
aws ssm get-command-invocation --command-id <command-id> --instance-id i-1234567890abcdef0
```

**Common Issues**:
- **Long installation times**: Visual Studio and Unreal Engine take 30-45 minutes each
- **Network timeouts**: Large downloads may timeout on slow connections
- **Disk space**: Ensure adequate storage for software packages
- **Custom script errors**: Check CloudWatch logs for script execution details

## Deployment Instructions

### Step 1: Build Windows AMI with Packer

**CRITICAL**: You must build a Windows AMI before deploying VDI workstations.

**Choose your template approach:**

**Option A: Game-Dev Template (Production)**
```bash
# Navigate to game-dev Packer directory
cd assets/packer/virtual-workstations/windows/game-dev/

# Build full AMI with all tools pre-installed (45+ minutes)
packer build windows-server-2025.pkr.hcl

# Note the AMI ID from the output
```

**Option B: Lightweight Template (Development)**
```bash
# Navigate to lightweight Packer directory
cd assets/packer/virtual-workstations/windows/lightweight/

# Build base AMI with runtime software installation (20 minutes)
packer build windows-server-2025-lightweight.pkr.hcl

# Note the AMI ID from the output
```

**Prerequisites for Packer Build:**
- Default VPC and subnet in your AWS account
- AWS credentials configured
- Packer installed locally
- Internet connectivity for the build instance

**Build Process Includes:**
1. Windows Server 2025 instance launch
2. WinRM configuration for Packer connectivity
3. Amazon DCV installation with GPU driver detection
4. Development tools (Visual Studio, Git, Perforce, AWS CLI)
5. Unreal Engine development environment setup
6. Sysprep preparation with password generation system
7. AMI creation and registration

**Customization Options:**
- Modify PowerShell scripts for additional software
- Adjust root volume size in the Packer template
- Change region to match your infrastructure

### Step 2: Deploy VDI Module

**Solo Developer Example:**

```hcl
module "vdi" {
  source = "./modules/vdi"

  # Core configuration
  project_prefix = "gamedev"
  region         = "us-east-1"
  environment    = "dev"
  vpc_id         = var.vpc_id

  # VDI Instances (new AWS-IA pattern)
  vdi_instances = {
    my-workstation = {
      ami               = "ami-from-packer-build"
      instance_type     = "g4dn.2xlarge"
      security_groups   = [aws_security_group.vdi_sg.id]
      availability_zone = var.availability_zone
      subnet_id         = var.subnet_id
      
      allowed_cidr_blocks = ["203.0.113.1/32"]
      
      volumes = {
        Root = { capacity = 256, type = "gp3", iops = 5000, encrypted = true }
        Projects = { capacity = 500, type = "gp3", encrypted = true }
      }
      
      join_ad = false
    }
  }

  # VDI Users
  vdi_users = {
    developer = {
      given_name  = "John"
      family_name = "Doe"
      email       = "john@company.com"
      join_ad     = false
    }
  }

  # VDI Assignments
  vdi_assignments = {
    developer-workstation = {
      user     = "developer"
      instance = "my-workstation"
    }
  }

  # No Active Directory for solo developer
  enable_ad_integration = false
}
```

### Step 3: Deploy Infrastructure

> **⚠️ IMPORTANT**
>
> This module creates **internet-accessible** services by default. Review security configurations and restrict access to your organization's IP ranges before deployment.

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs for connection information
terraform output workstation_connections
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
telnet <workstation-public-ip> 8443

# Test HTTPS connectivity
curl -k https://<workstation-public-ip>:8443
# Should return DCV login page HTML
```

**3. Retrieve Administrator password:**

```bash
# Get password from Secrets Manager
aws secretsmanager get-secret-value --secret-id vdi/workstations/my-workstation/administrator-password --query SecretString --output text
```

**4. Connect via DCV Web Client:**

```bash
# Get the DCV URL for your workstation
WORKSTATION_NAME="my-workstation"  # Replace with your workstation name
terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".dcv_endpoint"
```

- **Open the URL in your browser** (e.g., `https://44.215.109.53:8443`)
- **Accept certificate warning** (DCV uses self-signed certificates - click "Advanced" → "Proceed")
- **Login with:**
  - Username: `Administrator`
  - Password: (from Step 3)
- **Verify you can:**
  - See the Windows desktop
  - Open applications (File Explorer, Command Prompt)
  - Confirm it's responsive and usable

### Connection Test Checklist

- [ ] Instance shows "running" state
- [ ] Security group allows your IP on ports 8443 and 3389
- [ ] DCV service responds on port 8443
- [ ] Administrator password retrieved successfully
- [ ] DCV login page loads in browser
- [ ] Authentication succeeds with retrieved password
- [ ] Windows desktop appears and is responsive
- [ ] Can open and use applications (File Explorer, Command Prompt)
- [ ] Mouse and keyboard input work properly

### Password Retrieval

#### Via Terraform Output + AWS CLI (Recommended)
```bash
# 1. List your workstations to find the correct name
terraform output -json vdi_connection_info | jq 'keys[]'

# 2. Set your workstation name and decrypt password
WORKSTATION_NAME="your-workstation-name"  # Replace with actual name from step 1
terraform output -json private_keys | jq -r ".\"$WORKSTATION_NAME\"" > temp_key.pem
chmod 600 temp_key.pem
aws ec2 get-password-data \
  --instance-id $(terraform output -json vdi_connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") \
  --priv-launch-key temp_key.pem \
  --query 'PasswordData' \
  --output text
rm temp_key.pem
```

#### Via AWS Console (Alternative)
1. Go to [EC2 Console](https://console.aws.amazon.com/ec2/)
2. Select your VDI instance
3. Actions → Security → Get Windows Password
4. Upload the private key file (get from `terraform output -json private_keys`)
5. Click "Decrypt Password" to reveal the Administrator password

## Customization Options

### Infrastructure Customization

The module can be customized by:
- **Storage Configuration**: Adjust volume sizes, types, and IOPS per user
- **Network Security**: Specify user public IPs and modify CIDR blocks for security group rules
- **AMI Selection**: Use auto-discovery or specify custom AMI IDs
- **Encryption**: Enable EBS encryption with optional KMS keys

### Security Group Configuration

Each user gets security group rules allowing access from:
1. **Their specified public IP** (from `user_public_ips` parameter)
2. **VPC CIDR block** (for internal/VPN access)

This provides flexibility for users to connect directly from their public IP or through VPN/internal networks.

## Troubleshooting

### Critical Issues

#### 🚨 DCV "Connecting" Spinner (Never Connects)

**Cause**: User data script failed, no DCV sessions created

**Diagnosis**:
```powershell
# Connect via SSM Session Manager
aws ssm start-session --target [instance-id]

# Check if user accounts exist
Get-LocalUser

# Check DCV sessions
dcv list-sessions

# Check user data logs
Get-Content "C:\Windows\Temp\vdi-setup.log" -Tail 20
```

**Common Causes**:
- **User data syntax errors** - PowerShell script fails to parse
- **AWS permissions missing** - Can't access Secrets Manager
- **DCV service issues** - Wrong service names in script

#### 🚨 Private Key Decryption Fails

**Error**: "There was an error decrypting your password" or empty PasswordData

**Diagnosis**: Check if EC2Launch service is working
```bash
# Check instance launch time and status
aws ec2 describe-instances --instance-ids [instance-id] --query 'Reservations[].Instances[].[LaunchTime,State.Name]' --output table

# Test Windows connectivity
telnet [instance-ip] 3389  # RDP port
telnet [instance-ip] 8443  # DCV port

# Check password data availability
aws ec2 get-password-data --instance-id [instance-id] --query 'PasswordData' --output text
```

**Solutions**:

**If PasswordData is empty after 30+ minutes:**
- **AMI Issue**: EC2Launch service not configured properly during sysprep
- **Fix**: Rebuild AMI with proper EC2Launch configuration
- **Workaround**: Use AWS-provided Windows AMI as base

**If PasswordData exists but decryption fails:**
```bash
# Use S3 backup key instead of Terraform output
aws s3 cp s3://[bucket]/emergency-keys/[workstation]/[key].pem ./backup-key.pem
chmod 600 backup-key.pem
aws ec2 get-password-data --instance-id [instance-id] --priv-launch-key backup-key.pem
```

#### 🚨 User Accounts Not Created

**Symptoms**: Only Administrator, Guest, DefaultAccount exist

**Cause**: User data script failed during account creation

**Fix**: Check Secrets Manager access and script syntax
```powershell
# Test AWS access
Import-Module AWS.Tools.SecretsManager
Get-SECSecretValue -SecretId "[project]/users/[username]"

# Manually run user data (if needed)
$token = Invoke-RestMethod -Uri "http://169.254.169.254/latest/api/token" -Method PUT -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"}
$userData = Invoke-RestMethod -Uri "http://169.254.169.254/latest/user-data" -Headers @{"X-aws-ec2-metadata-token" = $token}
$userData | Out-File -FilePath "C:\temp\userdata.ps1" -Encoding UTF8
PowerShell -ExecutionPolicy Bypass -File "C:\temp\userdata.ps1"
```

### AMI Component Verification

After deploying an instance from your Packer-built AMI, verify all components are properly installed and configured.

#### NVIDIA Drivers (GPU Instances)

**Check GPU Detection:**
```powershell
# Open PowerShell as Administrator and run:
Get-WmiObject Win32_VideoController | Where-Object {$_.Name -like "*NVIDIA*"}
# Should show Tesla T4, V100, or other GPU model
```

**Check NVIDIA Management Interface:**
```powershell
# Should work directly (PATH configured during AMI build)
nvidia-smi

# If PATH not configured, run directly:
& "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
```

**Expected Output:**
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 452.39       Driver Version: 452.39       CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name            TCC/WDDM | Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla T4            TCC  | 00000000:00:1E.0 Off |                    0 |
| N/A   43C    P0    26W /  70W |      0MiB / 15109MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

**Common NVIDIA Issues:**

1. **"nvidia-smi is not recognized"**
   ```powershell
   # PATH should be configured automatically, but if not:
   $nvidiaSmiPath = "C:\Program Files\NVIDIA Corporation\NVSMI"
   $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
   [Environment]::SetEnvironmentVariable("Path", "$currentPath;$nvidiaSmiPath", "Machine")
   # Restart PowerShell and try again
   ```

2. **"Failed to initialize NVML"**
   ```powershell
   # Restart the instance to initialize drivers
   Restart-Computer -Force
   # Wait 5 minutes, then test nvidia-smi again
   ```

3. **No GPU detected**
   ```powershell
   # Check if you're on a GPU instance type
   $instanceType = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-type")
   Write-Host "Instance Type: $instanceType"
   # Should show g4dn.*, g5.*, p3.*, etc. for GPU instances
   ```

#### DCV Server Verification

**Check DCV Service Status:**
```powershell
Get-Service dcvserver
# Should show: Status = Running, StartType = Automatic
```

**Check DCV Sessions:**
```powershell
dcv list-sessions
# Should show active sessions, e.g.:
# Session 'console' (owner: Administrator)
```

**Test DCV Executable:**
```powershell
Test-Path "C:\Program Files\NICE\DCV\Server\bin\dcv.exe"
# Should return: True
```

**Check DCV Configuration:**
```powershell
Test-Path "C:\Program Files\NICE\DCV\Server\conf\dcv.conf"
# Should return: True

# View DCV configuration
Get-Content "C:\Program Files\NICE\DCV\Server\conf\dcv.conf"
```

**Common DCV Issues:**

1. **DCV Service Not Running**
   ```powershell
   Start-Service dcvserver
   Set-Service dcvserver -StartupType Automatic
   ```

2. **No DCV Sessions Available**
   ```powershell
   # Create a console session
   dcv create-session --owner Administrator console
   ```

3. **DCV Port Not Accessible**
   ```powershell
   # Check Windows Firewall
   Get-NetFirewallRule -DisplayName "*DCV*" | Select-Object DisplayName, Enabled
   
   # Enable DCV firewall rules if disabled
   Enable-NetFirewallRule -DisplayGroup "NICE DCV"
   ```

#### PowerShell AWS Modules

**Check Installed Modules:**
```powershell
Get-Module -ListAvailable AWS.Tools.*
# Should show: AWS.Tools.Common, AWS.Tools.EC2, AWS.Tools.SSM
```

**Test AWS Connectivity:**
```powershell
# Test basic AWS connectivity
Get-AWSRegion
# Should return list of AWS regions

# Test EC2 permissions
Get-EC2Instance -MaxItems 1
# Should return instance information or permission error
```

**Common PowerShell Module Issues:**

1. **Modules Not Found**
   ```powershell
   # Reinstall AWS modules
   Install-Module -Name AWS.Tools.Common -Force -AllowClobber
   Install-Module -Name AWS.Tools.EC2 -Force -AllowClobber
   Install-Module -Name AWS.Tools.SSM -Force -AllowClobber
   ```

2. **AWS Credentials Not Configured**
   ```powershell
   # Check if instance has IAM role
   $instanceProfile = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/iam/security-credentials/")
   Write-Host "Instance Profile: $instanceProfile"
   ```

#### Active Directory Tools (If Included)

**Check AD Tools Installation:**
```powershell
Get-WindowsFeature RSAT-AD-*
# Should show: InstallState = Installed for RSAT-AD-PowerShell, RSAT-AD-Tools

Get-Module -ListAvailable ActiveDirectory
# Should show ActiveDirectory module if AD tools installed
```

**Test AD Module Auto-Import:**
```powershell
# Should auto-import when PowerShell starts
Get-Module ActiveDirectory
# Should show: ModuleType = Manifest, Name = ActiveDirectory

# If not auto-imported, manually import:
Import-Module ActiveDirectory
```

**Test AD Connectivity (if domain-joined):**
```powershell
# Test domain connection
Test-ComputerSecureChannel -Verbose
# Should return: True

# List domain users (requires DOMAIN credentials, not local)
Get-ADUser -Filter * -Credential (Get-Credential)
# Enter: DOMAIN\username (e.g., CORP\domainadmin)
```

#### SSM Agent Verification

**Check SSM Agent Status:**
```powershell
Get-Service AmazonSSMAgent
# Should show: Status = Running, StartType = Automatic
```

**Test SSM Connectivity:**
```bash
# From your local machine, test SSM connection
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-1234567890abcdef0"
# Should show instance information with PingStatus = Online
```

**Common SSM Issues:**

1. **SSM Agent Offline**
   ```powershell
   # Restart SSM Agent
   Restart-Service AmazonSSMAgent
   
   # Check SSM Agent logs
   Get-Content "C:\ProgramData\Amazon\SSM\Logs\amazon-ssm-agent.log" -Tail 20
   ```

2. **"SSM Agent is not online" in Console**
   - **Wait 5-10 minutes** after instance launch for SSM to register
   - Check instance has internet connectivity or VPC endpoints
   - Verify IAM role has SSM permissions

### Password and Authentication Issues

#### Password Retrieval Problems

**EC2 Console Password Retrieval:**
```bash
# Method 1: AWS CLI with key pair
aws ec2 get-password-data --instance-id i-1234567890abcdef0 --priv-launch-key /path/to/private-key.pem

# Method 2: Check if password is available
aws ec2 get-password-data --instance-id i-1234567890abcdef0 --query 'PasswordData' --output text
# Should return encrypted password data (not empty)
```

**Common Password Issues:**

1. **"Password is not available" in SSM**
   - This is normal for first 4-5 minutes after launch
   - Use EC2 console password retrieval instead
   - Restart instance if persists after 10 minutes

2. **"Get Windows Password" shows no data**
   ```powershell
   # Check EC2Launch service on the instance
   Get-Service EC2Launch
   # Should be running, if not:
   Start-Service EC2Launch
   ```

3. **Wrong Password Format**
   - Password should be 20+ characters with special characters
   - Example: `P1dDqh;BWm5M.LBg8X-I6BnG&=UocxfH`
   - If too short or simple, EC2Launch may have failed

#### Authentication Troubleshooting

**Test RDP Connection:**
```bash
# Test RDP port accessibility
telnet <instance-ip> 3389
# Should connect (Ctrl+C to exit)

# Test from different network if fails
curl https://checkip.amazonaws.com/  # Check your current IP
```

**Test DCV Connection:**
```bash
# Test DCV HTTPS port
telnet <instance-ip> 8443
# Should connect

# Test DCV web interface
curl -k https://<instance-ip>:8443
# Should return HTML with "DCV" in content
```

### Network Connectivity Issues

#### Security Group Verification

**Check Your Current IP:**
```bash
curl https://checkip.amazonaws.com/
# Compare with configured user_public_ips
```

**Test Port Connectivity:**
```bash
# Test RDP (port 3389)
nc -zv <instance-ip> 3389

# Test DCV HTTPS (port 8443)
nc -zv <instance-ip> 8443

# Test DCV QUIC (UDP 8443) - may not work with nc
# Use DCV client to test QUIC connectivity
```

#### Instance Connectivity

**Check Instance Status:**
```bash
# Verify instance is running
aws ec2 describe-instances --instance-ids i-1234567890abcdef0 --query 'Reservations[].Instances[].State.Name'
# Should return: "running"

# Check status checks
aws ec2 describe-instance-status --instance-ids i-1234567890abcdef0
# Both SystemStatus and InstanceStatus should be "ok"
```

### Performance Issues

#### Instance Performance

**Check Instance Metrics:**
```bash
# Get CPU utilization
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=InstanceId,Value=i-1234567890abcdef0 --start-time 2024-01-01T00:00:00Z --end-time 2024-01-01T01:00:00Z --period 300 --statistics Average
```

**On the Instance:**
```powershell
# Check CPU usage
Get-Counter "\Processor(_Total)\% Processor Time"

# Check memory usage
Get-Counter "\Memory\Available MBytes"

# Check disk performance
Get-Counter "\PhysicalDisk(_Total)\Disk Read Bytes/sec"
Get-Counter "\PhysicalDisk(_Total)\Disk Write Bytes/sec"
```

#### DCV Performance

**Optimize DCV Settings:**
```powershell
# Check DCV display settings
dcv describe-session console --show-display

# Enable hardware acceleration (if available)
reg add "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\display" /v enable-hw-accel /t REG_SZ /d true /f

# Restart DCV service
Restart-Service dcvserver
```

### Terraform Deployment Issues

#### If the Terraform deployment fails:
1. Run `terraform plan` to check for configuration errors
2. Check the Terraform logs for error messages
3. Verify your VPC and subnets have proper internet connectivity
4. Ensure your AWS credentials have sufficient permissions for EC2, VPC, and Directory Service operations
5. Check that the instance types are available in your selected region
6. Verify the Packer AMI exists and is accessible in your account

#### Common Deployment Issues:
- **AMI Not Found**: Ensure the Packer AMI with prefix `windows-server-2025` exists in your account
- **Instance Launch Failures**: Check subnet capacity and instance type availability
- **Security Group Issues**: Verify CIDR blocks and port configurations
- **Domain Join Problems**: Ensure AD directory is accessible and SSM agent is running
- **Password Retrieval**: Confirm proper IAM permissions for EC2 password operations

### Getting Additional Help

#### Log Collection

**Collect System Information:**
```powershell
# System information
systeminfo > C:\temp\systeminfo.txt

# Network configuration
ipconfig /all > C:\temp\network.txt

# Installed software
Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Export-Csv C:\temp\software.csv

# Running services
Get-Service | Export-Csv C:\temp\services.csv
```

**Important Log Locations:**
- **DCV Logs**: `C:\ProgramData\NICE\DCV\log\`
- **SSM Logs**: `C:\ProgramData\Amazon\SSM\Logs\`
- **EC2 Config Logs**: `C:\Program Files\Amazon\Ec2ConfigService\Logs\`
- **Windows Event Logs**: Event Viewer → Windows Logs → System/Application

#### Support Information

When requesting help, include:
1. **Terraform version and configuration**
2. **Instance details** (type, region, AMI ID)
3. **Error messages** from logs
4. **Network configuration** (VPC, subnets, security groups)
5. **Verification command outputs** from above sections

### DCV Connection Issues

#### "No Connections Available" Error
**Symptoms**: DCV web client shows "No connections available" or connection fails immediately

**Causes & Solutions**:

1. **DCV Session Missing**
   ```powershell
   # Connect via RDP first, then check sessions
   dcv list-sessions
   # Should show: Session 'console' (owner: Administrator)
   
   # If no session exists, create one
   dcv create-session --owner Administrator console
   ```

2. **Wrong Session Owner**
   ```powershell
   # Check who owns the session
   dcv list-sessions
   
   # If owned by wrong user, close and recreate
   dcv close-session console
   dcv create-session --owner Administrator console
   ```

3. **DCV Service Not Running**
   ```powershell
   # Check DCV service status
   Get-Service dcvserver
   # Should show: Status = Running
   
   # If stopped, start the service
   Start-Service dcvserver
   
   # If failed to start, restart it
   Restart-Service dcvserver -Force
   ```

#### Connection Refused or Timeout
**Symptoms**: Browser shows "Connection refused" or times out when accessing DCV URL

**Causes & Solutions**:

1. **Security Group Configuration**
   - Verify security group allows **TCP 8443** (HTTPS) and **UDP 8443** (QUIC) from your IP
   - Check that your current public IP matches the configured `user_public_ips`
   - Test connectivity: `telnet <workstation-ip> 8443`

2. **Windows Firewall Blocking**
   ```powershell
   # Check Windows Firewall rules for DCV
   Get-NetFirewallRule -DisplayName "*DCV*" | Select-Object DisplayName, Enabled, Direction
   
   # If DCV rules are disabled, enable them
   Enable-NetFirewallRule -DisplayGroup "NICE DCV"
   ```

3. **Instance Not Ready**
   - Wait 5-10 minutes after instance launch for DCV to fully initialize
   - Check EC2 instance status checks are passing
   - Verify instance has public IP assigned

#### Authentication Failed
**Symptoms**: DCV prompts for credentials but login fails

**Causes & Solutions**:

1. **Wrong Password**
   ```bash
   # Get the correct Administrator password
   # Method 1: AWS Console
   # Go to EC2 → Select instance → Actions → Security → Get Windows Password
   
   # Method 2: AWS CLI (if using key pairs)
   aws ec2 get-password-data --instance-id i-1234567890abcdef0 --priv-launch-key /path/to/private-key.pem
   ```

2. **Account Locked**
   ```powershell
   # Check account status via RDP
   net user Administrator
   # Look for "Account active: Yes"
   
   # If locked, unlock it
   net user Administrator /active:yes
   ```

3. **Domain vs Local Authentication**
   - For **standalone instances**: Use `Administrator` (local account)
   - For **domain-joined instances**: Use `DOMAIN\username` or `username@domain.com`

### DCV Session Management

#### Understanding DCV Sessions
- **One session per user** - Each user should have their own session
- **Sessions persist** - Sessions continue running even when disconnected
- **Owner matters** - Session owner determines who can connect

#### Session Commands
```powershell
# List all sessions
dcv list-sessions

# Create a new session
dcv create-session --owner Administrator --type console console

# Close a session
dcv close-session console

# Check session permissions
dcv list-permissions console

# Set session permissions (for shared access)
dcv set-permissions console --user "DOMAIN\username" --permissions "connect,view"
```

#### Session Troubleshooting
```powershell
# If session won't start
# 1. Check DCV logs
Get-Content "C:\ProgramData\NICE\DCV\log\server.log" -Tail 50

# 2. Verify display driver
# For GPU instances: NVIDIA driver should be installed
# For non-GPU: DCV virtual display driver should be installed
Get-WmiObject Win32_VideoController | Select-Object Name, Status

# 3. Check registry settings
reg query "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\security" /v authentication
# Should show: authentication REG_SZ system
```

### Network Connectivity Issues

#### Testing Connectivity
```bash
# Test basic connectivity to DCV port
telnet <workstation-public-ip> 8443

# Test HTTPS connectivity
curl -k https://<workstation-public-ip>:8443
# Should return DCV login page HTML

# Check your current public IP
curl ifconfig.me
# Verify this matches your configured user_public_ips
```

#### DNS Resolution (for private access)
```bash
# If using private DNS names
nslookup <workstation-name>.dev.vdi.company.com
# Should resolve to private IP when on VPN

# Test private connectivity
ping <workstation-name>.dev.vdi.company.com
```

### Active Directory Integration Issues

#### Domain Join Failures
```bash
# Check domain join status via SSM
aws ssm describe-instance-associations-status --instance-id i-1234567890abcdef0

# Check domain join logs
aws ssm get-command-invocation --command-id <command-id> --instance-id i-1234567890abcdef0
```

```powershell
# On the instance, check domain membership
(Get-WmiObject Win32_ComputerSystem).Domain
# Should show: corp.company.com (not WORKGROUP)

# Test domain connectivity
Test-ComputerSecureChannel -Verbose
# Should return: True
```

#### AD User Management
```bash
# List all users in the directory
aws ds-data list-users --directory-id d-1234567890

# Get specific user details
aws ds-data describe-user --directory-id d-1234567890 --sam-account-name username

# Check directory status
aws ds describe-directories --directory-ids d-1234567890

# Reset user password
aws ds reset-user-password --directory-id d-1234567890 --user-name username --new-password "NewPassword123!"
```

### Performance Issues

#### DCV Performance Optimization
```powershell
# Check DCV performance settings
reg query "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" /v enable-quic-frontend
# Should show: enable-quic-frontend REG_SZ true

# Monitor DCV bandwidth usage
dcv describe-session console --show-display
```

#### Instance Performance
```powershell
# Check GPU utilization (for GPU instances)
nvidia-smi

# Check CPU and memory usage
Get-Counter "\Processor(_Total)\% Processor Time"
Get-Counter "\Memory\Available MBytes"

# Check disk performance
Get-Counter "\PhysicalDisk(_Total)\Disk Read Bytes/sec"
Get-Counter "\PhysicalDisk(_Total)\Disk Write Bytes/sec"
```

### Resource Lifecycle Issues

#### EC2 Emergency Key Overwrite
**Problem**: When instances are recreated, new private keys overwrite old keys in S3.

**Check for overwritten keys:**
```bash
# List S3 keys for workstation
aws s3 ls s3://[bucket-name]/[workstation-key]/ec2-key/ --recursive

# Should show only one key - old keys are overwritten
```

**Impact**: Cannot decrypt Administrator passwords from previous instances.

**Workaround**: Enable S3 versioning on emergency keys bucket before deployment.

#### VDIAdmin Secret Orphaning
**Problem**: VDIAdmin secrets managed by SSM scripts, not Terraform lifecycle.

**Check for orphaned secrets:**
```bash
# List all VDIAdmin secrets
aws secretsmanager list-secrets --filters Key=name,Values=cgd --query 'SecretList[?contains(Name, `vdiadmin`)].{Name:Name,LastChangedDate:LastChangedDate}' --output table

# Check if secret exists for destroyed instance
aws secretsmanager describe-secret --secret-id "cgd/[workstation]/users/vdiadmin"
```

**Cleanup orphaned secrets:**
```bash
# Delete orphaned VDIAdmin secret
aws secretsmanager delete-secret --secret-id "cgd/[workstation]/users/vdiadmin" --force-delete-without-recovery
```

### SSM Association Troubleshooting

#### Check Association Status
```bash
# List all VDI associations
aws ssm describe-associations --query 'Associations[?contains(Name, `cgd-dev`)].{AssociationId:AssociationId,Name:Name,LastExecutionDate:LastExecutionDate}' --output table

# Check specific association status
aws ssm describe-association --association-id [ASSOCIATION_ID] --query '{Status:Status,LastExecutionDate:LastExecutionDate,Overview:Overview}' --output table
```

#### Check Command Executions
```bash
# List recent command executions
aws ssm list-command-invocations --instance-id [INSTANCE_ID] --max-results 5 --query 'CommandInvocations[*].{CommandId:CommandId,DocumentName:DocumentName,Status:Status,RequestedDateTime:RequestedDateTime}' --output table

# Get detailed command output
aws ssm get-command-invocation --command-id [COMMAND_ID] --instance-id [INSTANCE_ID] --query '{Status:Status,StandardOutputContent:StandardOutputContent,StandardErrorContent:StandardErrorContent}'
```

#### Manual Association Triggering
```bash
# Trigger specific association immediately
aws ssm start-associations-once --association-ids [ASSOCIATION_ID]

# Trigger all VDI associations
aws ssm describe-associations --query 'Associations[?contains(Name, `cgd-dev`)].AssociationId' --output text | tr '\t' '\n' | while read assoc_id; do
  aws ssm start-associations-once --association-ids $assoc_id
done
```

#### Check Instance SSM Connectivity
```bash
# Verify instance is online for SSM
aws ssm describe-instance-information --filters Key=InstanceIds,Values=[INSTANCE_ID] --query 'InstanceInformationList[0].{PingStatus:PingStatus,LastPingDateTime:LastPingDateTime}' --output table

# Should show PingStatus: Online
```

### Password and Authentication Issues

#### VDIAdmin Authentication Problems
**If VDIAdmin login fails after SSM execution:**

```bash
# 1. Verify VDIAdmin secret exists
aws secretsmanager get-secret-value --secret-id "cgd/[workstation]/users/vdiadmin" --query SecretString --output text | jq -r '.password'

# 2. Check if SSM script executed successfully
aws ssm list-command-invocations --instance-id [INSTANCE_ID] --filters key=DocumentName,value=cgd-dev-setup-dcv-users-sessions --max-results 3

# 3. Get detailed SSM execution output
aws ssm get-command-invocation --command-id [COMMAND_ID] --instance-id [INSTANCE_ID] --query 'StandardOutputContent' --output text

# Look for: "VDIAdmin user created using Secrets Manager password"
```

#### Administrator Password Retrieval
```bash
# Method 1: Via Terraform output
WORKSTATION_NAME="[workstation-key]"
terraform output -json private_keys | jq -r ".\"$WORKSTATION_NAME\"" > temp_key.pem
chmod 600 temp_key.pem
aws ec2 get-password-data --instance-id $(terraform output -json connection_info | jq -r ".\"$WORKSTATION_NAME\".instance_id") --priv-launch-key temp_key.pem --query 'PasswordData' --output text
rm temp_key.pem

# Method 2: Via S3 backup key
BUCKET_NAME="[emergency-keys-bucket]"
aws s3 cp s3://$BUCKET_NAME/[workstation]/ec2-key/[workstation]-private-key.pem ./backup-key.pem
chmod 600 backup-key.pem
aws ec2 get-password-data --instance-id [INSTANCE_ID] --priv-launch-key backup-key.pem --query 'PasswordData' --output text
rm backup-key.pem
```

#### User Password Retrieval
```bash
# Get user password from Secrets Manager
aws secretsmanager get-secret-value --secret-id "cgd/[workstation]/users/[username]" --query SecretString --output text | jq -r '.password'

# List all user secrets for workstation
aws secretsmanager list-secrets --filters Key=name,Values=cgd/[workstation]/users --query 'SecretList[*].{Name:Name,LastChangedDate:LastChangedDate}' --output table
```

### Network Connectivity Issues

#### Test VDI Connectivity
```bash
# Check your current public IP
curl https://checkip.amazonaws.com/

# Test RDP port
nc -zv [instance-ip] 3389

# Test DCV HTTPS port
nc -zv [instance-ip] 8443

# Test DCV web interface
curl -k https://[instance-ip]:8443
# Should return HTML with "DCV" in content
```

#### Security Group Verification
```bash
# Get instance security groups
aws ec2 describe-instances --instance-ids [INSTANCE_ID] --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text

# Check security group rules
aws ec2 describe-security-groups --group-ids [SG_ID] --query 'SecurityGroups[].IpPermissions[?FromPort==`8443`]'
```

### Instance Status and Health

#### Basic Instance Checks
```bash
# Check instance status
aws ec2 describe-instances --instance-ids [INSTANCE_ID] --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' --output table

# Check instance status checks
aws ec2 describe-instance-status --instance-ids [INSTANCE_ID] --query 'InstanceStatuses[0].{InstanceStatus:InstanceStatus.Status,SystemStatus:SystemStatus.Status}' --output table

# Both should show "ok"
```

#### Connect to Instance for Debugging
```bash
# Connect via SSM Session Manager (no RDP needed)
aws ssm start-session --target [INSTANCE_ID]

# Then run PowerShell commands on the instance
```

### Software Installation Issues

#### Check Software Installation Status
```bash
# List all software installation commands
aws ssm list-command-invocations --instance-id [INSTANCE_ID] --filters key=DocumentName,value=cgd-dev-install --max-results 10

# Check specific software installation
aws ssm get-command-invocation --command-id [COMMAND_ID] --instance-id [INSTANCE_ID] --query '{Status:Status,StandardOutputContent:StandardOutputContent}'
```

#### Common Software Installation Problems
```powershell
# On the instance, check if software installed
Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*Visual Studio*"}
Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*Git*"}

# Check Chocolatey packages
choco list --local-only

# Check installation logs
Get-Content "C:\ProgramData\chocolatey\logs\chocolatey.log" -Tail 50
```

### Getting Help

#### Log Locations
- **DCV Server Logs**: `C:\ProgramData\NICE\DCV\log\server.log`
- **DCV Agent Logs**: `C:\ProgramData\NICE\DCV\log\agent.log`
- **Windows Event Logs**: Event Viewer → Windows Logs → System/Application
- **SSM Logs**: `C:\ProgramData\Amazon\SSM\Logs\amazon-ssm-agent.log`
- **Chocolatey Logs**: `C:\ProgramData\chocolatey\logs\`

#### Log Collection

**Collect System Information:**
```powershell
# System information
systeminfo > C:\temp\systeminfo.txt

# Network configuration
ipconfig /all > C:\temp\network.txt

# Installed software
Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Export-Csv C:\temp\software.csv

# Running services
Get-Service | Export-Csv C:\temp\services.csv

# DCV sessions
dcv list-sessions > C:\temp\dcv-sessions.txt

# Local users
Get-LocalUser | Export-Csv C:\temp\local-users.csv
```

#### Support Information

When requesting help, include:
1. **Terraform version and configuration**
2. **Instance details** (type, region, AMI ID)
3. **Error messages** from logs
4. **Network configuration** (VPC, subnets, security groups)
5. **Command outputs** from troubleshooting sections above
6. **Timeline** of when issues started occurring
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
