#!/bin/bash

# P4 Code Review Runtime Configuration Script
# Configures P4 Code Review with P4 Server connection details, Redis cache, and other runtime settings
# This script is called by user-data at instance launch time

LOG_FILE="/var/log/swarm_configure.log"

log_message() {
    echo "$(date) - $1" | tee -a $LOG_FILE
}

ROOT_UID=0
if [ "$UID" -ne "$ROOT_UID" ]; then
  echo "Must be root to run this script."
  exit 1
fi

log_message "========================================="
log_message "Starting P4 Code Review runtime configuration"
log_message "========================================="

# Parse command line arguments
P4D_PORT=""
P4CHARSET="none"
SWARM_HOST=""
SWARM_REDIS=""
SWARM_REDIS_PORT="6379"
SWARM_FORCE_EXT="y"
ENABLE_SSO="false"

# Secret ARNs for fetching credentials from AWS Secrets Manager
P4D_SUPER_SECRET_ARN=""
P4D_SUPER_PASSWD_SECRET_ARN=""
SWARM_USER_SECRET_ARN=""
SWARM_PASSWD_SECRET_ARN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --p4d-port)
      P4D_PORT="$2"
      shift 2
      ;;
    --p4charset)
      P4CHARSET="$2"
      shift 2
      ;;
    --swarm-host)
      SWARM_HOST="$2"
      shift 2
      ;;
    --swarm-redis)
      SWARM_REDIS="$2"
      shift 2
      ;;
    --swarm-redis-port)
      SWARM_REDIS_PORT="$2"
      shift 2
      ;;
    --swarm-force-ext)
      SWARM_FORCE_EXT="$2"
      shift 2
      ;;
    --enable-sso)
      ENABLE_SSO="$2"
      shift 2
      ;;
    --p4d-super-secret-arn)
      P4D_SUPER_SECRET_ARN="$2"
      shift 2
      ;;
    --p4d-super-passwd-secret-arn)
      P4D_SUPER_PASSWD_SECRET_ARN="$2"
      shift 2
      ;;
    --swarm-user-secret-arn)
      SWARM_USER_SECRET_ARN="$2"
      shift 2
      ;;
    --swarm-passwd-secret-arn)
      SWARM_PASSWD_SECRET_ARN="$2"
      shift 2
      ;;
    *)
      log_message "Unknown parameter: $1"
      shift
      ;;
  esac
done

log_message "Configuration parameters:"
log_message "P4D_PORT: $P4D_PORT"
log_message "P4CHARSET: $P4CHARSET"
log_message "SWARM_HOST: $SWARM_HOST"
log_message "SWARM_REDIS: $SWARM_REDIS"
log_message "SWARM_REDIS_PORT: $SWARM_REDIS_PORT"
log_message "SWARM_FORCE_EXT: $SWARM_FORCE_EXT"
log_message "ENABLE_SSO: $ENABLE_SSO"

# Retrieve credentials from AWS Secrets Manager
log_message "Fetching secrets from AWS Secrets Manager"
P4D_SUPER=$(aws secretsmanager get-secret-value --secret-id "$P4D_SUPER_SECRET_ARN" --query SecretString --output text)
P4D_SUPER_PASSWD=$(aws secretsmanager get-secret-value --secret-id "$P4D_SUPER_PASSWD_SECRET_ARN" --query SecretString --output text)
SWARM_USER=$(aws secretsmanager get-secret-value --secret-id "$SWARM_USER_SECRET_ARN" --query SecretString --output text)
SWARM_PASSWD=$(aws secretsmanager get-secret-value --secret-id "$SWARM_PASSWD_SECRET_ARN" --query SecretString --output text)

if [ -z "$P4D_SUPER" ] || [ -z "$P4D_SUPER_PASSWD" ] || [ -z "$SWARM_USER" ] || [ -z "$SWARM_PASSWD" ]; then
  log_message "ERROR: Failed to fetch secrets from AWS Secrets Manager"
  exit 1
fi

log_message "Successfully fetched secrets"

# P4 Code Review data directory - stores application data and configuration
SWARM_DATA_PATH="/opt/perforce/swarm/data"
SWARM_CONFIG="${SWARM_DATA_PATH}/config.php"

# Ensure data directory exists with proper ownership
# Note: configure-swarm.sh will change these, we'll fix them again afterwards
mkdir -p "$SWARM_DATA_PATH"
chown -R swarm:www-data "$SWARM_DATA_PATH"
chmod 775 "$SWARM_DATA_PATH"

# Run the official P4 Code Review configuration script
# This handles initial setup and P4 Server extension installation
log_message "Running configure-swarm.sh with super user credentials"

