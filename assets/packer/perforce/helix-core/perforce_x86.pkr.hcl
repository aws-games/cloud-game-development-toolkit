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
  ami_prefix = "p4_al2023"
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

source "amazon-ebs" "al2023" {
  region = var.region
  ami_name      = "${local.ami_prefix}-${local.timestamp}"
  instance_type = "t3.medium"

  vpc_id = var.vpc_id
  subnet_id = var.subnet_id

  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface = var.ssh_interface

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.5.*"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username = "ec2-user"
}

build {
  name = "P4_SDP_AWS"
  sources = [
    "source.amazon-ebs.al2023"
  ]

    provisioner "shell" {
      inline = [
        "cloud-init status --wait",
        "sudo dnf install -y git sendmail nfs-utils s-nail unzip cronie"
      ]
    }

    provisioner "shell" {
      script = "${path.root}/p4_setup.sh"
      execute_command = "sudo sh {{.Path}}"
    }

    provisioner "file" {
      source      = "${path.root}/p4_configure.sh"
      destination = "/tmp/p4_configure.sh"
    }

    provisioner "shell" {
      inline = ["mkdir -p /home/ec2-user/gpic_scripts",
                "sudo mv /tmp/p4_configure.sh /home/ec2-user/gpic_scripts"
      ]
    }

    provisioner "shell" {
      inline = ["sudo chmod +x /home/ec2-user/gpic_scripts/p4_configure.sh"]
    }

}
