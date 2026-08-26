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

variable "ami_prefix" {
  type    = string
  default = "jenkins-builder-amazon-linux-2023-x86_64"
}

variable "public_key" {
  type = string
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "al2023" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = "c5.2xlarge" # we need to build octobuild from source as there are no packages available for AL2023, and this requires a bit beefier of an instance
  region        = var.region
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
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
  name    = "jenkins-linux-packer"
  sources = [
    "source.amazon-ebs.al2023"
  ]

  provisioner "file" {
    source = "install_common.al2023.sh"
    destination = "/tmp/install_common.al2023.sh"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      cloud-init status --wait
      sudo chmod 755 /tmp/install_common.al2023.sh
      /tmp/install_common.al2023.sh
      EOF
    ]
  }

  # add the public key
  provisioner "shell" {
    inline = [
      <<-EOF
      echo "${var.public_key}" >> ~/.ssh/authorized_keys
      chmod 700 ~/.ssh
      chmod 600 ~/.ssh/authorized_keys
      EOF
    ]
  }

  provisioner "file" {
    source = "install_mold.sh"
    destination = "/tmp/install_mold.sh"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      sudo chmod 755 /tmp/install_mold.sh
      /tmp/install_mold.sh
      EOF
    ]
  }

  provisioner "file" {
    source = "octobuild.conf"
    destination = "/tmp/octobuild.conf"
  }
  provisioner "file" {
    source = "install_octobuild.al2023.x86_64.sh"
    destination = "/tmp/install_octobuild.al2023.x86_64.sh"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      sudo chmod 755 /tmp/install_octobuild.al2023.x86_64.sh
      /tmp/install_octobuild.al2023.x86_64.sh
      sudo mkdir -p /etc/octobuild/
      sudo cp /tmp/octobuild.conf /etc/octobuild/octobuild.conf
      EOF
    ]
  }

  provisioner "file" {
    source = "fsx_automounter.py"
    destination = "/tmp/fsx_automounter.py"
  }
  provisioner "file" {
    source = "fsx_automounter.service"
    destination = "/tmp/fsx_automounter.service"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      sudo cp /tmp/fsx_automounter.py /opt/fsx_automounter.py
      sudo dos2unix /opt/fsx_automounter.py
      sudo chmod 755 /opt/fsx_automounter.py
      sudo mkdir -p /etc/systemd/system/
      sudo cp /tmp/fsx_automounter.service /etc/systemd/system/fsx_automounter.service
      sudo chmod 755 /etc/systemd/system/fsx_automounter.service
      sudo systemctl enable fsx_automounter.service
      EOF
    ]
  }

  # set up script to automatically format and mount ephemeral storage
  provisioner "file" {
    source = "mount_ephemeral.sh"
    destination = "/tmp/mount_ephemeral.sh"
  }
  provisioner "file" {
    source = "mount_ephemeral.service"
    destination = "/tmp/mount_ephemeral.service"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      sudo cp /tmp/mount_ephemeral.sh /opt/mount_ephemeral.sh
      sudo dos2unix /opt/mount_ephemeral.sh
      sudo chmod 755 /opt/mount_ephemeral.sh
      sudo mkdir -p /etc/systemd/system/
      sudo cp /tmp/mount_ephemeral.service /etc/systemd/system/mount_ephemeral.service
      sudo chmod 755 /etc/systemd/system/mount_ephemeral.service
      sudo systemctl enable mount_ephemeral.service
      EOF
    ]
  }

  provisioner "file" {
    source = "create_swap.sh"
    destination = "/tmp/create_swap.sh"
  }
  provisioner "file" {
    source = "create_swap.service"
    destination = "/tmp/create_swap.service"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      sudo cp /tmp/create_swap.sh /opt/create_swap.sh
      sudo dos2unix /opt/create_swap.sh
      sudo chmod 755 /opt/create_swap.sh
      sudo mkdir -p /etc/systemd/system/
      sudo cp /tmp/create_swap.service /etc/systemd/system/create_swap.service
      sudo chmod 755 /etc/systemd/system/create_swap.service
      sudo systemctl enable create_swap.service
      EOF
    ]
  }

  provisioner "file" {
    source = "sccache.service"
    destination = "/tmp/sccache.service"
  }
  provisioner "file" {
    source = "install_sccache.sh"
    destination = "/tmp/install_sccache.sh"
  }
  provisioner "shell" {
    inline = [
      <<-EOF
      sudo chmod 755 /tmp/install_sccache.sh
      /tmp/install_sccache.sh
      sudo mkdir -p /etc/systemd/system/
      sudo cp /tmp/sccache.service /etc/systemd/system/sccache.service
      sudo chmod 755 /etc/systemd/system/sccache.service
      sudo systemctl enable sccache.service
      EOF
    ]
  }
}
