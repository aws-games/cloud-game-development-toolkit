# VDI (Virtual Desktop Infrastructure) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **ℹ️ Prerequisites**: You need a Windows Server AMI. The examples use Packer-built AMIs from this repo's [Packer templates](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/assets/packer/virtual-workstations) (`lightweight/` and `ue-gamedev/`), but any Windows Server 2019/2022/2025 AMI works. See [Amazon DCV Documentation](https://docs.aws.amazon.com/dcv/) for complete setup guidance.

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

- **Complete VDI Infrastructure** - EC2 workstations, security, IAM, and user management
- **Flexible Authentication** - EC2 key pairs (emergency) and Secrets Manager (managed)
- **Security by Default** - Least privilege IAM, encrypted storage, restricted access
- **Dual Connectivity** - Public internet or private VPN access
- **Game Development Ready** - GPU instances, high-performance storage
- **Runtime Software Installation** - Automated via SSM
- **Amazon DCV Integration** - High-performance remote desktop

## Connectivity Patterns

### Public Connectivity (Default)

**Best for**: Solo developers, small teams, development environments

> **Connection**: Direct internet access with IP restrictions
> - DCV: `https://INSTANCE-PUBLIC-IP:8443` 
> - RDP: `rdp://INSTANCE-PUBLIC-IP:3389`
> - DNS: `ec2-XX-XXX-XX-XX.region.compute.amazonaws.com` (example)

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

### Private Connectivity

**Best for**: Enterprise environments, security-conscious deployments, distributed teams

**Access**: VDI instances in private subnets, accessible via VPC connectivity

**⚠️ DNS Propagation**: After deployment, Client VPN endpoints need 1-3 hours for DNS propagation before connections work

#### **VPC Access Methods (Choose One):**

