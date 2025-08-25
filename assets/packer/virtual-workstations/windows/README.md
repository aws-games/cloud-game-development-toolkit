# Windows Virtual Workstation with Packer

This directory contains Packer configuration files and scripts for building Windows Server 2025 AMIs optimized for game development workstations with GPU support, particularly for Unreal Engine development.

## File Structure

- `windows-server-2025.pkr.hcl` - Main Packer template for Windows Server 2025
- `userdata.ps1` - Initial Windows setup script for WinRM configuration
- `base_setup_with_gpu_check.ps1` - Core system setup with GPU detection and DCV installation
- `dev_tools.ps1` - Development tools installation script
- `unreal_dev.ps1` - Unreal Engine development environment setup
- `sysprep_preparation.ps1` - Complete sysprep preparation including password generation system and answer file creation

## Prerequisites

Before using this Packer configuration, ensure you have:

1. An AWS account with appropriate permissions
2. [Packer](https://www.packer.io/downloads) installed on your local machine
3. AWS credentials configured either via environment variables, shared credentials file, or IAM roles
4. Basic understanding of AWS services (VPC, subnets)
5. A VPC and subnet in your AWS account where Packer can build the AMI

## Getting Started

### Step 1: Configure Variables

Default variables and values are provided in the `windows-server-2025.pkr.hcl` file. You can modify these variables as needed to match your infrastructure and development needs.
--For more information for assigning variables go to [Hashicorp Variable Reference Guide](https://developer.hashicorp.com/packer/guides/hcl/variables#assigning-variables)
**Default VPC** Make sure to have default VPC in your account
**Default Subnet** Make sure to have default subnet in your account
**Region** (default: `us-east-1`) AMIs are region specifc. Choose the Region for where you want your AMI to be used.
**Instance Type** (default: `g4dn.2xlarge`)
--[Minimum spec reququired for Unreal Engine workloads](https://dev.epicgames.com/documentation/en-us/unreal-engine/hardware-and-software-specifications-for-unreal-engine)
  --Recommend to start with the minimum instance size and bump up if needed. Estimated On-Demand price based on the us-east-1 region. Storage and transfer cost not included:
    **g4dn.2xlarge:** *Default* [$1.12] per hour ---- Monthly cost with 80% utilization: [$645.12]
    **g4dn.4xlarge** [$1.94] per hour ---- Monthly cost with 80% utilization: [$1117.44]
    **g4dn.8xlarge** [$3.648] per hour ---- Monthly cost with 80% utilization: [$2101.25]
    **g4dn.16xlarge:** [$6.12] per hour ---- Monthly cost with 80% utilization: [$3525.12]
**Root Volume Size**(default: `128`)

### Step 2: Run Packer Build

From this directory, run the following command:

```bash
packer build windows-server-2025.pkr.hcl
```

This will start the build process, which includes:
1. Launching a Windows Server 2025 instance
2. Configuring WinRM for Packer connectivity
3. Running provisioning scripts (base setup, dev tools, Unreal Engine setup)
4. Running sysprep preparation and generalization (sets up password generation system, creates answer file, and runs sysprep)
5. Creating and registering the final AMI

The build process may take 35-50 minutes depending on your instance type and network speed.

## Script Details

### userdata.ps1

Configures Windows for Packer connectivity via WinRM:[WinRM Documentation](https://developer.hashicorp.com/packer/docs/communicators/winrm#configuring-winrm-in-the-cloud)
- **Creates self-signed certificates**
- **Sets up WinRM listeners**
- **Configures Windows Firewall to allow WinRM traffic**

### base_setup_with_gpu_check.ps1

This script handles the core system setup, including:
- **Amazon DCV installation** [Amazon DCV](https://aws.amazon.com/hpc/dcv/)
    - Optional virtual display driver for [Non-GPU instances](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-winprereq.html)
- **AWS S3 tools for driver install** [S3 Powershell tools](https://docs.aws.amazon.com/powershell/v5/userguide/pstools-s3.html)
- **NVIDIA GPU detection and driver installation** [GRID Drivers](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-nvidia-driver.html#nvidia-GRID-driver)

### dev_tools.ps1

Installs development tools necessary for game development:

#### Package Management
- **Chocolatey** [Windows package manager](https://chocolatey.org/)

#### IDEs and Development Tools required for Unreal Engine
- **Visual Studio 2022 Community** [Visual Studio](https://visualstudio.microsoft.com/)
- Required Workloads and Components defined by Epic for [Unreal Engine](https://dev.epicgames.com/documentation/en-us/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine)
  - **Workloads:**
    - Managed Desktop (.NET)
    - Native Desktop (C++)
    - .NET Cross-Platform Development
  - **Components:**
    - Visual C++ Diagnostic Tools
    - Address Sanitizer
    - Windows 10 SDK (10.0.18362.0)
    - Unreal Engine Component

#### Source Control
- **Git** - [Distributed version control](https://git-scm.com/)
- **Perforce Client** [Visual interface (P4V)](https://www.perforce.com/products/helix-core-apps/helix-visual-client-p4v)
- **Perforce CLI** [Command-line interface (P4)](https://help.perforce.com/helix-core/server-apps/cmdref/current/Content/CmdRef/Home-cmdref.html)

#### Cloud and Scripting
- **AWS CLI** [Command-line interface for AWS](https://docs.aws.amazon.com/streams/latest/dev/setup-awscli.html)
- **Python v3.14** [General-purpose programming language](https://www.python.org/)
- **Boto3** [AWS SDK for Python](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

### unreal_dev.ps1

Sets up the Unreal Engine development environment:
- **Installs the Epic Games Launcher** [Epic Games Launcher](https://store.epicgames.com/en-US/download)
- **Creates desktop shortcuts for easy access**

### sysprep_preparation.ps1

Complete sysprep preparation and execution script that handles all AMI generalization:
[Createing a AMI with sysprep](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ami-create-win-sysprep.html)
- **Creates the password generation script** (`VDI-PasswordGen.ps1`) that runs on first boot
- **Configures GRID driver persistence** through EC2Launch v2 agent configuration
- **Creates sysprep answer file** (`unattend.xml`) with proper OOBE configuration
- **Sets unique hostname generation** - each instance gets a unique computer name on first boot
- **Executes sysprep** to generalize the AMI and shut down the instance

### Password Retrieval

1. Ensure you are launching the instance with a keypair and that you have access to the private key
2. Go to the Connect Tab in the AWS Console within the EC2 instance
3. Move to RDP Client tab
4. Click "Get password"
5. Upload or paste the private key including the opening and closing dashes
6. Click "Decrypt password"
7. Password should now be available to be copied

## Customization Options

### AMI Customization

The build process can be customized by:
- Modifying the PowerShell scripts to install additional software
- Adjusting the root volume size for more storage
- Changing the region to match your infrastructure

## Troubleshooting

# If the Packer build fails:
    1. Run packer build with the `-debug` flag for detailed output
    2. Check the Packer logs for error messages
    3. Verify your VPC and subnet have internet connectivity
    4. Ensure your AWS credentials have sufficient permissions
    5. Check that the instance type is available in your selected region
    6. If SSM is not connecting, ensure that your Security Group allows outbound traffic on port 443

## License

See the project's main LICENSE file for license information.
