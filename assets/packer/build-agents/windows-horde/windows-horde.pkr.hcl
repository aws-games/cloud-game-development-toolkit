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
  default = "c6a.4xlarge"
}

# Build agents launched by Packer live only for the duration of the build.
# Default to NO public IP so the temporary instance stays private; this pairs
# with a private/limited subnet + a locked-down security group. If you must
# reach the build instance over the public internet, set this true AND provide
# a security_group_id whose ingress is scoped to your own CIDR (never
# 0.0.0.0/0).
variable "associate_public_ip_address" {
  type    = bool
  default = false
}

# "private_ip" keeps WinRM traffic on the VPC (works when Packer itself runs
# from inside the VPC, e.g. a CodeBuild/bastion in the same network). Switch to
# "public_ip" only together with associate_public_ip_address = true and a
# CIDR-scoped security group.
variable "ssh_interface" {
  type    = string
  default = "private_ip"
}

# Optional: attach a pre-created, CIDR-scoped security group to the temporary
# build instance. REQUIRED if you set associate_public_ip_address = true, so
# WinRM (5986) is never exposed to 0.0.0.0/0. When null, Packer creates a
# temporary SG whose ingress it scopes to the CIDRs below.
variable "security_group_id" {
  type    = string
  default = null
}

# CIDRs allowed to reach the temporary build instance's WinRM (5986) when
# Packer creates its own temporary security group. MUST be a scoped list (e.g.
# the Packer host's /32) - NEVER 0.0.0.0/0. Only used when security_group_id is
# null.
variable "temporary_security_group_source_cidrs" {
  type    = list(string)
  default = []
}

variable "ami_prefix" {
  type    = string
  default = "windows-horde-build-agent"
}

variable "root_volume_size" {
  type    = number
  default = 256
}

variable "public_key" {
  type = string
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

data "amazon-ami" "windows22" {
  region = var.region
  filters = {
    name                = "Windows_Server-2022-English-Full-Base-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
}

source "amazon-ebs" "base" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = var.instance_type

  # AMI specifications
  region     = var.region
  source_ami = data.amazon-ami.windows22.id

  # windows uses winRM communicator
  communicator     = "winrm"
  force_deregister = true
  winrm_insecure   = true
  winrm_username   = "Administrator"
  winrm_use_ssl    = true
  winrm_timeout    = "15m"
  user_data_file   = "./userdata.ps1"

  # network specific details
  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface               = var.ssh_interface

  # When a pre-created, CIDR-scoped security group is supplied, use it. When
  # null, Packer creates a temporary SG and scopes its ingress to
  # temporary_security_group_source_cidrs (never 0.0.0.0/0).
  security_group_id                     = var.security_group_id
  temporary_security_group_source_cidrs = var.temporary_security_group_source_cidrs

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  imds_support = "v2.0"

  # storage specifications - expand root
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

build {
  name = "windows-horde-builder"
  sources = [
    "source.amazon-ebs.base",
  ]

  # Base OS tooling: choco, git, OpenSSH, Python. (No NFS-Client - the Horde
  # iSCSI pipeline uses the MSiSCSI initiator instead, configured below.)
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./base_setup.ps1"
  }

  # C++ toolchain: VS2022 Build Tools + VC 14.38 + WDK/PDBCOPY (Unreal from-source).
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./install_vs_tools.ps1"
  }

  # Horde build-agent runtimes: .NET 6 runtime (matches the Horde module's
  # agent_dotnet_runtime_version default so the module's first-boot choco
  # install is a no-op) + .NET 8 SDK (UE 5.5 UAT) + p4 + awscli.
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./install_horde_agent_tools.ps1"
  }

  # iSCSI initiator (MSiSCSI, Automatic) + MPIO feature + MSDSM iSCSI claim.
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./install_iscsi.ps1"
  }

  # Drop the per-boot unique-IQN LOGIC onto the IMAGE at a fixed path. This file
  # MUST land on the AMI (not merely run at build time): the ONSTART task below
  # invokes it on every boot to materialise an instance-id-derived initiator IQN.
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    inline = [
      "New-Item -ItemType Directory -Path C:\\ProgramData\\horde -Force | Out-Null"
    ]
  }

  provisioner "file" {
    source      = "./set_unique_iqn.ps1"
    destination = "C:\\ProgramData\\horde\\set_unique_iqn.ps1"
  }

  # Register the ONSTART Scheduled Task (SYSTEM, RunLevel Highest) that runs the
  # baked script above on every boot. This is the baked MECHANISM; the IQN VALUE
  # is derived per-instance at boot time. Input-free: no ONTAP, no Perforce.
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./register_iqn_task.ps1"
  }

  # Validation: fail the build if the toolchain / iSCSI / MPIO / boot-IQN task
  # are not present.
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./validate_image.ps1"
  }

  # Copy SSH public key to agent AMI
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    inline = [
      "$authorizedKey = '${var.public_key}'",
      "Add-Content -Force -Path $env:ProgramData/ssh/administrators_authorized_keys -Value $authorizedKey;icacls.exe \"\"$env:ProgramData/ssh/administrators_authorized_keys\"\" /inheritance:r /grant \"\"Administrators:F\"\" /grant \"\"SYSTEM:F\"\""
    ]
  }

  # Remove the run-once flag so user scripts run on first boot
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    inline = [
      "Remove-Item C:\\ProgramData\\Amazon\\EC2Launch\\state\\.run-once"
    ]
  }
}
