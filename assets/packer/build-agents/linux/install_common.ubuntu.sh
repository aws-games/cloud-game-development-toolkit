#!/usr/bin/env bash
# Install common tools on Ubuntu, architecture-independent.
# These common tools are necessary for Jenkins Agents, and to build/install various other software.
# Core common tools:
#  git
#  curl
#  jq
#  unzip
#  AWS CLI
#  AWS Systems Manager Agent
#  Amazon Corretto
#  mount.nfs
#  python3
#  python3-pip
#  python3-requests
#  python3-botocore
#  boto3
#  dos2unix
#  clang
#  scons
#  cmake3

cloud-init status --wait
wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
echo "Updating apt.."
sudo apt-get -o DPkg::Lock::Timeout=180 update -y
echo "Installing packages..."
sudo apt-get -o DPkg::Lock::Timeout=180 install -y nfs-common libarchive-tools unzip cmake build-essential python3 python3-pip python3-requests python3-botocore clang lld git openssl libcurl4-openssl-dev libssl-dev uuid-dev zlib1g-dev libpulse-dev scons jq libsdl2-mixer-dev libsdl2-image-dev libsdl2-dev libfreetype-dev libsndfile1-dev libopenal-dev python3 jq libx11-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev libglu-dev libasound2-dev libudev-dev libxi-dev libxrandr-dev java-11-amazon-corretto-jdk dos2unix
sudo pip install boto3
echo "Installing AWS cli..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo snap install amazon-ssm-agent --classic