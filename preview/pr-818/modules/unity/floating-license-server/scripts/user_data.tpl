#!/bin/bash

# Send all output to console and log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# License Server Setup
${server_setup_script}

# License Watch Daemon Setup
${daemon_setup_script}

# Create completion flag so Terraform script can end
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating completion flag..."
touch /tmp/user-data-complete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] User data script completed"
echo "[END_UDS_TKN]" | tee /dev/console
