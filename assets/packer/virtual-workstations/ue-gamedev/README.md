# VDI Unreal Engine GameDev AMI

This Packer template creates a Windows Server 2025 AMI optimized for Unreal Engine game development with pre-installed development tools.

## What's Included

**Base Infrastructure (from shared/base_infrastructure.ps1):**
- Windows Server 2025 base
- NVIDIA GRID drivers (GPU instances)
- Amazon DCV remote desktop server
- AWS CLI and PowerShell modules
- Git, Python, Chocolatey
- Perforce (P4 command line + P4V visual client)
- Active Directory management tools

**Unreal Engine Development Stack (from unreal_development_stack.ps1):**
- Visual Studio 2022 Community with game development workloads:
  - Managed Desktop (.NET)
  - Native Desktop (C++)
  - .NET Cross-Platform Development
  - Visual C++ Diagnostic Tools
  - Address Sanitizer
  - Windows 10 SDK (10.0.18362.0)
  - Unreal Engine Component
- Epic Games Launcher
- Desktop shortcut for Epic Games Launcher

## Build Instructions

1. **Navigate to template directory:**
   ```bash
   cd assets/packer/virtual-workstations/ue-gamedev/
   ```

2. **Build AMI:**
   ```bash
   packer build windows-server-2025-ue-gamedev.pkr.hcl
   ```

3. **Optional - Custom variables:**
   ```bash
   # Override instance type or other settings
   packer build -var 'instance_type=g4dn.4xlarge' windows-server-2025-ue-gamedev.pkr.hcl
   ```

## Build Time & Requirements

- **Estimated Build Time:** 45-60 minutes
- **Instance Type:** g4dn.2xlarge (default, GPU required)
- **Storage:** 150GB root volume (larger for Visual Studio + UE)
- **Network:** Requires internet access for software downloads

## Post-Build Setup

**Unreal Engine Installation:**
- Epic Games Launcher is pre-installed
- Unreal Engine must be installed manually after first login:
  1. Launch Epic Games Launcher from desktop
  2. Create/sign in to Epic Games account
  3. Navigate to Unreal Engine tab
  4. Click "Install Engine" and select desired version
  5. Choose installation location (recommend D:\\ drive)

**Why Manual UE Installation:**
- Requires Epic Games account authentication
- Requires EULA acceptance
- No silent installation method available
- User-specific licensing requirements

## Usage with VDI Module

Use the resulting AMI with the VDI Terraform module:

```hcl
module "vdi" {
  source = "./modules/vdi"

  templates = {
    "ue-developer" = {
      instance_type = "g4dn.xlarge"
      ami = "ami-0123456789abcdef0"  # Your built AMI ID
      # No need for software_packages - already installed
    }
  }

  users = {
    "game-dev" = {
      given_name = "Game"
      family_name = "Developer"
      type = "user"
    }
  }
}
```

## Development Ready Features

**Immediate Development:**
- Visual Studio 2022 with all UE workloads
- Git for version control
- Perforce for enterprise VCS
- Python for scripting
- AWS CLI for cloud integration

**GPU Acceleration:**
- NVIDIA GRID drivers pre-installed
- DCV hardware acceleration enabled
- Ready for UE rendering and CUDA development

**User Experience:**
- Desktop shortcuts for all tools
- Optimized PATH configuration
- Development-friendly PowerShell profile

## Troubleshooting

**Build Failures:**
- Ensure GPU instance type (g4dn.* required)
- Check internet connectivity for downloads
- Verify AWS credentials and permissions

**Visual Studio Issues:**
- Build may take 45+ minutes (normal)
- Large download sizes require stable connection
- Workload installation is comprehensive

**Epic Games Launcher:**
- Pre-installed but requires user login
- UE installation is user-initiated
- Account creation may be required

## Alternative Templates

- **[Lightweight AMI](../lightweight/README.md)** - Runtime software customization

For faster iteration during development, consider the lightweight template with runtime software installation via the VDI module.
