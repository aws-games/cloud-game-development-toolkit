# Virtual Workstations Packer Templates

## 🚨 CRITICAL REQUIREMENTS

### GPU Instance Types Required

**⚠️ ALL TEMPLATES BUILD NVIDIA-OPTIMIZED AMIs**

**For Packer Build:**
- ✅ **GPU instances**: `g4dn.*`, `g5.*`, `p3.*`, `p4.*` (full functionality)
- ⚠️ **Non-GPU instances**: `t3.*`, `m5.*`, `c5.*`, `r5.*` (builds succeed, skips NVIDIA drivers)
- 🔧 **Current defaults**: `g4dn.2xlarge` (recommended for production)
- 🎓 **Workshop friendly**: C instances work fine for learning/demos

**For Final VDI Deployment:**
- ✅ **Recommended**: GPU instances for full functionality
- ⚠️ **Will boot but degraded**: Non-GPU instances (software rendering only)
- ❌ **GPU apps will fail**: Unreal Engine, CUDA applications

**Instance Compatibility Matrix:**

| Packer Build | Final Instance | Result |
|--------------|----------------|--------|
| `g4dn.2xlarge` | `g4dn.xlarge` | ✅ Full GPU acceleration |
| `g4dn.2xlarge` | `g4dn.4xlarge` | ✅ Full GPU acceleration |
| `g4dn.2xlarge` | `m5.2xlarge` | ⚠️ Boots, no GPU, slow DCV |
| `g4dn.2xlarge` | `t3.medium` | ❌ Poor performance, apps fail |

### Directory Structure Required

⚠️ **CRITICAL: These templates require the complete directory structure and cannot be used standalone without customization.**

## Directory Structure

```
assets/packer/virtual-workstations/
├── shared/                    # REQUIRED - Base infrastructure scripts
│   ├── base_infrastructure.ps1    # NVIDIA + DCV + AWS tools + dev tools
│   ├── sysprep.ps1               # EC2Launch configuration
│   └── userdata.ps1              # Packer WinRM setup
├── lightweight/               # Base VDI AMI
├── ue-gamedev/               # Unreal Engine development AMI
├── artists/                  # Creative tools AMI (planned)
└── old/                      # Previous templates (archived)
```

## Prerequisites

**You MUST have the complete CGD Toolkit repository:**

```bash
# Clone the entire repository
git clone https://github.com/aws-games/cloud-game-development-toolkit.git
cd cloud-game-development-toolkit

# Verify structure exists
ls assets/packer/virtual-workstations/shared/
# Should show: base_infrastructure.ps1  sysprep.ps1  userdata.ps1
```

**Build with defaults:**

Packer will use your current AWS session and the defaults defined in the template:

```bash
# Navigate to the template directory
cd assets/packer/virtual-workstations/lightweight/

# Build with defaults (recommended)
packer build windows-server-2025-lightweight.pkr.hcl
```

**To override default instance type (optional):**

```bash
# Create variables file (optional)
cp variables.pkrvars.hcl.example variables.pkrvars.hcl

# Edit variables.pkrvars.hcl
instance_type = "g4dn.4xlarge"  # Must be GPU-enabled

# Build with custom variables
packer build -var-file="variables.pkrvars.hcl" windows-server-2025-lightweight.pkr.hcl
```

## Available Templates

### Lightweight AMI
**Best for:** Runtime software customization via VDI Terraform module

```bash
# Navigate to lightweight template directory
cd assets/packer/virtual-workstations/lightweight/

# Build lightweight AMI
packer build windows-server-2025-lightweight.pkr.hcl
```

**Includes:** Windows Server 2025 + DCV + AWS CLI + PowerShell + Git + Perforce + Python + Chocolatey
**Build Time:** ~25 minutes

### UE GameDev AMI
**Best for:** Immediate Unreal Engine development

```bash
# Navigate to UE GameDev template directory
cd assets/packer/virtual-workstations/ue-gamedev/

# Build UE GameDev AMI
packer build windows-server-2025-ue-gamedev.pkr.hcl
```

**Includes:** Lightweight base + Visual Studio 2022 + Unreal Engine 5.3
**Build Time:** ~45 minutes

### Artists AMI (Planned)
**Best for:** Creative workflows

```bash
# Coming soon
cd assets/packer/virtual-workstations/artists/
packer build windows-server-2025-artists.pkr.hcl
```

**Will Include:** Lightweight base + Blender + Maya + Creative Suite

## Shared Infrastructure

All templates use the shared base infrastructure script that provides:

- **NVIDIA GRID drivers** (GPU instances)
- **Amazon DCV** remote desktop server
- **AWS CLI** and PowerShell modules
- **Git, Perforce, Python** development tools
- **Chocolatey** package manager
- **Active Directory** management tools
- **System PATH** configuration

## Template Dependencies

**Each template references shared scripts:**
- `../shared/base_infrastructure.ps1` - Common infrastructure setup
- `../shared/sysprep.ps1` - EC2Launch configuration
- `../shared/userdata.ps1` - Packer WinRM connectivity

**This is why the complete directory structure is required.**

## Usage with VDI Module

After building an AMI, use it with the VDI Terraform module:

```hcl
module "vdi" {
  source = "path/to/vdi/module"

  # Core configuration
  project_prefix = "gamedev"
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Templates reference your built AMIs
  templates = {
    "developer" = {
      instance_type = "g4dn.2xlarge"
      ami           = "ami-0d22cd2c73f6b623"  # Use AMI ID from Packer build output
      volumes = {
        Root = { capacity = 256, type = "gp3", windows_drive = "C:" }
        Projects = { capacity = 1024, type = "gp3", windows_drive = "D:" }
      }
    }
  }

  # Workstations and users configuration
  workstations = { /* ... */ }
  users = { /* ... */ }
  workstation_assignments = { /* ... */ }
}
```

## Troubleshooting

**"Script not found" errors:**
- Ensure you're running from the correct subdirectory
- Verify the `shared/` directory exists at the same level
- Check that you have the complete repository structure

**Build failures:**
- Verify AWS credentials are configured
- Check VPC/subnet configuration in variables
- Ensure instance type supports GPU drivers (g4dn.* recommended)

## Contributing

When adding new templates:
1. Create new subdirectory (e.g., `audio/`)
2. Reference shared scripts: `../shared/base_infrastructure.ps1`
3. Add template-specific scripts in the subdirectory
4. Update this README with the new template
5. Add dependency warnings to the template file