/opt/perforce/swarm/sbin/configure-swarm.sh \
  -n \
  -p "$P4D_PORT" \
  -u "$SWARM_USER" \
  -w "$SWARM_PASSWD" \
  -H "$SWARM_HOST" \
  -e localhost \
  -X \
  -U "$P4D_SUPER" \
  -W "$P4D_SUPER_PASSWD" || {
    log_message "ERROR: configure-swarm.sh failed with exit code $?"
    log_message "This likely means P4 server connectivity or permissions issue"
    exit 1
  }

# Update Swarm extension configuration
# The Perforce configure-swarm.sh script sets Swarm-Secure to true by default
# We need to set it to false when using self-signed certificates
log_message "Updating Swarm extension configuration for SSL settings"

# Trust the P4 server SSL certificate and authenticate
log_message "Establishing P4 connection for extension configuration"
p4 -p "$P4D_PORT" trust -y 2>/dev/null || log_message "P4 trust already established or using non-SSL"
echo "$P4D_SUPER_PASSWD" | p4 -p "$P4D_PORT" -u "$P4D_SUPER" login 2>/dev/null || {
  log_message "WARNING: P4 login failed, extension configuration may not work"
}

p4 -p "$P4D_PORT" -u "$P4D_SUPER" extension --configure Perforce::helix-swarm -o | \
  sed 's/Swarm-Secure: true/Swarm-Secure: false/' | \
  p4 -p "$P4D_PORT" -u "$P4D_SUPER" extension --configure Perforce::helix-swarm -i || {
    log_message "WARNING: Failed to update Swarm extension configuration"
  }

# Configure initial permissions for Swarm data directory
# Note: Queue-specific permissions are set after Apache starts (see below)
log_message "Configuring initial permissions for Swarm data directory"
chown -R swarm:www-data "$SWARM_DATA_PATH"
chmod 775 "$SWARM_DATA_PATH"

# Ensure p4trust file is readable by Apache worker processes
chmod 644 "$SWARM_DATA_PATH/p4trust" 2>/dev/null || true

# Swarm application log must be a regular file with group write permissions
if [ -e "$SWARM_DATA_PATH/log" ] && [ ! -f "$SWARM_DATA_PATH/log" ]; then
  log_message "Correcting log path to be a regular file"
  rm -rf "$SWARM_DATA_PATH/log"
fi
if [ ! -f "$SWARM_DATA_PATH/log" ]; then
  touch "$SWARM_DATA_PATH/log"
  chown swarm:www-data "$SWARM_DATA_PATH/log"
  chmod 664 "$SWARM_DATA_PATH/log"
fi

# Add swarm-cron user to www-data group for queue worker file access
log_message "Adding swarm-cron user to www-data group"
usermod -aG www-data swarm-cron

# Update configuration file with runtime settings
log_message "Updating P4 Code Review configuration"

