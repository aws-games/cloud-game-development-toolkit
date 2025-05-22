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
echo "Updating apt.."
sudo export DEBIAN_FRONTEND="noninteractive" apt-get -o DPkg::Lock::Timeout=180 update -y
echo "Installing unzip..."
sudo export DEBIAN_FRONTEND="noninteractive" apt-get install -y unzip
