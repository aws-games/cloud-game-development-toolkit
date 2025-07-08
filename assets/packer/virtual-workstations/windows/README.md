# Windows Virtual Workstation with Packer

This directory contains Packer configuration files and scripts for building Windows Server 2025 AMIs optimized for game development workstations with GPU support, particularly for Unreal Engine development.

## What is Packer?

[Packer](https://www.packer.io/) is an open-source tool for creating identical machine images for multiple platforms from a single source configuration. It's designed to be lightweight, running on every major operating system, and performs builds in parallel for multiple platforms.

Packer helps you create standardized machine images that can be used repeatedly to provision virtual machines, ensuring consistency across your infrastructure.

## Prerequisites

Before using this Packer configuration, ensure you have:

1. An AWS account with appropriate permissions
2. [Packer](https://www.packer.io/downloads) installed on your local machine
3. AWS credentials configured either via environment variables, shared credentials file, or IAM roles
4. Basic understanding of AWS services (VPC, subnets)
5. A VPC and subnet in your AWS account where Packer can build the AMI

## Getting Started

### Step 1: Configure Variables

Edit the `variables.pkrvars.hcl` file to specify your AWS environment settings:

```hcl
region = "us-east-1"             # AWS region to build in
vpc_id = "vpc-xxxxxxxxxxxx"      # Your VPC ID
subnet_id = "subnet-xxxxxxxxxxxx" # Your subnet ID
associate_public_ip_address = true
ssh_interface = "public_ip"

instance_type = "g4dn.4xlarge"   # Instance type to use for building (use GPU-enabled instance)
root_volume_size = 512           # Size of root volume in GB

ami_prefix = "windows-server-2025-workstation" # Prefix for the AMI name

# Add your SSH public key here (starts with ssh-rsa)
public_key = <<EOF
ssh-rsa AAAAB3NzaC1yc2E... your_public_key_here
EOF
```

Key variables to modify:
- `vpc_id` - Your VPC ID
- `subnet_id` - Your subnet ID
- `instance_type` - Choose a GPU-enabled instance for best results
- `root_volume_size` - Adjust based on your storage needs
- `public_key` - Your SSH public key for authentication

### Step 2: Run Packer Build

From this directory, run the following command:

```bash
packer build -var-file="variables.pkrvars.hcl" windows-server-2025.pkr.hcl
```

This will start the build process, which includes:
1. Launching a Windows Server 2025 instance
2. Configuring WinRM for Packer connectivity
3. Running provisioning scripts
4. Creating and registering the final AMI

The build process may take 30-60 minutes depending on your instance type and network speed.

## Script Breakdown

### base_setup_with_gpu_check.ps1
This script handles the core system setup, including:
- System configuration and logging
- AWS tools installation (CLI, SSM)
- Chocolatey package manager installation
- NVIDIA GPU detection and driver installation
- OpenSSH Server setup
- NFS Client setup for file sharing
- Amazon DCV installation for remote desktop access

### base_setup_with_gpu_check_16kb.ps1
A version of the base setup script optimized for use as user data when manually creating instances. This script:
- Installs AWS tools and PowerShell modules
- Sets up GPU drivers if a compatible GPU is detected
- Configures Amazon DCV
- Restarts the instance to apply changes

### dev_tools.ps1
Installs development tools necessary for game development:
- Visual Studio 2022 Community and Build Tools
- Windows Development Kit
- Visual Studio Code with extensions
- Git for source control
- Python and Node.js
- Terraform and tfenv for infrastructure management

### unreal_dev.ps1
Sets up the Unreal Engine development environment:
- Creates directory structure for Unreal Engine
- Installs the Epic Games Launcher
- Creates desktop shortcuts for easy access

### userdata.ps1
Configures Windows for Packer connectivity via WinRM:
- Creates self-signed certificates
- Sets up WinRM listeners
- Configures Windows Firewall to allow WinRM traffic

### windows-server-2025.pkr.hcl
The main Packer configuration file that:
- Defines the Amazon EBS builder
- Sets up communication with the Windows instance
- Specifies provisioning steps using PowerShell scripts
- Configures SSH key deployment

## Customization Options

### Instance Types
Choose an appropriate instance type based on your development needs:
- For GPU workloads: g4dn.xlarge, g4dn.2xlarge, g4dn.4xlarge
- For CPU-focused workloads: m5.xlarge, c5.2xlarge

### AMI Customization
You can customize the AMI by:
1. Modifying the existing scripts to add/remove software
2. Adding new provisioning scripts to the Packer configuration
3. Adjusting system configurations in the PowerShell scripts

### Administrator Password
For security reasons, the Administrator password is not set during the AMI creation. After launching an instance from the AMI, you should set a password using AWS SSM:

```bash
aws ssm send-command --document-name "AWS-RunPowerShellScript" \
  --parameters "commands=['net user Administrator YourNewPassword']" \
  --targets "Key=instanceids,Values=i-1234567890abcdef0"
```

## Troubleshooting

If the Packer build fails:
1. Check the Packer logs for error messages
2. Verify your VPC and subnet have internet connectivity
3. Ensure your AWS credentials have sufficient permissions
4. Check that the instance type is available in your selected region
5. Validate the syntax of your variables.pkrvars.hcl file

## License

See the project's main LICENSE file for license information.
