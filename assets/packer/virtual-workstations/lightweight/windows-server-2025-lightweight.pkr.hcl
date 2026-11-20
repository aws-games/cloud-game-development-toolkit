# ⚠️  IMPORTANT: This template requires the complete virtual-workstations directory structure
# You must clone/download the entire assets/packer/virtual-workstations/ folder
# This template references shared scripts in ../shared/ and cannot be used standalone without customization
#
# Required structure:
# assets/packer/virtual-workstations/
# ├── shared/           (REQUIRED - contains base infrastructure scripts)
# ├── lightweight/      (this template)
# └── ue-gamedev/       (other templates)

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = null
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "subnet_id" {
  type    = string
  default = null
}

variable "instance_type" {
  type    = string
  default = "g4dn.2xlarge"
}

variable "associate_public_ip_address" {
  type    = bool
  default = true
}

variable "ami_prefix" {
  type    = string
  default = "vdi-lightweight-windows-server-2025"
}

variable "root_volume_size" {
  type    = number
  default = 80
}

variable "capacity_reservation_preference" {
  type        = string
  default     = null
  description = "Capacity reservation preference: 'open' (use ODCR if available), 'none' (never use ODCR), or null (no preference specified)"
}

variable "generalize" {
  type        = bool
  default     = true
  description = <<-EOT
    Run Sysprep to generalize the image. Leave true for a final, distributable AMI.

    Set false when this AMI is an INTERMEDIATE layer that a downstream Packer build
    will use as its source_ami.

    Sysprep's specialize phase re-scrambles the Administrator password without
    encrypting it to a launch keypair (so ec2:GetPasswordData returns an empty
    string forever) and removes the WinRM listener, so a downstream build cannot
    connect to a generalized image.

    When false, this template skips Sysprep and instead runs `ec2launch reset` as
    its last provisioner, which is required for a downstream build to be able to log
    in at all: setAdminAccount has frequency "once", this instance's own boot already
    recorded it as done, and that state is captured into the image. The downstream
    build is then responsible for generalizing the final image.

    ONE THING IS STILL YOUR RESPONSIBILITY. Make a `windows-restart` the FIRST
    provisioner of the DOWNSTREAM build. `ec2launch reset` leaves the agent shut
    down and that state is captured into the image, so without the reboot the
    downstream build's provisioners can silently do nothing while Packer still
    reports SUCCESS. See the README section on layering.
  EOT
}

locals {
  # Guards for the tail provisioners below. Both must stay in sync with the name of
  # the source block, source.amazon-ebs.lightweight; declared here so a rename needs
  # one edit rather than four.
  #
  # `except` rather than `only` on purpose. Packer takes literal build names in both
  # and silently ignores a name that matches nothing, so a stale name after a rename
  # degrades differently depending on which you pick:
  #   except -> the guarded provisioner runs when it should not. Sysprep runs on an
  #             intermediate image, and the downstream build then fails to connect.
  #   only   -> the guarded provisioner never runs at all. generalize = true would
  #             silently ship an UN-generalized AMI as if it were distributable.
  # The first is a loud failure on a private intermediate; the second is a silent one
  # in the default, distributable path. Prefer the loud one.
  skip_when_layering   = var.generalize ? [] : ["amazon-ebs.lightweight"]
  skip_unless_layering = var.generalize ? ["amazon-ebs.lightweight"] : []
}

# Version is controlled by CGD Toolkit maintainers
# Users should not modify this - it aligns with toolkit releases
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  version = "v1.1.6"  # Update this for each toolkit release
  ami_name = "${var.ami_prefix}-${local.timestamp}"
}