if [ -f "$SWARM_CONFIG" ]; then
  # Backup existing configuration
  cp "$SWARM_CONFIG" "${SWARM_CONFIG}.backup.$(date +%s)"

  log_message "Adding Redis configuration to config.php"

  # Use PHP to properly modify the configuration file
  php -r "
    \$config = include '$SWARM_CONFIG';

    // Configure Redis connection for session storage and caching
    if (!isset(\$config['redis'])) {
      \$config['redis'] = array();
    }
    \$config['redis']['options'] = array(
      'server' => array(
        'host' => '$SWARM_REDIS',
        'port' => $SWARM_REDIS_PORT,
      ),
    );

    // Set external URL for generating links in notifications and emails
    if (!isset(\$config['environment'])) {
      \$config['environment'] = array();
    }
    \$config['environment']['hostname'] = 'https://$SWARM_HOST';

    // Write back the configuration
    file_put_contents('$SWARM_CONFIG', '<?php' . PHP_EOL . 'return ' . var_export(\$config, true) . ';' . PHP_EOL);
  " || {
    log_message "ERROR: Failed to update config.php with Redis settings"
    exit 1
  }

  # Configure SSO (Single Sign-On) if enabled
  if [ "$ENABLE_SSO" = "true" ]; then
    log_message "Enabling SSO in configuration"
    php -r "
      \$config = include '$SWARM_CONFIG';
      \$config['saml']['sp']['entityId'] = 'https://$SWARM_HOST';
      \$config['saml']['sp']['assertionConsumerService']['url'] = 'https://$SWARM_HOST/saml/acs';
      \$config['saml']['sp']['singleLogoutService']['url'] = 'https://$SWARM_HOST/saml/sls';
      file_put_contents('$SWARM_CONFIG', '<?php' . PHP_EOL . 'return ' . var_export(\$config, true) . ';' . PHP_EOL);
    " || log_message "WARNING: Failed to add SSO configuration"

    # Clear cache when SSO settings change to force configuration reload
    rm -rf "${SWARM_DATA_PATH}/cache"/* 2>/dev/null || true
  fi

  chown swarm:www-data "$SWARM_CONFIG"
  chmod 664 "$SWARM_CONFIG"

  log_message "Configuration file updated successfully"
else
  log_message "ERROR: Config file not found at $SWARM_CONFIG after running configure-swarm.sh"
  exit 1
fi

# Disable default Apache site so Swarm becomes the default (important for health checks)
log_message "Disabling default Apache site"
a2dissite 000-default || log_message "Default site already disabled"

# Start Apache web server
log_message "Starting Apache service"
systemctl enable apache2
systemctl restart apache2
systemctl status apache2 --no-pager

# Start PHP-FPM for PHP request handling
if systemctl list-unit-files | grep -q php-fpm; then
  log_message "Starting PHP-FPM service"
  systemctl enable php-fpm
  systemctl start php-fpm
  systemctl status php-fpm --no-pager
fi

# Configure permissions for queue workers and caching
# This must run AFTER Apache starts because Swarm may create directories with restrictive permissions
log_message "Configuring permissions for queue worker functionality"

# Create queue directories if they don't exist
mkdir -p "$SWARM_DATA_PATH/queue/workers"
mkdir -p "$SWARM_DATA_PATH/queue/tokens"
mkdir -p "$SWARM_DATA_PATH/cache"

# Set ownership and permissions for queue-related directories
# Workers run as swarm-cron (in www-data group) and need write access
chown -R www-data:www-data "$SWARM_DATA_PATH/queue"
chmod 770 "$SWARM_DATA_PATH/queue"
chmod 770 "$SWARM_DATA_PATH/queue/workers"
chmod 770 "$SWARM_DATA_PATH/queue/tokens"
chown -R www-data:www-data "$SWARM_DATA_PATH/cache"
chmod 775 "$SWARM_DATA_PATH/cache"

# Configure P4 Code Review background workers for async tasks
# Workers are spawned by cron job created by configure-swarm.sh at /etc/cron.d/helix-swarm
# Update the default worker configuration to use localhost for optimal performance
log_message "Configuring P4 Code Review queue workers"

SWARM_CRON_CONFIG="/opt/perforce/etc/swarm-cron-hosts.conf"
log_message "Updating worker configuration at $SWARM_CRON_CONFIG"

# Workers should connect to localhost to avoid routing through load balancer
echo "http://localhost" > "$SWARM_CRON_CONFIG"
chown swarm-cron:swarm-cron "$SWARM_CRON_CONFIG"
chmod 644 "$SWARM_CRON_CONFIG"

log_message "Queue workers configured to use localhost endpoint"

# Ensure worker token is properly initialized
# The token file may exist but be empty after configure-swarm.sh runs
log_message "Initializing queue worker authentication token"

TOKEN_DIR="${SWARM_DATA_PATH}/queue/tokens"

# Find existing token file
TOKEN_FILE=$(find "$TOKEN_DIR" -type f 2>/dev/null | head -1)

if [ -n "$TOKEN_FILE" ] && [ -f "$TOKEN_FILE" ]; then
  # Check if token file is empty
  if [ ! -s "$TOKEN_FILE" ]; then
    log_message "Token file exists but is empty, generating new token"
    TOKEN_CONTENT=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$(hostname)")
    echo "$TOKEN_CONTENT" > "$TOKEN_FILE"
    chown www-data:www-data "$TOKEN_FILE"
    chmod 644 "$TOKEN_FILE"
    log_message "Worker token initialized: $(basename "$TOKEN_FILE")"
  else
    log_message "Worker token already exists and is valid"
  fi
else
  log_message "No token file found, creating new one"
  TOKEN_NAME=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "swarm-token-$(date +%s)")
  TOKEN_FILE="$TOKEN_DIR/$TOKEN_NAME"
  TOKEN_CONTENT=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$(hostname)")
  echo "$TOKEN_CONTENT" > "$TOKEN_FILE"
  chown www-data:www-data "$TOKEN_FILE"
  chmod 644 "$TOKEN_FILE"
  log_message "Worker token created: $TOKEN_NAME"
fi

log_message "========================================="
log_message "P4 Code Review configuration completed"
log_message "P4 Code Review should be accessible at: https://$SWARM_HOST"
log_message "Data path: $SWARM_DATA_PATH"
log_message "========================================="
