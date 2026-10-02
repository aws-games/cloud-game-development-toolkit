#!/usr/bin/env bash
# Install common tools on Amazon Linux 2023, architecture-independent.
# These common tools are necessary for Jenkins Agents, and to build/install various other software.
# Core common tools:
#  git
#  curl
#  jq
#  unzip
#  AWS CLI
#  AWS Systems Manager Agent
#  Amazon Corretto
#  mount.nfs (already installed on Amazon Linux)
#  python3
#  python3-pip
#  python3-requests
#  boto3
#  botocore
#  dos2unix
#  clang
#  scons
#  cmake3

cloud-init status --wait
echo "Updating packages..."
sudo yum update -y
echo "Installing packages..."
sudo yum -y groupinstall "Development Tools"
sudo dnf install -y awscli java-11-amazon-corretto-headless java-11-amazon-corretto-devel libarchive libarchive-devel unzip cmake python3 python3-pip python3-requests clang lld git openssl libcurl-devel openssl-devel uuid-devel zlib-devel pulseaudio-libs-devel jq freetype-devel libsndfile-devel python3 jq libX11-devel libXcursor-devel libXinerama-devel mesa-libGL-devel mesa-libGLU-devel libudev-devel libXi-devel libXrandr-devel dos2unix
sudo pip install boto3 botocore scons
if [ "$(uname -p)" == "x86_64" ]; then
    sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
fi
if [ "$(uname -p)" == "aarch64" ]; then
    sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm
fi
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
