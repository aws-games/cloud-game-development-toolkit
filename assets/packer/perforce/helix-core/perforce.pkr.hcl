packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_prefix = "p4_rocky_linux"
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

variable "associate_public_ip_address" {
  type = bool
  default = true
}

variable "ssh_interface" {
  type = string
  default = "public_ip"
}

source "amazon-ebs" "rocky" {
  region = var.region
  ami_name      = "${local.ami_prefix}-${local.timestamp}"
  instance_type = "t3.medium"

  vpc_id = var.vpc_id
  subnet_id = var.subnet_id

  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface = var.ssh_interface

  source_ami_filter {
    filters = {
      name                = "Rocky-9-EC2-Base-9.2-20230513.0.x86_64*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["679593333241"]
  }

  ssh_username = "rocky"
}

build {
  name = "P4_SDP_AWS"
  sources = [
    "source.amazon-ebs.rocky"
  ]

    provisioner "shell" {
      inline = [
        "sudo dnf install -y git"
      ]
    }

    provisioner "shell" {
      script = "p4_setup.sh"
      execute_command = "sudo sh {{.Path}}"
    }

    provisioner "file" {
      source      = "p4_configure.sh"
      destination = "/home/rocky/p4_configure.sh"
    }

    provisioner "shell" {    
      inline = ["chmod +x /home/rocky/p4_configure.sh"]
    }

    # Install Amazon SSM Agent
    provisioner "shell" {
      inline = [
        "sudo dnf install -y https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/linux_amd64/amazon-ssm-agent.rpm",
        "sudo systemctl enable amazon-ssm-agent"
      ]
    }

    # Install AWS CLI
    provisioner "shell" {
      inline = [
          <<-EOF
          sudo dnf install -y unzip
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install
          EOF
      ]
    }
}
