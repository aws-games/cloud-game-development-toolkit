#!/bin/bash
set -e

echo "Installing Wine with multiarch support..."

# Enable 32-bit architecture
sudo dpkg --add-architecture i386
sudo apt-get update

# Install Wine and 32-bit support
sudo apt-get install -y wine wine32:i386

# Verify installation
wine --version

echo "Wine installation completed"
