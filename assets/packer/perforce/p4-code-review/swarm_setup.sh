#!/bin/bash

# Log file location
LOG_FILE="/var/log/swarm_setup.log"

# Function to log messages
log_message() {
    echo "$(date) - $1" | tee -a $LOG_FILE
}

# Constants
ROOT_UID=0

# Check if script is run as root
if [ "$UID" -ne "$ROOT_UID" ]; then
  echo "Must be root to run this script."
  log_message "Script not run as root."
  exit 1
fi

log_message "Starting P4 Code Review (Swarm) installation"

# Wait for dpkg lock to be released (unattended-upgrades may be running)
wait_for_apt() {
  local max_wait=300
  local wait_time=0
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    if [ $wait_time -ge $max_wait ]; then
      log_message "ERROR: Timed out waiting for apt lock after ${max_wait}s"
      exit 1
    fi
    log_message "Waiting for apt lock to be released..."
    sleep 5
    wait_time=$((wait_time + 5))
  done
}

log_message "Waiting for any background package operations to complete"
wait_for_apt

# Update package lists
log_message "Updating package lists"
apt-get update

# Install required dependencies
log_message "Installing required dependencies"
apt-get install -y software-properties-common gnupg2 wget apt-transport-https ca-certificates unzip curl

# Install AWS CLI v2
log_message "Installing AWS CLI v2"
(
  cd /tmp || exit 1
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
)

# Add Perforce repository
log_message "Adding Perforce repository"
wget -qO - https://package.perforce.com/perforce.pubkey | gpg --dearmor | tee /usr/share/keyrings/perforce-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/perforce-archive-keyring.gpg] http://package.perforce.com/apt/ubuntu noble release" | tee /etc/apt/sources.list.d/perforce.list

# Update package lists with new repository
log_message "Updating package lists with Perforce repository"
apt-get update

# Check if PHP 8.x is available natively
log_message "Checking for PHP 8.x availability"
if apt-cache show php8.3 &>/dev/null || apt-cache show php8.1 &>/dev/null; then
  log_message "PHP 8.x available natively, using system packages"
else
  log_message "PHP 8.x not available natively, adding ondrej/php PPA"
  add-apt-repository -y ppa:ondrej/php
  apt-get update
fi

# Determine which PHP 8.x version to install
if apt-cache show php8.3 &>/dev/null; then
  PHP_VERSION="8.3"
elif apt-cache show php8.1 &>/dev/null; then
  PHP_VERSION="8.1"
else
  log_message "ERROR: No PHP 8.x version available"
  exit 1
fi

log_message "Installing Apache2 and PHP ${PHP_VERSION} with required extensions"
apt-get install -y apache2 \
  php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-common \
  php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-ldap php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath \
  libapache2-mod-php${PHP_VERSION}

# Install PHP PECL extensions
log_message "Installing PHP PECL extensions"
apt-get install -y php${PHP_VERSION}-igbinary php${PHP_VERSION}-msgpack php${PHP_VERSION}-redis

# Install Helix Swarm
log_message "Installing Helix Swarm"
apt-get install -y helix-swarm

# Install helix-swarm-optional package (LibreOffice, ImageMagick)
if [ "${INSTALL_SWARM_OPTIONAL:-true}" = "true" ]; then
  log_message "Installing helix-swarm-optional package"
  apt-get install -y helix-swarm-optional || log_message "helix-swarm-optional package not available, skipping"
else
  log_message "Skipping helix-swarm-optional installation"
fi

# Enable required Apache modules
log_message "Enabling required Apache modules"
a2enmod rewrite
a2enmod proxy
a2enmod proxy_fcgi
a2enmod setenvif

# Enable PHP-FPM configuration for Apache
log_message "Configuring PHP-FPM for Apache"
a2enconf php*-fpm

# Enable and configure Apache
log_message "Enabling Apache service"
systemctl enable apache2

# Enable and configure PHP-FPM
log_message "Enabling PHP-FPM service"
systemctl enable php${PHP_VERSION}-fpm

# Create swarm user if it doesn't exist (package may have already created it)
if ! id -u swarm > /dev/null 2>&1; then
  log_message "Creating swarm user"
  useradd -r -s /bin/bash swarm
fi

# Set proper ownership on Swarm directories
log_message "Setting ownership on Swarm directories"
chown -R swarm:swarm /opt/perforce/swarm || log_message "Swarm directory ownership already set"

# Configure AppArmor for Swarm (Ubuntu uses AppArmor instead of SELinux)
if command -v aa-status > /dev/null 2>&1; then
  log_message "AppArmor is active"
  # AppArmor is less restrictive by default for /opt
  # Additional configuration can be added here if needed
else
  log_message "AppArmor not found, skipping AppArmor configuration"
fi

log_message "P4 Code Review (Swarm) installation completed successfully"
log_message "Configuration will be done at runtime via swarm_instance_init.sh"
