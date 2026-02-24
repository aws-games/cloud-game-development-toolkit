#!/bin/bash

# Log file location
LOG_FILE="/var/log/p4_setup.log"

# Function to log messages
log_message() {
    echo "$(date) - $1" >> $LOG_FILE
}

# Constants
ROOT_UID=0

# Check if script is run as root
if [ "$UID" -ne "$ROOT_UID" ]; then
  echo "Must be root to run this script."
  log_message "Function not run as a root."
  exit 1
fi

# Set local variables
SDP_Root=/hxdepots/sdp/helix_binaries
SDP=/hxdepots/sdp
PACKAGE="policycoreutils-python-utils" # Required in both

# Function to check SELinux status
check_selinux_status() {
    SELINUX_STATUS=$(getenforce)
    if [ "$SELINUX_STATUS" = "Enforcing" ] || [ "$SELINUX_STATUS" = "Permissive" ]; then
        log_message "SELinux is enabled."
        return 0  # Return 0 for enabled
    else
        log_message "SELinux is not enabled."
        return 1  # Return 1 for disabled
    fi
}

# Function to check if a group exists
group_exists() {
  getent group $1 > /dev/null 2>&1
}

# Function to check if a user exists
user_exists() {
  id -u $1 > /dev/null 2>&1
}

# Function to check if a directory exists
directory_exists() {
  [ -d "$1" ]
}

log_message "Installing Perforce"

# Check if SELinux is enabled
if check_selinux_status; then
    if ! dnf list installed "$PACKAGE" &> /dev/null; then
        log_message "Package $PACKAGE is not installed. Installing..."
        sudo dnf install -y $PACKAGE
        if [ $? -eq 0 ]; then
            log_message "$PACKAGE installed successfully."
        else
            log_message "Failed to install $PACKAGE."
        fi
    else
        log_message "Package $PACKAGE is already installed."
    fi
else
    log_message "SELinux is not enabled. Skipping package installation."
fi

# Check if group 'perforce' exists, if not, add it
if ! group_exists perforce; then
  groupadd perforce
fi

# Check if user 'perforce' exists, if not, add it
if ! user_exists perforce; then
  useradd -d /home/perforce -s /bin/bash -m perforce -g perforce
fi

# Set up sudoers for perforce user
if [ ! -f /etc/sudoers.d/perforce ]; then
  touch /etc/sudoers.d/perforce
  chmod 0600 /etc/sudoers.d/perforce
  echo "perforce ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/perforce
  chmod 0400 /etc/sudoers.d/perforce
fi

# Create directories if they don't exist
for dir in /hxdepots /hxlogs /hxmetadata; do
  if ! directory_exists $dir; then
    mkdir $dir
  fi
done

# Change ownership
chown -R perforce:perforce /hx*

# Download and extract SDP
cd /hxdepots
if [ ! -f sdp.Unix.tgz ]; then
  log_message "Downloading SDP..."
  curl -L -O https://swarm.workshop.perforce.com/download/guest/perforce_software/sdp/downloads/sdp.Unix.tgz
  tar -xzf sdp.Unix.tgz
fi

chmod -R +w $SDP
cd $SDP_Root
# checking if required binaries are in the folder.
required_binaries=(p4 p4broker p4d p4p)
missing_binaries=0

# Check each binary
for binary in "${required_binaries[@]}"; do
    if [ ! -f "/hxdepots/sdp/helix_binaries/$binary" ]; then
        echo "Missing binary: $binary"
        missing_binaries=1
        break
    fi
done

# Download binaries if any are missing
if [ $missing_binaries -eq 1 ]; then
    echo "One or more Perforce binaries are missing. Running get_helix_binaries.sh..."
    /hxdepots/sdp/helix_binaries/get_helix_binaries.sh
else
    echo "All Perforce binaries are present."
fi
###### previously each run got the binaries by: /hxdepots/sdp/helix_binaries/get_helix_binaries.sh

chown -R perforce:perforce $SDP_Root
