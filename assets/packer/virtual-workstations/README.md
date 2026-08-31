# Virtual Workstations Packer Templates

## 🚨 CRITICAL REQUIREMENTS

### GPU Instance Types Required

#### **⚠️ ALL TEMPLATES BUILD NVIDIA-OPTIMIZED AMIs**

### **For Packer Build:**

- ✅ **GPU instances**: `g4dn.*`, `g5.*`, `p3.*`, `p4.*` (full functionality)
- ⚠️ **Non-GPU instances**: `t3.*`, `m5.*`, `c5.*`, `r5.*` (builds succeed, skips NVIDIA drivers)
- 🔧 **Current defaults**: `g4dn.2xlarge` (recommended for production)
- 🎓 **Workshop friendly**: C instances work fine for learning/demos

**For Final VDI Deployment:**

- ✅ **Recommended**: GPU instances for full functionality
- ⚠️ **Will boot but degraded**: Non-GPU instances (software rendering only)
- ❌ **GPU apps will fail**: Unreal Engine, CUDA applications

**Instance Compatibility Matrix:**

| Packer Build | Final Instance | Result |
|--------------|----------------|--------|
| `g4dn.2xlarge` | `g4dn.xlarge` | ✅ Full GPU acceleration |
| `g4dn.2xlarge` | `g4dn.4xlarge` | ✅ Full GPU acceleration |
| `g4dn.2xlarge` | `m5.2xlarge` | ⚠️ Boots, no GPU, slow DCV |
| `g4dn.2xlarge` | `t3.medium` | ❌ Poor performance, apps fail |

### Directory Structure Required

⚠️ **CRITICAL: These templates require the complete directory structure and cannot be used standalone without customization.**

## Directory Structure

```text
assets/packer/virtual-workstations/
├── shared/                    # REQUIRED - Base infrastructure scripts
│   ├── base_infrastructure.ps1    # NVIDIA + DCV + AWS tools + dev tools
│   ├── sysprep.ps1               # EC2Launch configuration
│   └── userdata.ps1              # Packer WinRM setup
├── lightweight/               # Base VDI AMI
└── ue-gamedev/               # Unreal Engine development AMI
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

**Build with defaults:**

Packer will use your current AWS session and the defaults defined in the template:

```bash
# Navigate to the template directory
cd assets/packer/virtual-workstations/lightweight/

# Build with defaults (recommended)
packer build windows-server-2025-lightweight.pkr.hcl
```

**To override default instance type (optional):**

```bash
# Create variables file (optional)
cp variables.pkrvars.hcl.example variables.pkrvars.hcl

# Edit variables.pkrvars.hcl
instance_type = "g4dn.4xlarge"  # Must be GPU-enabled

# Build with custom variables
packer build -var-file="variables.pkrvars.hcl" windows-server-2025-lightweight.pkr.hcl
```

**On-Demand Capacity Reservations (ODCR):**

Use existing capacity reservations during AMI builds:

```bash
# Use ODCR if available, fall back to On-Demand if not
packer build -var capacity_reservation_preference=open windows-server-2025-lightweight.pkr.hcl

# Never use ODCR, always On-Demand
packer build -var capacity_reservation_preference=none windows-server-2025-lightweight.pkr.hcl
```

## Available Templates

### Lightweight AMI

**Best for:** Runtime software customization via VDI Terraform module

```bash
# Navigate to lightweight template directory
cd assets/packer/virtual-workstations/lightweight/

# Build lightweight AMI
packer build windows-server-2025-lightweight.pkr.hcl
```

**Includes:** Windows Server 2025 + DCV + AWS CLI + PowerShell + Git + Perforce + Python + Chocolatey
**Build Time:** ~25 minutes

### UE GameDev AMI

**Best for:** Immediate Unreal Engine development

```bash
# Navigate to UE GameDev template directory
cd assets/packer/virtual-workstations/ue-gamedev/

