# Game Development VDI AMI

## Overview
Comprehensive Windows Server 2025 AMI with full game development stack pre-installed.

**Build time**: ~45 minutes

## Included Software
- Windows Server 2025
- DCV Server
- NVIDIA GRID drivers
- Visual Studio 2022 Community (with game dev workloads)
- Unreal Engine development tools
- Git version control
- Perforce client tools
- Development utilities and tools

## Usage

### Prerequisites
- AWS credentials configured ([AWS Profile Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html))
- Packer installed

### Build AMI
```bash
cd game-dev/

# Use defaults (default VPC)
packer build windows-server-2025.pkr.hcl

# Or customize with variables file
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
# Edit variables.pkrvars.hcl as needed
packer build -var-file=variables.pkrvars.hcl windows-server-2025.pkr.hcl
```

## Benefits
- **Ready to use** - All software pre-installed
- **Consistent environment** - Same setup for all users
- **No runtime installation** - Immediate productivity

## Use Cases
- Teams with standardized toolchain
- Environments where build time is not critical
- Users who prefer everything pre-configured