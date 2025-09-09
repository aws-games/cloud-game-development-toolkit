# Virtual Workstations Packer Templates

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

## Available Templates

### Lightweight AMI
**Best for:** Runtime software customization via VDI Terraform module

```bash
cd assets/packer/virtual-workstations/lightweight/
packer build windows-server-2025-lightweight.pkr.hcl
```

**Includes:** Windows Server 2025 + DCV + AWS CLI + PowerShell + Git + Perforce + Python + Chocolatey
**Build Time:** ~25 minutes

### UE GameDev AMI  
**Best for:** Immediate Unreal Engine development

```bash
cd assets/packer/virtual-workstations/ue-gamedev/
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
  
  # Option 1: Auto-discovery via data source (requires ami_prefix variable)
  ami_prefix = "vdi-lightweight-windows-server-2025"  # Module uses data source to find latest
  
  # Option 2: Specific AMI ID (recommended after Packer build)
  # ami = "ami-0d22cd2c73f6b623"  # Use the AMI ID from your Packer build output
  
  # Configure runtime software (lightweight AMI)
  templates = {
    "developer" = {
      software_packages = [
        "chocolatey",
        "visual-studio-2022", 
        "unreal-engine-5.3"
      ]
    }
  }
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