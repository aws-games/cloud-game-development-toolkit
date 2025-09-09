# ⚠️  IMPORTANT: This template requires the complete virtual-workstations directory structure
# You must clone/download the entire assets/packer/virtual-workstations/ folder
# This template references shared scripts in ../shared/ and cannot be used standalone without customization
# 
# Required structure:
# assets/packer/virtual-workstations/
# ├── shared/           (REQUIRED - contains base infrastructure scripts)
# ├── lightweight/      (other templates)
# └── ue-gamedev/       (this template)

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
  default = "vdi-ue-gamedev-windows-server-2025"
}

variable "root_volume_size" {
  type    = number
  default = 150
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
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

source "amazon-ebs" "ue-gamedev" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
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

  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    iops                  = "5000"
    throughput            = "250"
  }

  tags = {
    Name        = "${var.ami_prefix}-${local.timestamp}"
    Purpose     = "VDI Unreal Engine GameDev"
    BuildDate   = local.timestamp
    BaseOS      = "Windows Server 2025"
    Components  = "DCV,NVIDIA,AWS-CLI,PowerShell,AD-Tools,Git,Perforce,Python,Chocolatey,VisualStudio2022,UnrealEngine5.3"
  }
}

build {
  sources = ["source.amazon-ebs.ue-gamedev"]

  # Install shared base infrastructure (DCV, NVIDIA, AWS tools, common dev tools)
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "../shared/base_infrastructure.ps1"
  }

  # Install Unreal Engine development stack (Visual Studio + UE5.3)
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "./unreal_development_stack.ps1"
  }

  # Configure EC2Launch v2 for VDI deployment
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    script            = "../shared/sysprep.ps1"
  }

  # Clean restart before sysprep
  provisioner "windows-restart" {
    restart_timeout = "5m"
  }

  # Run sysprep and shutdown
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = build.Password
    inline = [
      "Write-Host 'Starting sysprep for UE GameDev VDI AMI...'",
      "Start-Process -FilePath \"$${env:ProgramFiles}\\Amazon\\EC2Launch\\ec2launch.exe\" -ArgumentList 'sysprep', '--shutdown' -WindowStyle Hidden -Wait:$false",
      "Start-Sleep -Seconds 5"
    ]
  }
}