data "amazon-ami" "windows2025" {
  region = var.region
  filters = {
    name                = "Windows_Server-2025-English-Full-Base-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
}

source "amazon-ebs" "lightweight" {
  ami_name      = local.ami_name
  instance_type = var.instance_type
  region        = var.region
  source_ami    = data.amazon-ami.windows2025.id

  # S3 access for NVIDIA drivers
  temporary_iam_instance_profile_policy_document {
    Statement {
      Action = ["s3:GetObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [
        "arn:aws:s3:::ec2-windows-nvidia-drivers",
        "arn:aws:s3:::ec2-windows-nvidia-drivers/*"
      ]
    }
    Version = "2012-10-17"
  }

  communicator                = "winrm"
  winrm_insecure              = true
  winrm_username              = "Administrator"
  winrm_use_ssl               = true
  user_data_file              = "../shared/userdata.ps1"

  vpc_id                          = var.vpc_id
  subnet_id                       = var.subnet_id
  associate_public_ip_address     = var.associate_public_ip_address
  capacity_reservation_preference = var.capacity_reservation_preference

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  imds_support = "v2.0"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    iops                  = "3000"
    throughput            = "125"
  }

  tags = {
    # Core identification
    Name           = local.ami_name
    Purpose        = "VDI Lightweight Base"
    Version        = local.version
    BuildDate      = local.timestamp

    # Technical details
    BaseOS         = "Windows Server 2025"
    Template       = "lightweight"
    Architecture   = "x86_64"

    # Software components
    Components     = "DCV,NVIDIA,AWS-CLI,PowerShell,Git,Perforce,Python,Chocolatey"

    # Project tracking
    Project        = "cloud-game-development-toolkit"
    Repository     = "https://github.com/aws-games/cloud-game-development-toolkit"

    # Operational
    Environment    = "development"
    ManagedBy      = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.lightweight"]

  # Install shared base infrastructure (DCV, NVIDIA, AWS tools, common dev tools)
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "../shared/base_infrastructure.ps1"
  }

  # Configure EC2Launch v2 for VDI deployment
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "../shared/sysprep.ps1"
    except            = local.skip_when_layering
  }

  # Clean restart before sysprep
  provisioner "windows-restart" {
    restart_timeout = "5m"
    except          = local.skip_when_layering
  }

  # Run sysprep and shutdown
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    inline = [
      "Write-Host 'Starting sysprep for lightweight VDI AMI...'",
      "Start-Process -FilePath \"$${env:ProgramFiles}\\Amazon\\EC2Launch\\ec2launch.exe\" -ArgumentList 'sysprep', '--shutdown' -WindowStyle Hidden -Wait:$false",
      "Start-Sleep -Seconds 5"
    ]
    except = local.skip_when_layering
  }

  # The generalize = false counterpart of the block above: reset EC2Launch v2's agent
  # state so an instance launched from this INTERMEDIATE image treats itself as a
  # first boot and re-runs once-per-instance tasks -- above all setAdminAccount, which
  # generates the Administrator password and encrypts it to the launch keypair.
  #
  # Without this a downstream build cannot connect at all: this instance's own boot
  # already ran setAdminAccount and recorded it in state.json (with a marker at
  # .run-once), both of which are captured into the AMI, so EC2Launch downstream logs
  # "Warning: Skipping task preReady-setAdminAccount-0" and ec2:GetPasswordData
  # returns an empty string forever.
  #
  # MUST be last: an inline reset "runs immediately and resets the agent. The current
  # task finishes, then the agent shuts down without running any further tasks", so
  # anything after it would be silently skipped. -c/--clean is deliberately omitted:
  # it would also delete the instance logs that make a failed build debuggable.
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    inline = [
      "$launch = Join-Path $env:ProgramFiles 'Amazon\\EC2Launch\\ec2launch.exe'",
      "if (-not (Test-Path $launch)) { Write-Error \"ec2launch.exe not found at $launch\"; exit 1 }",
      "Write-Host 'Resetting EC2Launch v2 agent state so the next boot re-runs once-only tasks...'",
      "& $launch reset",
      "$state = 'C:\\ProgramData\\Amazon\\EC2Launch\\state'",
      "if (Test-Path (Join-Path $state '.run-once')) { Write-Error 'ec2launch reset left .run-once in place; a downstream build would skip setAdminAccount'; exit 1 }",
      "if (Test-Path (Join-Path $state 'state.json')) { Write-Error 'ec2launch reset left state.json in place; a downstream build would skip setAdminAccount'; exit 1 }",
      "Write-Host 'EC2Launch state reset: .run-once and state.json are gone.'"
    ]
    except = local.skip_unless_layering
  }
}
