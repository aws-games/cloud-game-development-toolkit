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

## Usage with VDI Module

Use the resulting AMI with the VDI Terraform module for runtime software customization:

```hcl
templates = {
  "developer" = {
    instance_type = "g4dn.xlarge"
    software_packages = [
      "chocolatey",
      "git",
      "visual-studio-2022",
      "unreal-engine-5.3"
    ]
  }
}
```

## Alternative AMIs

For faster boot times with pre-installed software, consider:
- **[UE GameDev AMI](../ue-gamedev/)** - Full Unreal Engine development stack
- **[Artists AMI](../artists/)** - Creative tools and applications

## Troubleshooting

- **Build fails:** Check VPC/subnet configuration and internet connectivity
- **GPU drivers:** Ensure g4dn instance type for proper driver testing
- **WinRM timeout:** Increase timeout in Packer template if needed