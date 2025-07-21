# Windows Virtual Workstation with Packer

This directory contains Packer configuration files and scripts for building Windows Server 2025 AMIs optimized for game development workstations with GPU support, particularly for Unreal Engine development.

## What's Included

This project provides a complete solution for creating Windows-based virtual workstations in AWS with:

- **GPU Support**: Automatic detection and configuration of NVIDIA GPUs
- **Remote Access**: Amazon DCV for high-performance remote desktop access
- **Development Tools**: Visual Studio, Git, Python, and other essential tools
- **Unreal Engine Support**: Epic Games Launcher pre-installed

## File Structure

- `windows-server-2025.pkr.hcl` - Main Packer template for Windows Server 2025
- `userdata.ps1` - Initial Windows setup script for WinRM configuration
- `base_setup_with_gpu_check.ps1` - Core system setup with GPU detection and DCV installation
- `dev_tools.ps1` - Development tools installation script
- `unreal_dev.ps1` - Unreal Engine development environment setup

## Prerequisites

Before using this Packer configuration, ensure you have:

1. An AWS account with appropriate permissions
2. [Packer](https://www.packer.io/downloads) installed on your local machine
3. AWS credentials configured either via environment variables, shared credentials file, or IAM roles
4. Basic understanding of AWS services (VPC, subnets)
5. A VPC and subnet in your AWS account where Packer can build the AMI

## Getting Started

### Step 1: Configure Variables

You can pass variables directly to the Packer command:

```bash
packer build \
  -var="region=us-east-1" \
  -var="vpc_id=vpc-0123456789abcdef0" \
  -var="subnet_id=subnet-0123456789abcdef0" \
  -var="instance_type=g4dn.2xlarge" \
  windows-server-2025.pkr.hcl
```

### Step 2: Run Packer Build

From this directory, run the following command:

```bash
packer build windows-server-2025.pkr.hcl
```

This will start the build process, which includes:
1. Launching a Windows Server 2025 instance
2. Configuring WinRM for Packer connectivity
3. Running provisioning scripts
4. Creating and registering the final AMI

The build process may take 30-45 minutes depending on your instance type and network speed.

## Script Details

### base_setup_with_gpu_check.ps1

This script handles the core system setup, including:
- System configuration and logging
- Amazon DCV installation with virtual display driver for non-GPU instances
- AWS S3 tools for driver install
- NVIDIA GPU detection and driver installation
- Sysprep configuration for GRID drivers compatibility

### dev_tools.ps1

Installs development tools necessary for game development:
- Chocolatey package manager
- Visual Studio 2022 Community with C++ workload
- AWS CLI
- Git for source control
- Perforce client and CLI
- Python with AWS SDKs

### unreal_dev.ps1

Sets up the Unreal Engine development environment:
- Installs the Epic Games Launcher
- Creates desktop shortcuts for easy access

### userdata.ps1

Configures Windows for Packer connectivity via WinRM:
- Creates self-signed certificates
- Sets up WinRM listeners
- Configures Windows Firewall to allow WinRM traffic

## Customization Options

### Instance Types

Choose an appropriate instance type based on your development needs:
- For GPU workloads: g4dn.xlarge, g4dn.2xlarge, g4dn.4xlarge
- For CPU-focused workloads: m5.xlarge, c5.2xlarge

### AMI Customization

The build process can be customized by:
- Modifying the PowerShell scripts to install additional software
- Adjusting the root volume size for more storage
- Changing the region and VPC settings to match your infrastructure

## Troubleshooting

# If the Packer build fails:
    1. Run packer build with the `-debug` flag for detailed output
    2. Check the Packer logs for error messages
    3. Verify your VPC and subnet have internet connectivity
    4. Ensure your AWS credentials have sufficient permissions
    5. Check that the instance type is available in your selected region
    6. Check that all required variables are provided in your command line

## License

See the project's main LICENSE file for license information.