# Build UE GameDev AMI
packer build windows-server-2025-ue-gamedev.pkr.hcl
```

**Includes:** Lightweight base + Visual Studio 2022 + Epic Games Launcher (UE requires manual install)
**Build Time:** ~45 minutes

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

  # Core configuration
  project_prefix = "gamedev"
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Templates reference your built AMIs
  templates = {
    "developer" = {
      instance_type = "g4dn.2xlarge"
      ami           = "ami-0d22cd2c73f6b623"  # Use AMI ID from Packer build output
      volumes = {
        Root = { capacity = 256, type = "gp3", windows_drive = "C:" }
        Projects = { capacity = 1024, type = "gp3", windows_drive = "D:" }
      }
    }
  }

  # Workstations and users configuration
  workstations = { /* ... */ }
  users = { /* ... */ }
  workstation_assignments = { /* ... */ }
}
```

## Layering another build on top of these AMIs

These templates produce **final, distributable AMIs**: the last provisioners run
Sysprep to generalize the image. If you want to build *on top* of one — adding a
licensed engine install, studio tooling, or a game project in a second Packer build
that sets `source_ami` to this template's output — set `generalize = false`:

```bash
packer build -var "generalize=false" windows-server-2025-ue-gamedev.pkr.hcl
```

Your downstream build is then responsible for generalizing the final image.

Layering needs three things. The template handles the first two for you; the third is
yours:

| # | Where | What | Who |
|---|---|---|---|
| 1 | this build | do not Sysprep | `-var "generalize=false"` |
| 2 | this build, **last** provisioner | `ec2launch reset` | done by the template when `generalize = false` |
| 3 | **downstream** build, **first** provisioner | `windows-restart` | **you** |

Without 2 the downstream build hangs forever waiting for a password. Without 3 it is
worse: the downstream build **appears to succeed** while its provisioners do nothing.

### 1 + 2 — this build

Nothing to write. Passing `generalize = false` swaps the Sysprep tail for an
`ec2launch reset` provisioner, which must be — and is — last, because an inline reset
shuts the agent down immediately and anything after it would be silently skipped.

**Why the reset is required.** `setAdminAccount` — the task that generates the
Administrator password and encrypts it to the launch keypair — has frequency
*once*. This build's own first boot already ran it and recorded success in
`C:\ProgramData\Amazon\EC2Launch\state\state.json`, with a marker at `.run-once`.
Both are captured into the AMI. EC2Launch on a downstream instance reads that state
and skips the task:

```text
Warning: Skipping task preReady-setAdminAccount-0
```

so `ec2:GetPasswordData` returns an empty string forever and Packer hangs at
`Waiting for auto-generated password` until it times out. Note this state comes from
the instance simply *booting* — the stock AWS Windows AMI is already sysprepped — so
skipping Sysprep here does not prevent it, and it is not something this template
causes. `ec2launch reset` deletes that state, and the downstream instance then
behaves like a genuine first boot.

**Why `generalize = false` is still needed alongside it.** Sysprep's specialize phase
re-scrambles the Administrator password (via
`EC2Launch.exe internal randomize-password`) without encrypting it to a keypair, and
it removes the WinRM listener the downstream build connects through — undoing the
reset. This is deliberate on AWS's part: it is documented as a security measure to
stop an instance being reachable after Sysprep if `setAdminAccount` was not
configured. It is not something to work around, which is why the reset has to happen
*instead of* Sysprep rather than after it.

### 3 — the downstream build

```hcl
build {
  sources = ["source.amazon-ebs.my-layer"]

  # MUST be first. The intermediate AMI was captured with the EC2Launch agent shut
  # down by `ec2launch reset`, so this instance has never completed a normal boot
  # cycle and the provisioner environment is not fully initialized. Without this
  # reboot, provisioners silently produce no output and can lose their
  # environment_vars mid-run -- and Packer still reports the build as SUCCESSFUL.
  provisioner "windows-restart" {
    restart_timeout = "20m"
    check_registry  = true
  }

  # ... your provisioners ...
}
```

This one is easy to miss because the failure mode is a *passing* build: Packer reports
success and publishes an AMI that is missing everything the skipped provisioners were
supposed to install.

### Handling the intermediate image

An un-generalized image retains the build instance's SID and hostname, so treat it as
a private intermediate artifact — do not publish or share it, and delete it once the
downstream AMI is built.

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
