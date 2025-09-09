# VDI Packer Templates

Choose the right AMI approach for your needs:

## 🎮 Game Development (`game-dev/`)
**Pre-installed comprehensive game development environment**

- **Build time**: ~45 minutes
- **Use case**: Teams wanting everything pre-installed
- **Includes**: Visual Studio, Unreal Engine, Git, Perforce, development tools
- **Benefits**: Ready to use immediately, consistent environment
- **Trade-offs**: Longer build time, larger AMI, less flexibility

## ⚡ Lightweight (`lightweight/`)
**Minimal base with runtime software installation**

- **Build time**: ~20-30 minutes  
- **Use case**: Flexible software configuration per workstation
- **Includes**: Windows Server 2025, DCV, NVIDIA drivers, SSM, PowerShell
- **Benefits**: Fast deployment, per-user customization, easy updates
- **Trade-offs**: Software installs after deployment (2-3 minutes async)

## Decision Guide

**Choose Game Development if:**
- All users need the same software stack
- You prefer everything pre-installed
- Build time is not a concern
- You rarely change software requirements

**Choose Lightweight if:**
- Different users need different software
- You want fast infrastructure deployment
- You frequently update software packages
- You prefer infrastructure-as-code approach

## Usage

Navigate to the appropriate directory and follow the README instructions:
- `cd game-dev/` - Full game development environment
- `cd lightweight/` - Minimal base with runtime installation

## 🖥️ DCV Session Management

**IMPORTANT**: These Packer templates install and configure DCV service but **do NOT create DCV sessions**.

### For Standalone Usage (Packer AMI Only)

After launching an EC2 instance from your Packer-built AMI:

1. **Connect via RDP first** (to create DCV session)
2. **Create DCV session manually**:
   ```powershell
   # Connect via RDP, then run:
   dcv create-session --owner=Administrator console
   ```
3. **Connect via DCV client**: `https://instance-ip:8443`

### For VDI Module Usage (Recommended)

The **VDI Terraform Module** automatically handles DCV session creation:
- ✅ Creates sessions for all user accounts at boot
- ✅ Configures admin sharing for fleet management  
- ✅ No manual session creation needed

## Need More Customization?

For advanced VDI deployments with multi-user management, authentication systems, and flexible software installation, use the **VDI Terraform Module**:

👉 **[VDI Module Documentation](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi)**

The VDI module provides:
- Multi-user workstation management
- Template-based configuration
- Runtime software installation
- Active Directory integration
- Secrets Manager authentication
- Centralized logging and monitoring
- **Automatic DCV session management**