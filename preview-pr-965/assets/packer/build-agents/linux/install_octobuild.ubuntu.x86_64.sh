#!/usr/bin/env bash
# Install octobuild on Ubuntu, x86_64 only
#  (octobuild does not seem to have packages available for aarch64 at the moment)
# Requires common tools to be installed first.
sudo apt-get -o DPkg::Lock::Timeout=180 update -y
sudo NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=180 install -y apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/octobuild/octobuild/setup.deb.sh' | sudo -E bash
sudo NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=180 install -y octobuild
sudo mkdir -p /etc/octobuild