| Method | Setup | Best For | Key Features |
|--------|-------|----------|-------------|
| **[AWS Client VPN](https://aws.amazon.com/vpn/client-vpn/)** | Automatic (module) or use existing | Remote teams, individual users | Per-user certificates, internal DNS, .ovpn files |
| **[Site-to-Site VPN](https://aws.amazon.com/vpn/site-to-site-vpn/)** | Manual setup or use existing | Office networks | Persistent connection, connects entire network |
| **[AWS Direct Connect](https://aws.amazon.com/directconnect/)** | Manual setup or use existing | Enterprise, high bandwidth | Dedicated connection, consistent performance |

#### **Client VPN Example Configuration:**

```hcl
module "vdi" {
  enable_private_connectivity = true  # Creates Client VPN infrastructure
  
  users = {
    "vdiadmin" = {
      type              = "global_administrator"
      connectivity_type = "private"  # Gets VPN access + certificates
    }
    "john-doe" = {
      type              = "administrator"
      connectivity_type = "private"  # Gets VPN access + certificates
    }
  }
  
  workstations = {
    "vdi-001" = {
      preset_key = "my-template"
      subnet_id = aws_subnet.private_subnet.id
      allowed_cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR only
    }
  }
  
  workstation_assignments = {
    "vdi-001" = { user = "john-doe" }
  }
}
```

> **Note**: `vdiadmin` is not assigned to a specific workstation because `global_administrator` users are automatically created on ALL workstations in the fleet for management purposes.

> **Connection Process**: Download .ovpn → Connect to VPN → Access workstations
> - Private IP: `https://PRIVATE-IP:8443` (DCV) or `rdp://PRIVATE-IP:3389` (RDP)
> - Private DNS: `ip-XX-X-X-XXX.region.compute.internal` (AWS internal)
> - Custom DNS: `user.vdi.internal`

**Module Creates**:
- Client VPN endpoint with per-user certificates
- S3 storage for .ovpn files  
- Internal DNS zone (`user.vdi.internal`)

**Benefits**: Enhanced security, simplified IP management, compliance-ready

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Remote User   │    │   VPN Client     │    │  VDI Workstation│
│                 │───▶│  (Private Mode)  │───▶│   EC2 Instance  │
│  Web Browser    │    │   .ovpn file     │    │   Windows + DCV │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │ (Public Mode)         │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │         AWS VPC           │
                    │  ┌─────────────────────┐  │
                    │  │   Security Groups   │  │
                    │  │   IAM Roles        │  │
                    │  │   SSM Documents    │  │
                    │  └─────────────────────┘  │
                    │                           │
                    │  ┌─────────────────────┐  │
                    │  │   S3 Buckets        │  │
                    │  │   - Scripts         │  │
                    │  │   - Keys            │  │
                    │  │   - VPN Configs     │  │
                    │  └─────────────────────┘  │
                    │                           │
                    │  ┌─────────────────────┐  │
                    │  │  Secrets Manager    │  │
                    │  │  User Passwords     │  │
                    │  └─────────────────────┘  │
                    └───────────────────────────┘
```

| Component | Purpose |
|-----------|----------|
| **EC2 Workstations** | GPU-enabled instances with DCV remote access |
| **Secrets Manager** | User password storage and management |
| **Security Groups** | Network access control with IP restrictions |
| **IAM Roles** | SSM permissions for instance management |
| **SSM Automation** | Software installation and user creation |
| **S3 Storage** | Script hosting, emergency key backup, VPN configs |
| **Client VPN** (Optional) | Private access with per-user certificates |

### Account Creation Pattern

| Account Type | Created When | Password Storage | Scope | Use Case |
|--------------|-------------|------------------|-------|----------|
| 🆘 **Administrator** (built-in) | Windows boot | EC2 Key Pair | All workstations | Emergency break-glass only |
| 🛡️ **Fleet Admin** (`global_administrator`) | SSM (if defined) | Secrets Manager | All workstations | Fleet management |
| 🔧 **Local Admin** (`administrator`) | SSM (if defined) | Secrets Manager | Assigned workstation | Local administration |
| 💻 **Standard User** (`user`) | SSM (if defined) | Secrets Manager | Assigned workstation | Daily usage |

**Key Point**: Only the built-in Administrator exists automatically. All other accounts must be explicitly defined in the `users` variable.

## Prerequisites

### Required Access & Tools

1. **AWS Account Setup**
   - AWS CLI configured with deployment permissions
   - VPC with public and private subnets
   - Basic understanding of AWS services ([VPC](https://aws.amazon.com/vpc/), [EC2](https://aws.amazon.com/ec2/))

2. **Custom IAM Instance Profile (Optional)**
   
   If you want to use your own IAM instance profile instead of the module's default, it must include these actions (scope resources following least privilege):
   
   - **EC2**: `DescribeTags`, `DescribeInstances`
   - **SSM**: `GetParameter`, `SendCommand`, `ListCommandInvocations`, etc.
   - **Secrets Manager**: `GetSecretValue`, `PutSecretValue` (for module-created secrets only)
   - **S3**: `GetObject`, `ListBucket` (for module-created buckets only)
   - **CloudWatch Logs**: `CreateLogGroup`, `PutLogEvents` (for module log groups only)
   - **AWS Managed Policies**: `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy` (if logging enabled)

3. **Network Planning**
   - **Public connectivity**: User public IP addresses for security group access
   - **Private connectivity**: VPN setup and VPC CIDR planning

### Getting User Public IP Addresses

**Public Connectivity**: Collect user IPs via `https://checkip.amazonaws.com/`
- Examples automatically detect your IP, but you'll need to add other users' IPs manually
- Public IPs change over time, requiring security group updates
- **Recommendation**: Use private connectivity for multiple users

**Private Connectivity**: Not needed - users connect via VPN

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples). They provide complete Terraform configuration with VPC setup, security groups, and detailed connection instructions.

**Available Examples:**

- **[Public Connectivity](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples/public-connectivity)** - Direct internet access with IP restrictions
- **[Private Connectivity](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples/private-connectivity)** - AWS Client VPN with internal DNS
- **[External Client VPN](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi/examples/external-client-vpn)** - Use existing VPN infrastructure

Each example includes complete infrastructure setup and connection instructions.

## Deployment Instructions

### Step 1: Clone the CGD Toolkit

```bash
# Clone the complete repository
git clone https://github.com/aws-games/cloud-game-development-toolkit.git
cd cloud-game-development-toolkit
```

### Step 2: Build Windows AMI with Packer

**CRITICAL**: You must build a Windows AMI before deploying VDI workstations.

```bash
# Navigate to UE GameDev template directory
cd assets/packer/virtual-workstations/ue-gamedev/

# Build UE GameDev AMI (45-60 minutes)
packer build windows-server-2025-ue-gamedev.pkr.hcl

# Note the AMI ID from the output
# Example: ami-0123456789abcdef0
```

**The AMI will be named**: `vdi-ue-gamedev-windows-server-2025-YYYY-MM-DD-HH-MM-SS`

### Step 3: Use the Examples

**Navigate to an example directory and deploy:**

```bash
# For public internet access
cd modules/vdi/examples/public-connectivity/

# For private VPN access
# cd modules/vdi/examples/private-connectivity/
```

**The public connectivity example includes:**

```terraform
module "vdi" {
  # Update source path based on your setup:
  # Local: "./path/to/modules/vdi" (relative path to where you put the module)
  # Remote: "github.com/aws-games/cloud-game-development-toolkit//modules/vdi?ref=main"
  source = "./modules/vdi"

  # Core Configuration
  project_prefix = "gamedev"
  region         = data.aws_region.current.id
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Templates (Reusable Configurations)
  templates = {
    "ue-gamedev-workstation" = {
      instance_type = "g4dn.4xlarge"
      ami           = data.aws_ami.vdi_ue_gamedev_ami.id
      volumes = {
        Root = {
          capacity      = 300
          type          = "gp3"
          windows_drive = "C:"
          iops          = 3000
          encrypted     = true
        }
        Projects = {
          capacity      = 2000
          type          = "gp3"
          windows_drive = "D:"
          iops          = 3000
          encrypted     = true
        }
      }
    }
  }

  # Workstations (Infrastructure Placement)
  workstations = {
    "vdi-001" = {
      template_key      = "ue-gamedev-workstation"
      subnet_id         = aws_subnet.vdi_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_sg.id]
      allowed_cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    }
  }

  # Users (Authentication & Identity)
  users = {
    "naruto-uzumaki" = {
      given_name  = "Naruto"
      family_name = "Uzumaki"
      email       = "naruto@konoha.com"
      type        = "administrator"  # "administrator" or "user"
      # administrator: Added to Windows Administrators group, created on ALL workstations
      # user: Added to Windows Users group, created only on assigned workstation
    }
  }

  # Assignments (User-to-Workstation Mapping)
  workstation_assignments = {
    "vdi-001" = {
      user = "naruto-uzumaki"
    }
  }

  # Optional features
  enable_centralized_logging = true
}
```

### Step 4: Deploy Infrastructure

```bash
# From the example directory (e.g., modules/vdi/examples/public-connectivity/)

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Get connection details
terraform output connection_info
```

### Step 5: Connect to VPN (Private Connectivity Only)

**Skip this step if using public connectivity.**

**Find your VPN bucket:**
```bash
aws s3 ls | grep vdi-vpn-configs
```

**Download VPN configuration:**

**⚠️ IMPORTANT: After `terraform apply`, wait 1-3 hours before connecting**
- Client VPN endpoints use DNS names that need time to propagate globally
- The endpoint shows "available" but DNS resolution may fail initially
- This is normal AWS behavior - do not recreate the endpoint

**macOS/Linux:**
```bash
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/naruto-uzumaki/naruto-uzumaki.ovpn ~/Downloads/
```

**Windows:**
```cmd
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/naruto-uzumaki/naruto-uzumaki.ovpn %USERPROFILE%\Downloads\
```

**Connect to VPN:**

**Option A: AWS VPN Client (Recommended)**

- Download: [AWS VPN Client](https://aws.amazon.com/vpn/client-vpn-download/)
- Setup Guide: [AWS Client VPN User Guide](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect.html)
- Import .ovpn file and connect via GUI
- User-friendly GUI interface

**Option B: OpenVPN (Alternative)**

**macOS/Linux:**
```bash
# Install: brew install openvpn (macOS) or apt install openvpn (Linux)
sudo openvpn --config ~/Downloads/naruto-uzumaki.ovpn
# Runs in terminal, Ctrl+C to disconnect
```

**Windows:**
```cmd
# Install OpenVPN from https://openvpn.net/client/
# Then run from Downloads folder:
cd %USERPROFILE%\Downloads
openvpn --config naruto-uzumaki.ovpn
```

**Verify VPN connection:**
```bash
# Test internal DNS resolution
nslookup naruto-uzumaki.cgd.vdi.internal
# Should resolve to private IP (10.0.x.x)
```

### Step 6: Validate Deployment

**1. Get connection details:**
```bash
# Get all connection info (shows all workstations)
terraform output connection_info
```

**2. Get specific workstation info:**
```bash
# Get specific workstation details (replace "vdi-001" with your workstation key)
terraform output -json connection_info | jq '."vdi-001"'
```

**3. Get complete login information:**
```bash
# Get all login details for a workstation (replace "vdi-001" with your workstation)
WORKSTATION="vdi-001"

# Get connection endpoints
terraform output -json connection_info | jq -r ".\"$WORKSTATION\" | {dcv_endpoint, custom_dcv_endpoint, assigned_user}"

# Get user password
USER=$(terraform output -json connection_info | jq -r ".\"$WORKSTATION\".assigned_user")
aws secretsmanager get-secret-value \
  --secret-id "cgd/$WORKSTATION/users/$USER" \
  --query SecretString --output text | jq -r '{username, password}'
```

**4. Verify deployment:**

> **Note**: For private connectivity, connect to VPN first (see Connection Guide section below)

```bash
# Check installation progress
INSTANCE_ID=$(terraform output -json connection_info | jq -r '."vdi-001".instance_id')
aws ssm list-command-invocations \
  --instance-id $INSTANCE_ID \
  --query 'CommandInvocations[?contains(Comment,`Immediate`)].{Status:Status,Document:DocumentName}' \
  --output table

# Test connectivity
DCV_ENDPOINT=$(terraform output -json connection_info | jq -r '."vdi-001".dcv_endpoint')
curl -k $DCV_ENDPOINT
# Should return DCV login page HTML
```

## Connection Guide

### Get Connection Information
```bash
# Get all connection endpoints
terraform output -json connection_info | jq '."vdi-001"'

# Shows: dcv_endpoint, custom_dcv_endpoint (if private), rdp_endpoint, etc.
```

### Connect via DCV (Recommended)
1. **Open browser** to your DCV endpoint
2. **Accept certificate warning** (self-signed certificates)
3. **Login** with your username and Secrets Manager password
4. **Verify** Windows desktop loads

### Emergency Administrator Access
```bash
# Get Administrator password
terraform output -json private_keys | jq -r '."vdi-001"' > temp_key.pem
chmod 600 temp_key.pem
aws ec2 get-password-data \
  --instance-id $(terraform output -json connection_info | jq -r '."vdi-001".instance_id') \
  --priv-launch-key temp_key.pem --query 'PasswordData' --output text
rm temp_key.pem
```

**Alternative: AWS Console** → EC2 → Instances → Actions → Security → Get Windows password

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

### Private Connectivity Client Setup

**Step 1: Download VPN Configuration**

```bash
# Get S3 bucket name from Terraform output
terraform output

# Download your .ovpn file (one per user, works for all workstations)
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/vdiadmin/vdiadmin.ovpn ./vdiadmin.ovpn

# Or for regular users
aws s3 cp s3://cgd-vdi-vpn-configs-XXXXXXXX/john-doe/john-doe.ovpn ./john-doe.ovpn
```

**Step 2: Install VPN Client**

**Option A: OpenVPN (Free)**
- **macOS**: `brew install openvpn` or download from [OpenVPN.net](https://openvpn.net/client/)
- **Windows**: Download from [OpenVPN.net](https://openvpn.net/client/)
- **Linux**: `sudo apt install openvpn` or `sudo yum install openvpn`

**Option B: AWS VPN Client (Recommended)**
- Download from [AWS VPN Client](https://aws.amazon.com/vpn/client-vpn-download/)
- Import .ovpn file directly

**Step 3: Connect to VPN**

```bash
# OpenVPN command line
sudo openvpn --config vdiadmin.ovpn

# Or use GUI client to import and connect
```

**Step 4: Verify VPN Connection**

```bash
# Test internal DNS resolution (for assigned users)
nslookup naruto-uzumaki.vdi.internal
# Should resolve to private IP (10.0.x.x)

# Test DCV connectivity
curl -k https://naruto-uzumaki.vdi.internal:8443
# Should return DCV login page HTML

# For fleet admins (vdiadmin), access any workstation by private IP
curl -k https://10.0.1.100:8443  # Direct private IP access
```

**Step 5: Connect via DCV**

**For Fleet Admins (vdiadmin):**
- **URL**: `https://10.0.1.100:8443` (any workstation private IP)
- **Username**: `vdiadmin`
- **Password**: From Secrets Manager

**For Assigned Users:**
- **URL**: `https://naruto-uzumaki.vdi.internal:8443`
- **Username**: `naruto-uzumaki`
- **Password**: From Secrets Manager

### Remote Desktop Protocol (RDP)

**Windows Built-in RDP:**

1. Open Remote Desktop Connection (mstsc)
2. Enter workstation IP address or internal DNS name
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
# Boot-time session creation (via SSM automation):
dcv create-session --owner=assigned-user assigned-user-session
```

**Session Management Commands:**
```powershell
# List all sessions
dcv list-sessions

# Close session
dcv close-session assigned-user-session

# Recreate session with different owner
dcv create-session --owner new-user new-user-session
```

**Administrator Access Options:**
- **Standard RDP**: Connect as Administrator/vdiadmin for separate admin desktop
- **SSM Session Manager**: `aws ssm start-session --target instance-id` for command-line access
- **Fleet Manager**: AWS Console → Fleet Manager → Connect with Remote Desktop

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

#### 5. SSM-Based Configuration Approach

**Why We Use SSM Instead of User Data**:

The VDI module uses AWS Systems Manager (SSM) for workstation configuration instead of EC2 user data for several technical reasons:

- ✅ **Line ending compatibility** - Avoids Windows/macOS line ending issues (`CRLF` vs `LF`) that cause "unrecognized user data format" errors
- ✅ **More reliable** - SSM handles retries and error recovery automatically
- ✅ **Better debugging** - Full execution logs available in CloudWatch and SSM console
- ✅ **Flexible timing** - Can run configuration at any time, not just at boot
- ✅ **Per-workstation customization** - Different software packages per workstation
- ✅ **Predictable execution** - 3-minute wait ensures SSM agent is ready

**Common User Data Issues on Windows Server 2025:**

When developing on macOS/Linux and deploying to Windows, user data often fails with:
```
EC2Launch v2: User data format: unrecognized
```

This typically occurs because:
- **Line endings**: macOS/Linux use `LF`, Windows expects `CRLF`
- **EC2Launch v2 strictness**: More sensitive to formatting than previous versions
- **Complex PowerShell**: Multi-line scripts with embedded quotes are error-prone

**Why Packer AMIs Work Fine:**

Packer AMI builds succeed because:
- **Packer handles line endings** - Automatically converts line endings for target OS
- **Direct WinRM execution** - Packer uses WinRM, not EC2 user data for PowerShell
- **Build-time vs runtime** - AMI scripts run during build, not at instance launch
- **Simpler scripts** - AMI scripts typically install software, not create dynamic users

**SSM Configuration Process**:

1. **Instance boots** with no user data (clean startup)
2. **Terraform waits** 3 minutes for SSM agent to be ready
3. **SSM associations execute** user creation and software installation
4. **All configuration** happens through reliable SSM documents

**Benefits of This Approach**:
- **Predictable timing** - Always wait exactly 3 minutes for SSM readiness
- **Better error handling** - SSM provides detailed execution logs
- **Flexible software installation** - Different packages per workstation
- **Debuggable** - Can view execution status in AWS console
- **Retryable** - Can re-run configuration without rebuilding instances

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

*Symptoms*: VPN client shows connection errors, timeouts, or authentication failures

*Solutions*:
- Verify .ovpn file downloaded from correct S3 folder: `aws s3 ls s3://cgd-vdi-vpn-configs-XXXXXXXX/`
- Check VPN client supports AWS Client VPN (OpenVPN protocol)
- Ensure certificates are valid and not expired
- Try different VPN client (AWS VPN Client vs OpenVPN)
- Check local firewall isn't blocking VPN traffic

**Internal DNS Not Resolving:**

*Symptoms*: `john-doe.vdi.internal` doesn't resolve or resolves to wrong IP

*Solutions*:
```bash
# Test DNS resolution after VPN connection
nslookup john-doe.vdi.internal
# Should resolve to private IP (10.0.x.x)

# If not resolving, check VPN connection status
ip route | grep 192.168  # Should show VPN routes

# Test direct private IP access
curl -k https://10.0.1.100:8443  # Use actual private IP
```

**Certificate Issues:**

*Symptoms*: Authentication failures, certificate errors in VPN client

*Solutions*:
```bash
# Check certificate validity
openssl x509 -in john-doe.crt -text -noout
# Verify dates and subject

# Re-download certificates from S3
aws s3 sync s3://cgd-vdi-vpn-configs-XXXXXXXX/vdi-001-john-doe/ ./vpn-config/

# Verify certificate chain
openssl verify -CAfile ca.crt john-doe.crt
```

**VPN Stuck on "Reconnecting" - Troubleshooting Steps:**

*Symptoms*: VPN client shows "Reconnecting..." indefinitely

**Step 1: Check DNS Resolution (Most Common)**
```bash
# Test if VPN endpoint DNS resolves
nslookup [your-endpoint-name].prod.clientvpn.us-east-1.amazonaws.com
```

**⚠️ CRITICAL: If you get NXDOMAIN (DNS not found):**
- **This is NORMAL after terraform apply** - AWS DNS propagation takes time
- **Wait 1-3 hours** - Do NOT recreate the endpoint
- **DNS propagation can take up to 48 hours** in worst cases
- **The endpoint shows 'available' but DNS isn't ready yet**
- **Recreating the endpoint will restart the propagation delay**

```bash
# Test periodically until it resolves
nslookup [endpoint-name].prod.clientvpn.us-east-1.amazonaws.com 8.8.8.8
# Once it resolves, VPN connection will work
```

**Step 2: Check CIDR Overlap**
```bash
# Check your local network IP
ifconfig | grep "inet " | grep -v 127.0.0.1
# If your local IP overlaps with your client_cidr_block range, you have a conflict
# Example: Local 192.168.5.x conflicts with Client VPN 192.168.0.0/16

# Fix: Change Client VPN CIDR in main.tf
client_vpn_config = {
  client_cidr_block = "10.100.0.0/16"  # Use non-conflicting range
}
terraform apply
```

**Step 3: Check VPN Conflicts**
```bash
# Kill conflicting VPN processes
ps aux | grep -i vpn
sudo kill [process-id]  # Kill corporate VPN processes
```

**Step 4: Check Detailed Logs**
```bash
# View AWS VPN Client logs (macOS)
tail -20 ~/.config/AWSVPNClient/logs/ovpn_aws_vpn_client_*.log
# Look for DNS resolution errors or certificate issues
```

**VPN Connected But Can't Access VDI:**

*Symptoms*: VPN shows connected, but DCV/RDP connections fail

*Solutions*:
```bash
# Check VPN assigned IP
ifconfig | grep "10.100"  # Should show VPN interface with new CIDR

# Test basic connectivity to VDI subnet
ping 10.0.1.1  # VPC gateway

# Check security group rules allow VPC CIDR
# Should see 10.0.0.0/16 in allowed_cidr_blocks

# Test specific ports
telnet john-doe.vdi.internal 8443  # DCV
telnet john-doe.vdi.internal 3389  # RDP
```

**Multiple VPN Clients Conflict:**

*Symptoms*: Connection works sometimes, fails other times

*Solutions*:
- Disconnect from other VPNs (corporate VPN, etc.)
- Use only one VPN client at a time
- Check for IP address conflicts (192.168.x.x ranges)
- Restart network interface: `sudo ifconfig [interface] down && sudo ifconfig [interface] up`

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
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.5.0 |
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
| [aws_cloudwatch_log_group.vdi_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_client_vpn_authorization_rule.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_authorization_rule) | resource |
| [aws_ec2_client_vpn_endpoint.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint) | resource |
| [aws_ec2_client_vpn_network_association.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_network_association) | resource |
| [aws_ec2_client_vpn_route.vdi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_route) | resource |
| [aws_eip.workstation_eips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_instance_profile.vdi_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.vdi_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vdi_instance_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.vdi_cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.vdi_ssm_managed_instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.workstations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_key_pair.workstation_keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_route53_record.load_balancer_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.regional_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.vdi_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.vdi_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.vdi_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone.vdi_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
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
| [aws_secretsmanager_secret.user_passwords](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.user_passwords](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.workstation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_association.vdi_user_creation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.create_vdi_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_security_group_egress_rule.all_outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.dcv_https_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.dcv_quic_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.rdp_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.rdp_access_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.user_passwords](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.wait_for_ssm_agent](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [tls_cert_request.client_vpn_users](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.client_vpn_users](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.client_vpn_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.client_vpn_server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.client_vpn_users](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.workstation_keys](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.client_vpn_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [tls_self_signed_cert.client_vpn_server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_ami.windows_server_2025](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.vdi_instance_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | Default CIDR blocks allowed for VDI access (can be overridden per user) | `list(string)` | <pre>[<br>  "10.0.0.0/16"<br>]</pre> | no |
| <a name="input_ami_prefix"></a> [ami\_prefix](#input\_ami\_prefix) | AMI name prefix for auto-discovery when ami not specified in templates | `string` | `"vdi_lightweight_ws2025"` | no |
| <a name="input_client_vpn_config"></a> [client\_vpn\_config](#input\_client\_vpn\_config) | Client VPN configuration for private connectivity | <pre>object({<br>    client_cidr_block = optional(string, "192.168.0.0/16")<br>    generate_client_configs = optional(bool, true)<br>  })</pre> | `{}` | no |
| <a name="input_connectivity_type"></a> [connectivity\_type](#input\_connectivity\_type) | VDI connectivity type: 'public' for internet access, 'private' for Client VPN access | `string` | `"public"` | no |
| <a name="input_create_default_security_groups"></a> [create\_default\_security\_groups](#input\_create\_default\_security\_groups) | Create default security groups for VDI workstations | `bool` | `true` | no |
| <a name="input_dcv_session_permissions"></a> [dcv\_session\_permissions](#input\_dcv\_session\_permissions) | DCV session management and permission configuration | <pre>object({<br>    admin_default_permissions = optional(string, "full")  # "view" or "full"<br>    user_can_share_session   = optional(bool, false)     # Allow users to share their own sessions<br>    auto_create_user_session = optional(bool, true)      # Create session for assigned user at boot<br>  })</pre> | `{}` | no |
| <a name="input_debug_mode"></a> [debug\_mode](#input\_debug\_mode) | Enable debug mode to force SSM execution on every terraform apply | `bool` | `false` | no |
| <a name="input_dns_config"></a> [dns\_config](#input\_dns\_config) | DNS configuration for VDI instances and services | <pre>object({<br>    private_zone = object({<br>      enabled     = optional(bool, true)<br>      domain_name = optional(string, "vdi.internal")<br>      vpc_id      = optional(string, null)<br>    })<br>    regional_endpoints = object({<br>      enabled = optional(bool, false)<br>      pattern = optional(string, "{region}.{domain}")<br>    })<br>    load_balancer_alias = object({<br>      enabled   = optional(bool, false)<br>      subdomain = optional(string, "lb")<br>    })<br>  })</pre> | `null` | no |
| <a name="input_dual_admin_pattern"></a> [dual\_admin\_pattern](#input\_dual\_admin\_pattern) | Dual admin account pattern configuration (no automatic rotation - use AD for that) | <pre>object({<br>    enabled                   = optional(bool, true)   # Use dual admin accounts<br>    administrator_unchanging  = optional(bool, true)   # Administrator account never rotates (break-glass)<br>    managed_admin_name       = optional(string, "VDIAdmin")  # Managed admin account name<br>    user_can_change_password = optional(bool, false)   # Allow users to change their own passwords<br>  })</pre> | `{}` | no |
| <a name="input_ebs_encryption_enabled"></a> [ebs\_encryption\_enabled](#input\_ebs\_encryption\_enabled) | Enable EBS encryption for VDI volumes | `bool` | `false` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | KMS key ID for EBS encryption (if encryption enabled) | `string` | `null` | no |
| <a name="input_enable_admin_fleet_access"></a> [enable\_admin\_fleet\_access](#input\_enable\_admin\_fleet\_access) | Enable admin accounts (Administrator, VDIAdmin, DomainAdmin) to access all VDI instances in the deployment | `bool` | `true` | no |
| <a name="input_enable_centralized_logging"></a> [enable\_centralized\_logging](#input\_enable\_centralized\_logging) | Enable centralized logging with CloudWatch log groups following CGD Toolkit patterns | `bool` | `false` | no |
| <a name="input_enable_private_connectivity"></a> [enable\_private\_connectivity](#input\_enable\_private\_connectivity) | Enable private connectivity infrastructure (Client VPN endpoint, S3 bucket for configs) | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_force_user_creation_rerun"></a> [force\_user\_creation\_rerun](#input\_force\_user\_creation\_rerun) | Change this value to force SSM user creation to re-run (e.g., after IAM permission fixes) | `string` | `"1"` | no |
| <a name="input_log_group_prefix"></a> [log\_group\_prefix](#input\_log\_group\_prefix) | Prefix for CloudWatch log group names (useful for multi-module deployments) | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `30` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | Prefix for resource names | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_s3_bucket_prefix"></a> [s3\_bucket\_prefix](#input\_s3\_bucket\_prefix) | Prefix for S3 bucket names (will be combined with project\_prefix and random suffix) | `string` | `"vdi"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IaC": "Terraform",<br>  "ModuleBy": "CGD-Toolkit",<br>  "ModuleName": "terraform-aws-vdi",<br>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi",<br>  "RootModuleName": "-"<br>}</pre> | no |
| <a name="input_templates"></a> [templates](#input\_templates) | Configuration blueprints defining instance types and named volumes with Windows drive mapping.<br><br>**KEY BECOMES TEMPLATE NAME**: The map key (e.g., "ue-developer") becomes the template name referenced by workstations.<br><br>Templates provide reusable configurations that can be referenced by multiple workstations via template\_key.<br><br>Example:<br>templates = {<br>  "ue-developer" = {           # ← This key becomes the template name<br>    instance\_type = "g4dn.2xlarge"<br>    gpu\_enabled   = true<br>    volumes = {<br>      Root = { capacity = 256, type = "gp3", windows\_drive = "C:" }<br>      Projects = { capacity = 1024, type = "gp3", windows\_drive = "D:" }<br>    }<br>  }<br>  "basic-workstation" = {      # ← Another template name<br>    instance\_type = "g4dn.xlarge"<br>    gpu\_enabled   = true<br>  }<br>}<br><br># Referenced by workstations:<br>workstations = {<br>  "alice-ws" = {<br>    template\_key = "ue-developer"    # ← References template by key<br>  }<br>}<br><br>Valid volume types: "gp2", "gp3", "io1", "io2"<br>Windows drives: "C:", "D:", "E:", etc. | <pre>map(object({<br>    # Core compute configuration<br>    instance_type = string<br>    ami           = optional(string, null)<br>    <br>    # Hardware configuration<br>    gpu_enabled       = optional(bool, false)<br>    <br>    # Named volumes with Windows drive mapping<br>    volumes = map(object({<br>      capacity      = number<br>      type          = string<br>      windows_drive = string<br>      iops          = optional(number, 3000)<br>      throughput    = optional(number, 125)<br>      encrypted     = optional(bool, true)<br>    }))<br>    <br>    # Optional configuration<br>    iam_instance_profile = optional(string, null)<br>    tags                 = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Local Windows user accounts with Windows group types and network connectivity (managed via Secrets Manager)<br><br>**KEY BECOMES WINDOWS USERNAME**: The map key (e.g., "john-doe") becomes the actual Windows username created on VDI instances.<br><br>type options (Windows groups):<br>- "administrator": User added to Windows Administrators group, created on ALL workstations<br>- "user": User added to Windows Users group, created only on assigned workstation<br><br>connectivity\_type options (network access):<br>- "public": User accesses VDI via public internet (default)<br>- "private": User accesses VDI via Client VPN (generates VPN config)<br><br>Example:<br>users = {<br>  "vdiadmin" = {              # ← This key becomes Windows username "vdiadmin"<br>    given\_name = "VDI"<br>    family\_name = "Administrator"<br>    email = "admin@company.com"<br>    type = "administrator"      # Windows Administrators group<br>  }<br>  "naruto-uzumaki" = {         # ← This key becomes Windows username "naruto-uzumaki"<br>    given\_name = "Naruto"<br>    family\_name = "Uzumaki"<br>    email = "naruto@konoha.com"<br>    type = "user"               # Windows Users group<br>  }<br>}<br><br># Referenced by assignments:<br>workstation\_assignments = {<br>  "vdi-001" = {<br>    user = "naruto-uzumaki"     # ← Must match users{} key<br>  }<br>} | <pre>map(object({<br>    given_name        = string<br>    family_name       = string<br>    email             = string<br>    type              = optional(string, "user")  # "administrator" or "user" (Windows group)<br>    connectivity_type = optional(string, "public")  # "public" or "private" (network access)<br>    tags              = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where VDI instances will be deployed | `string` | n/a | yes |
| <a name="input_workstation_assignments"></a> [workstation\_assignments](#input\_workstation\_assignments) | Workstation assignments mapping workstations to users.<br><br>Key must match a workstation key. Maps each workstation to a specific user.<br><br>Example:<br>workstation\_assignments = {<br>  "alice-workstation" = {<br>    user = "alice"          # References users{} key<br>  }<br>  "bob-workstation" = {<br>    user = "bob-smith"      # References users{} key<br>  }<br>}<br><br>All users use local Windows accounts with Secrets Manager authentication. | <pre>map(object({<br>    user = string<br>    tags = optional(map(string), {})<br>  }))</pre> | `{}` | no |
| <a name="input_workstations"></a> [workstations](#input\_workstations) | Physical infrastructure instances with template references and placement configuration.<br><br>**KEY BECOMES WORKSTATION NAME**: The map key (e.g., "alice-workstation") becomes the workstation identifier used throughout the module.<br><br>Workstations inherit configuration from templates via template\_key reference.<br><br>Example:<br>workstations = {<br>  "alice-workstation" = {        # ← This key becomes the workstation name<br>    template\_key = "ue-developer"  # ← References templates{} key<br>    subnet\_id = "subnet-123"<br>    availability\_zone = "us-east-1a"<br>    security\_groups = ["sg-456"]<br>    allowed\_cidr\_blocks = ["203.0.113.1/32"]<br>  }<br>  "vdi-001" = {                  # ← Another workstation name<br>    template\_key = "basic-workstation"<br>    subnet\_id = "subnet-456"<br>  }<br>}<br><br># Referenced by assignments:<br>workstation\_assignments = {<br>  "alice-workstation" = {        # ← Must match workstations{} key<br>    user = "alice"                # ← References users{} key<br>  }<br>} | <pre>map(object({<br>    # Template reference<br>    template_key = string<br>    <br>    # Infrastructure placement<br>    subnet_id         = string<br>    availability_zone = string<br>    security_groups   = list(string)<br>    <br>    # Optional overrides<br>    allowed_cidr_blocks = optional(list(string), ["10.0.0.0/16"])<br>    tags                = optional(map(string), {})<br>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | AMI ID used for workstations |
| <a name="output_connection_info"></a> [connection\_info](#output\_connection\_info) | Complete connection information for VDI workstations |
| <a name="output_emergency_key_paths"></a> [emergency\_key\_paths](#output\_emergency\_key\_paths) | S3 paths for emergency private keys |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | Map of workstation instance IDs |
| <a name="output_password_retrieval_commands"></a> [password\_retrieval\_commands](#output\_password\_retrieval\_commands) | Commands to retrieve passwords for each workstation |
| <a name="output_private_keys"></a> [private\_keys](#output\_private\_keys) | Private keys for emergency access (sensitive) |
| <a name="output_public_ips"></a> [public\_ips](#output\_public\_ips) | Map of workstation public IP addresses |
| <a name="output_secrets_manager_arns"></a> [secrets\_manager\_arns](#output\_secrets\_manager\_arns) | Secrets Manager ARNs for user passwords |
<!-- END_TF_DOCS -->