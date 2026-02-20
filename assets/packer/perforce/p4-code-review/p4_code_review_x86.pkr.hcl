packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  ami_prefix = "p4_code_review_ubuntu"
}

data "amazon-ami" "ubuntu" {
  filters = {
    # Pin to Ubuntu 24.04 LTS (noble) - helix-swarm-optional requires ImageMagick 6
    # which is not available in Ubuntu 25.x+
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    architecture        = "x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical
  region      = var.region
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

variable "associate_public_ip_address" {
  type = bool
  default = true
}

variable "ssh_interface" {
  type = string
  default = "public_ip"
}

variable "install_swarm_optional" {
  type = bool
  default = true
  description = "Install helix-swarm-optional package (includes LibreOffice for document previews and ImageMagick for image previews). Adds ~500MB to AMI size."
}

source "amazon-ebs" "ubuntu" {
  region = var.region
  ami_name      = "${local.ami_prefix}-${local.timestamp}"
  instance_type = "t3.medium"

  vpc_id = var.vpc_id
  subnet_id = var.subnet_id

  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface = var.ssh_interface

  source_ami = data.amazon-ami.ubuntu.id

  ssh_username = "ubuntu"
}

build {
  name = "P4_CODE_REVIEW_AWS"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

    provisioner "shell" {
      inline = [
        "cloud-init status --wait",
        "sudo apt-get update",
        "sudo apt-get install -y git unzip curl"
      ]
    }

    provisioner "shell" {
      script = "${path.root}/swarm_setup.sh"
      execute_command = "sudo sh {{.Path}}"
      environment_vars = [
        "INSTALL_SWARM_OPTIONAL=${var.install_swarm_optional}"
      ]
    }

    provisioner "file" {
      source      = "${path.root}/swarm_instance_init.sh"
      destination = "/tmp/swarm_instance_init.sh"
    }

    provisioner "shell" {
      inline = ["mkdir -p /home/ubuntu/swarm_scripts",
                "sudo mv /tmp/swarm_instance_init.sh /home/ubuntu/swarm_scripts"
      ]
    }

    provisioner "shell" {
      inline = ["sudo chmod +x /home/ubuntu/swarm_scripts/swarm_instance_init.sh"]
    }

}
