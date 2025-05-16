#!/bin/bash
set -e

echo "Installing .NET Runtime..."

# Add Microsoft package repository
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Install .NET Runtime
sudo apt-get update
sudo apt-get install -y dotnet-runtime-6.0

# Verify installation
dotnet --info

echo ".NET Runtime installation completed"
