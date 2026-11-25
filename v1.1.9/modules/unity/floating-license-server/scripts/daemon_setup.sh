#!/bin/bash

# Define logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Setting up license watch daemon..."

# Install inotify-tools
log_message "Installing inotify-tools..."
apt-get -o DPkg::Lock::Timeout=120 install -y inotify-tools

# Create the watch script
log_message "Creating watch script..."
cat << 'WATCHSCRIPT' > /opt/UnityLicensingServer/daemon_setup_watch.sh
${daemon_setup_watch}
WATCHSCRIPT

# Make the watch script executable and set ownership
chmod +x /opt/UnityLicensingServer/daemon_setup_watch.sh
chown ubuntu:ubuntu /opt/UnityLicensingServer/daemon_setup_watch.sh

# Create the systemd service
log_message "Creating systemd service for license watch..."
cat << WATCHSERVICE > /etc/systemd/system/unity-license-watch.service
${daemon_setup_systemd_service}
WATCHSERVICE

# Create the import expect script
log_message "Creating import expect script..."
cat << 'IMPORTSCRIPT' > /opt/UnityLicensingServer/daemon_setup_expect.exp
${daemon_setup_expect}
IMPORTSCRIPT

chmod +x /opt/UnityLicensingServer/daemon_setup_expect.exp

# Ensure proper ownership of all Unity License Server files
chown -R ubuntu:ubuntu /opt/UnityLicensingServer

# Configure sudo access for the ubuntu user to manage the service without password
echo "ubuntu ALL=(ALL) NOPASSWD: /bin/systemctl restart unity-license-server" > /etc/sudoers.d/unity-license
echo "ubuntu ALL=(ALL) NOPASSWD: /bin/systemctl stop unity-license-watch" >> /etc/sudoers.d/unity-license
echo "ubuntu ALL=(ALL) NOPASSWD: /opt/UnityLicensingServer/Unity.Licensing.Server" >> /etc/sudoers.d/unity-license
chmod 440 /etc/sudoers.d/unity-license

# Enable and start the watch service
log_message "Enabling and starting license watch service..."
systemctl daemon-reload
systemctl enable unity-license-watch
systemctl start unity-license-watch

log_message "License watch daemon setup completed"
