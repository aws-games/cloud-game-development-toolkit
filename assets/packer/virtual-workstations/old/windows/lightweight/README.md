# VDI Lightweight AMI Builder

## Overview
This Packer template creates a lightweight Windows Server 2025 AMI optimized for VDI workloads with minimal components:

- **Windows Server 2025** - Base operating system
- **DCV Server** - Remote desktop capability  
- **NVIDIA GRID drivers** - GPU support (GPU instances only)
- **PowerShell modules** - AWS management tools
- **SSM Agent** - Systems Manager connectivity

## Build Time
~20-30 minutes

## Usage

### Prerequisites
- AWS credentials configured ([AWS Profile Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html))
- Packer installed

### Build AMI
```bash
cd modules/vdi/packer

# Option 1: Use defaults (default VPC)
packer build windows-server-2025-lightweight.pkr.hcl

# Option 2: Customize with variables file
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
# Edit variables.pkrvars.hcl as needed
packer build -var-file=variables.pkrvars.hcl windows-server-2025-lightweight.pkr.hcl
```

### Configuration
Customize `variables.pkrvars.hcl` for:
- Specific VPC/subnet (optional - uses default VPC)
- Instance type (default: g4dn.2xlarge)
- Root volume size (default: 80 GB)
- AMI naming prefix

## What's NOT Included
Software installation is handled at runtime via SSM (user configurable):
- Visual Studio
- Git  
- Unreal Engine
- Perforce
- Custom applications

Users can choose which software packages to install per workstation via the `software_packages` variable.

## Benefits
- **Fast deployment** - Infrastructure ready in 2-3 minutes
- **Flexible software** - Per-assignment customization
- **Easy updates** - Change software without rebuilding AMI
- **Smaller AMI** - Reduced storage costs
- **Async installation** - Software installs don't block Terraform