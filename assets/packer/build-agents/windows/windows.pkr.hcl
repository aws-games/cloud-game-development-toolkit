packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
    type = string
    default = "us-west-2"
}

variable "vpc_id" {
  type = string
  default = null
}

variable "subnet_id" {
  type = string
  default = null
}

variable "instance_type" {
  type = string
  default = "t3.small"
}

variable "associate_public_ip_address" {
  type = bool
  default = true
}

variable "ssh_interface" {
  type = string
  default = "public_ip"
}

variable "ami_prefix" {
  type    = string
  default = "windows-server-2022"
}

variable "setup_jenkins_agent" {
  type = bool
  default = true
}

variable "install_vs_tools" {
  type = bool
  default = true
}

variable "public_key" {
  type = string
}

variable "root_volume_size" {
  type = number
  default = 64
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

data "amazon-ami" "windows22" {
  region = var.region
  filters = {
    name = "Windows_Server-2022-English-Full-Base-*"
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
  region        = var.region
  source_ami    = data.amazon-ami.windows22.id

  # windows uses winRM communicator
  communicator = "winrm"
  force_deregister = true
  winrm_insecure = true
  winrm_username = "Administrator"
  winrm_use_ssl = true
  winrm_timeout = "1h"
  user_data_file = "./userdata.ps1"

  # network specific details
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface = var.ssh_interface

  # storage specifications - expand root
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = var.root_volume_size
    volume_type = "gp3"
    delete_on_termination = true
  }
}

build {
  name = "windows-builder"
  sources = [
    "source.amazon-ebs.base",
  ]

  # Execute sample script
  provisioner "powershell" {
    elevated_user = "Administrator"
    elevated_password = build.Password
    script           = "./base_setup.ps1"
  }

  # Execute sample script
  provisioner "powershell" {
    only = var.setup_jenkins_agent ? ["amazon-ebs.base"] : []
    elevated_user = "Administrator"
    elevated_password = build.Password
    script           = "./setup_jenkins_agent.ps1"
  }

  # Execute sample script
  provisioner "powershell" {
    only = var.install_vs_tools ? ["amazon-ebs.base"] : []
    elevated_user = "Administrator"
    elevated_password = build.Password
    script           = "./install_vs_tools.ps1"
  }

  # Copy SSH public key to agent AMI
  provisioner "powershell" {
    elevated_user = "Administrator"
    elevated_password = build.Password
    inline = [
      "$authorizedKey = '${var.public_key}'",
      "Add-Content -Force -Path $env:ProgramData/ssh/administrators_authorized_keys -Value $authorizedKey;icacls.exe \"\"$env:ProgramData/ssh/administrators_authorized_keys\"\" /inheritance:r /grant \"\"Administrators:F\"\" /grant \"\"SYSTEM:F\"\"",
      "Get-Disk | where partitionstyle -eq \"raw\" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel \"Data Drive\" -Confirm:$false"
    ]
  }
}
