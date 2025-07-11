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
  default = null
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
  default = "m5.large"
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
  type = string
  default = "windows-server-2025"
}


variable "public_key" {
  type = string
  default = ""  # Empty default, but pkrvars file should provide a real value
}

variable "root_volume_size" {
  type = number
  default = 64
}

variable "admin_password" {
  type = string
  default = null
  sensitive = true
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

data "amazon-ami" "windows2025" {
  region = var.region
  filters = {
    name = "Windows_Server-2025-English-Full-Base-*"
    root-device-type = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners = ["amazon"]
}

source "amazon-ebs" "base" {
  ami_name = "${var.ami_prefix}-${local.timestamp}"
  instance_type = var.instance_type
  region = var.region
  source_ami = data.amazon-ami.windows2025.id

  communicator = "winrm"
  force_deregister = true
  winrm_insecure = true
  winrm_username = "Administrator"
  winrm_use_ssl = true
  winrm_timeout = "30m"
  user_data_file = "./userdata.ps1"

  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface = var.ssh_interface

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = var.root_volume_size
    volume_type = "gp3"
    delete_on_termination = true
  }
}

build {
  name = "windows-server-2025-builder"
  sources = ["source.amazon-ebs.base"]

  # Run the base_setup_with_gpu_check script (core system setup)
  provisioner "powershell" {
    elevated_user = "Administrator"
    elevated_password = build.Password
    script = "./base_setup_with_gpu_check.ps1"
  }

  # Run the dev tools installation script
  provisioner "powershell" {
    elevated_user = "Administrator"
    elevated_password = build.Password
    script = "./dev_tools.ps1"
  }

  # Run the Unreal Engine development environment setup script
  provisioner "powershell" {
    elevated_user = "Administrator"
    elevated_password = build.Password
    script = "./unreal_dev.ps1"
  }
}
