#!/bin/bash

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Starting user data script execution..."

log_message "Installing prerequisites..."
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 install -y fuse3 s3fs unzip expect

# Install AWS CLI v2
log_message "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Mount S3 bucket to file system
log_message "Creating mount point..."
mkdir -p /mnt/s3
chown ubuntu:ubuntu /mnt/s3
chmod 755 /mnt/s3

log_message "Mounting S3 bucket..."
s3fs "${s3_bucket_name}" /mnt/s3 -o iam_role="${iam_role_name}" -o allow_other -o uid=$(id -u ubuntu) -o gid=$(id -g ubuntu) -o stat_cache_expire=1 -o use_cache=/tmp -o del_cache

# Create the unity-licensing-server group
log_message "Creating unity-licensing-server group..."
groupadd unity-licensing-server

# Add ubuntu user to the group
log_message "Adding ubuntu user to unity-licensing-server group..."
usermod -a -G unity-licensing-server ubuntu

# Set correct ownership for Unity directories
chown -R ubuntu:unity-licensing-server /opt/UnityLicensingServer
chown -R ubuntu:unity-licensing-server /usr/share/unity3d/LicensingServer

# Set correct permissions
chmod -R 775 /opt/UnityLicensingServer
chmod -R 775 /usr/share/unity3d/LicensingServer

# Create directory and extract file
log_message "Creating Unity License Server directory..."
mkdir -p /opt/UnityLicensingServer
chown ubuntu:ubuntu /opt/UnityLicensingServer

log_message "Copying and extracting Unity License Server..."
cp /mnt/s3/"${license_server_file_name}" /opt/UnityLicensingServer/
cd /opt/UnityLicensingServer
unzip "${license_server_file_name}"
chmod +x Unity.Licensing.Server

log_message "Getting admin password from Secrets Manager..."
ADMIN_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "${admin_password_arn}" --query 'SecretString' --output text)

log_message "Setting up Unity License Server..."
# Create expect script from base server_setup.exp file
cat << 'EXPECT' > setup.exp
${server_setup_expect}
EXPECT

# Replace the admin password placeholder with value from Secrets Manager and run
sed -i 's/\[ADMIN_PWD_PLACEHOLDER\]/'"$ADMIN_PASSWORD"'/' setup.exp
chmod +x setup.exp
./setup.exp "${license_server_name}" "${license_server_port}"

# Ensure Unity License Server data directory exists with correct permissions
log_message "Setting up Unity License Server data directory..."
mkdir -p /usr/share/unity3d/LicensingServer/data
chown -R ubuntu:ubuntu /usr/share/unity3d/LicensingServer
chmod -R 755 /usr/share/unity3d/LicensingServer

log_message "Creating systemd service..."
# Create systemd service from base server_setup_systemd.service file
cat << 'SYSTEMD' > /etc/systemd/system/unity-license-server.service
${server_setup_systemd_service}
SYSTEMD

log_message "Starting Unity License Server..."
systemctl daemon-reload
systemctl enable unity-license-server
systemctl start unity-license-server

# Add automatic S3 mount on boot
echo "${s3_bucket_name} /mnt/s3 fuse.s3fs _netdev,allow_other,iam_role=${iam_role_name},uid=$(id -u ubuntu),gid=$(id -g ubuntu) 0 0" >> /etc/fstab

# Copy generated files to S3
log_message "Copying generated files to S3..."
cp /opt/UnityLicensingServer/server-registration-request.xml /mnt/s3/
cp /opt/UnityLicensingServer/services-config.json /mnt/s3/
