packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
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
  default = "unity-license-server-ubuntu-22.04-amd64"
}

variable "path_to_unity_license_zip" {
  type    = string
  default = "Unity.Licensing.Server.linux-x64.zip"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = "t3.small"
  region        = var.region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ubuntu"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  imds_support = "v2.0"

  # network specific details
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface = var.ssh_interface
}

build {
  name = "unity-license-server-linux-packer"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "file" {
    source = "install_unzip.ubuntu.sh"
    destination = "/tmp/install_unzip.ubuntu.sh"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      cloud-init status --wait
      sudo chmod 755 /tmp/install_unzip.ubuntu.sh
      /tmp/install_unzip.ubuntu.sh
      EOF
    ]
  }

  provisioner "file" {
    source      = "${path.root}/${var.path_to_unity_license_zip}"
    destination = "/tmp/Unity.Licensing.Server.zip"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      cloud-init status --wait
      sudo mkdir -p /opt/UnityLicensingServer
      sudo unzip /tmp/Unity.Licensing.Server.zip -d /opt/UnityLicensingServer
      rm /tmp/Unity.Licensing.Server.zip
      sudo chmod +x /opt/UnityLicensingServer/Unity.Licensing.Server
      EOF
    ]
  }
}
