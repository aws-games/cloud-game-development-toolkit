# VDI Lightweight Windows AMI

This Packer template creates a lightweight Windows Server 2025 AMI optimized for VDI workloads with runtime software customization.

## What's Included

**Base Infrastructure (from shared/base_infrastructure.ps1):**
- Windows Server 2025 base
- NVIDIA GRID drivers (GPU instances)
- Amazon DCV remote desktop server
- AWS CLI and PowerShell modules
- Git, Perforce, Python, Chocolatey
- Active Directory management tools
- System PATH configuration

**Runtime Customization:**
- Software packages installed via VDI Terraform module
- User accounts created at deployment time
- DCV sessions configured per user
- Domain join (optional)

## Build Instructions

1. **Copy variables file:**
   ```bash
   cp variables.pkrvars.hcl.example variables.pkrvars.hcl
   ```

2. **Edit variables.pkrvars.hcl:**
   - Set your AWS region
   - Configure VPC/subnet (optional)
   - Adjust instance type if needed

3. **Build AMI:**
   ```bash
   packer build -var-file="variables.pkrvars.hcl" windows-server-2025-lightweight.pkr.hcl
   ```

## Build Time

- **Estimated:** 20-30 minutes
- **Instance Type:** g4dn.2xlarge (for GPU driver testing)
- **Storage:** 80GB root volume

## Using the AMI

### Option 1: AWS Console (Manual Deployment)

1. **Launch Instance:**
   - Go to EC2 Console → Launch Instance
   - Search for your AMI ID (from Packer build output)
   - Select GPU instance type: `g4dn.xlarge` or larger
   - Configure security group to allow RDP (port 3389) or DCV (port 8443)

2. **Connect via DCV:**
   - Install DCV Client: https://download.nice-dcv.com/
   - Connect to: `https://<instance-ip>:8443`
   - Login with Administrator account

3. **Install Additional Software:**
   - Use Chocolatey: `choco install vscode`
   - Use PowerShell: Install modules as needed
   - Manual installers: Download and install directly

### Option 2: Terraform (Infrastructure as Code)

```hcl
resource "aws_instance" "workstation" {
  ami           = "ami-0123456789abcdef0"  # Your AMI ID
  instance_type = "g4dn.xlarge"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.workstation.id]

  tags = {
    Name = "Developer Workstation"
  }
}
```

### Option 3: VDI Module (Advanced Automation)

For multi-user environments with automated user management:

```hcl
module "vdi" {
  source = "path/to/vdi/module"

  presets = {
    "developer" = {
      ami           = "ami-0123456789abcdef0"  # Your AMI ID
      instance_type = "g4dn.xlarge"
      software_packages = ["vscode", "git"]
    }
  }
}
```

## Alternative AMIs

For faster boot times with pre-installed software, consider:
- **[UE GameDev AMI](../ue-gamedev/)** - Visual Studio 2022 + Epic Games Launcher (UE requires manual install)

## Troubleshooting

- **Build fails:** Check VPC/subnet configuration and internet connectivity
- **GPU drivers:** Ensure g4dn instance type for proper driver testing
- **WinRM timeout:** Increase timeout in Packer template if needed
