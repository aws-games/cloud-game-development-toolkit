#!/bin/bash
# User data script for P4 Code Review native EC2 instance
# Handles EBS volume attachment/mounting and Swarm configuration

set -e
set -o pipefail

# Configuration variables (injected by Terraform)
REGION="${region}"
DEVICE_NAME="${device_name}"
MOUNT_PATH="${mount_path}"
VOLUME_TAG_KEY="SwarmDataVolume"
VOLUME_TAG_VALUE="true"
MODULE_TAG_VALUE="${module_identifier}"

# P4 Code Review configuration parameters
P4D_PORT="${p4d_port}"
P4CHARSET="${p4charset}"
SWARM_HOST="${swarm_host}"
SWARM_REDIS="${swarm_redis}"
SWARM_REDIS_PORT="${swarm_redis_port}"
SWARM_FORCE_EXT="${swarm_force_ext}"

# Secret ARNs for AWS Secrets Manager
P4D_SUPER_PASSWD_SECRET_ARN="${super_user_password_secret_arn}"
SWARM_USER_SECRET_ARN="${p4_code_review_user_username_secret_arn}"
SWARM_PASSWD_SECRET_ARN="${p4_code_review_user_password_secret_arn}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/swarm-startup.log
}

log "========================================="
log "Starting P4 Code Review native EC2 setup"
log "========================================="

# 1. Get instance metadata
log "Fetching instance metadata..."
IMDS_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_AZ=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

log "Instance ID: $INSTANCE_ID"
log "Instance AZ: $INSTANCE_AZ"

# 2. Find the EBS volume by tags
log "Searching for EBS volume with tags: $VOLUME_TAG_KEY=$VOLUME_TAG_VALUE, ModuleIdentifier=$MODULE_TAG_VALUE"

VOLUME_ID=$(aws ec2 describe-volumes \
    --region "$REGION" \
    --filters \
        "Name=tag:$VOLUME_TAG_KEY,Values=$VOLUME_TAG_VALUE" \
        "Name=tag:ModuleIdentifier,Values=$MODULE_TAG_VALUE" \
        "Name=availability-zone,Values=$INSTANCE_AZ" \
    --query 'Volumes[0].VolumeId' \
    --output text)

if [ "$VOLUME_ID" == "None" ] || [ -z "$VOLUME_ID" ]; then
    log "ERROR: Could not find EBS volume with required tags in AZ $INSTANCE_AZ"
    exit 1
fi

log "Found EBS volume: $VOLUME_ID"

# 3. Check current volume attachment status
VOLUME_INFO=$(aws ec2 describe-volumes \
    --region "$REGION" \
    --volume-ids "$VOLUME_ID" \
    --query 'Volumes[0].{State:State,AttachedInstance:Attachments[0].InstanceId,AttachState:Attachments[0].State}' \
    --output json)

VOLUME_STATE=$(echo "$VOLUME_INFO" | jq -r '.State')
ATTACHED_INSTANCE=$(echo "$VOLUME_INFO" | jq -r '.AttachedInstance // "none"')
ATTACH_STATE=$(echo "$VOLUME_INFO" | jq -r '.AttachState // "none"')

log "Volume state: $VOLUME_STATE, Attached to: $ATTACHED_INSTANCE, Attach state: $ATTACH_STATE"

if [ "$ATTACHED_INSTANCE" == "$INSTANCE_ID" ]; then
    log "Volume $VOLUME_ID is already attached to this instance"
elif [ "$ATTACHED_INSTANCE" != "none" ] && [ "$ATTACHED_INSTANCE" != "null" ]; then
    log "Volume is attached to different instance $ATTACHED_INSTANCE - checking instance state"

    # Check if the attached instance is terminated before force detaching
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$ATTACHED_INSTANCE" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null || echo "unknown")

    log "Previous instance $ATTACHED_INSTANCE state: $INSTANCE_STATE"

    if [ "$INSTANCE_STATE" = "terminated" ] || [ "$INSTANCE_STATE" = "unknown" ]; then
        log "Previous instance is terminated/unknown, safe to force detach"
        aws ec2 detach-volume \
            --region "$REGION" \
            --volume-id "$VOLUME_ID" \
            --force 2>&1 | tee -a /tmp/swarm-setup.log || log "Warning: Force detach may have failed"
    else
        log "ERROR: Volume attached to running instance $ATTACHED_INSTANCE (state: $INSTANCE_STATE)"
        log "Cannot safely detach volume - manual intervention required"
        exit 1
    fi

    # Wait for detachment with timeout
    log "Waiting up to 2 minutes for volume to become available..."
    for i in {1..24}; do
        CURRENT_STATE=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$VOLUME_ID" --query 'Volumes[0].State' --output text)
        if [ "$CURRENT_STATE" == "available" ]; then
            log "Volume is now available"
            break
        fi
        log "Volume state: $CURRENT_STATE (attempt $i/24)"
        sleep 5
    done

    log "Attaching volume $VOLUME_ID to instance $INSTANCE_ID at $DEVICE_NAME"
    aws ec2 attach-volume \
        --region "$REGION" \
        --volume-id "$VOLUME_ID" \
        --instance-id "$INSTANCE_ID" \
        --device "$DEVICE_NAME"

    log "Waiting for volume attachment..."
    aws ec2 wait volume-in-use \
        --region "$REGION" \
        --volume-ids "$VOLUME_ID"

    log "Volume attached successfully"
else
    log "Attaching volume $VOLUME_ID to instance $INSTANCE_ID at $DEVICE_NAME"

    aws ec2 attach-volume \
        --region "$REGION" \
        --volume-id "$VOLUME_ID" \
        --instance-id "$INSTANCE_ID" \
        --device "$DEVICE_NAME"

    log "Waiting for volume attachment..."
    aws ec2 wait volume-in-use \
        --region "$REGION" \
        --volume-ids "$VOLUME_ID"

    log "Volume attached successfully"
fi

# 4. Find the actual device name (NVMe instances use different naming)
log "Looking for attached device..."
ACTUAL_DEVICE=""
for i in {1..30}; do
    # Try the original device name first
    if [ -e "$DEVICE_NAME" ]; then
        ACTUAL_DEVICE="$DEVICE_NAME"
        log "Found device at $ACTUAL_DEVICE"
        break
    fi

    # Look for NVMe device by volume ID symlink
    NVME_LINK="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_$${VOLUME_ID//-/}"
    if [ -L "$NVME_LINK" ]; then
        ACTUAL_DEVICE=$(readlink -f "$NVME_LINK")
        log "Found NVMe device via symlink: $ACTUAL_DEVICE"
        break
    fi

    log "Attempt $i/30: Device not yet available, waiting..."
    sleep 2
done

if [ -z "$ACTUAL_DEVICE" ]; then
    log "ERROR: Could not find attached device after 60 seconds"
    log "Expected: $DEVICE_NAME or /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_$${VOLUME_ID//-/}"
    exit 1
fi

DEVICE_NAME="$ACTUAL_DEVICE"
log "Using device: $DEVICE_NAME"

# 5. Check if the device has a filesystem, if not create one
log "Checking filesystem on $DEVICE_NAME..."
if ! blkid "$DEVICE_NAME" > /dev/null 2>&1; then
    log "No filesystem detected on $DEVICE_NAME, creating ext4 filesystem..."
    mkfs -t ext4 "$DEVICE_NAME"
    log "Filesystem created successfully"
else
    log "Existing filesystem detected on $DEVICE_NAME"
fi

# 6. Create mount point if it doesn't exist
if [ ! -d "$MOUNT_PATH" ]; then
    log "Creating mount point: $MOUNT_PATH"
    mkdir -p "$MOUNT_PATH"
fi

# 7. Mount the volume
log "Mounting $DEVICE_NAME to $MOUNT_PATH..."
mount "$DEVICE_NAME" "$MOUNT_PATH"
log "Volume mounted successfully"

# 8. Set proper permissions for Swarm
log "Setting permissions on $MOUNT_PATH..."
chmod 755 "$MOUNT_PATH"
chown -R swarm:swarm "$MOUNT_PATH"

# 9. Add entry to /etc/fstab for automatic mounting on reboot
if ! grep -q "$DEVICE_NAME" /etc/fstab; then
    log "Adding entry to /etc/fstab for persistent mounting..."
    echo "$DEVICE_NAME $MOUNT_PATH ext4 defaults,nofail 0 2" >> /etc/fstab
    log "fstab entry added"
else
    log "fstab entry already exists"
fi

# 10. Verify mount
if mountpoint -q "$MOUNT_PATH"; then
    log "SUCCESS: $MOUNT_PATH is mounted"
    df -h "$MOUNT_PATH"
else
    log "ERROR: $MOUNT_PATH is not mounted"
    exit 1
fi

# 11. Configure Swarm using the script from the AMI
log "Configuring P4 Code Review with runtime parameters..."

# Write custom config JSON to file if provided (for swarm_instance_init.sh to merge)
CUSTOM_CONFIG_FILE="/tmp/swarm_custom_config.json"
%{ if custom_config != null && custom_config != "" ~}
cat > "$CUSTOM_CONFIG_FILE" << 'CUSTOM_CONFIG_EOF'
${custom_config}
CUSTOM_CONFIG_EOF
log "Custom config written to $CUSTOM_CONFIG_FILE"
%{ else ~}
log "No custom config provided"
%{ endif ~}

/home/ubuntu/swarm_scripts/swarm_instance_init.sh \
  --p4d-port "$P4D_PORT" \
  --p4charset "$P4CHARSET" \
  --swarm-host "$SWARM_HOST" \
  --swarm-redis "$SWARM_REDIS" \
  --swarm-redis-port "$SWARM_REDIS_PORT" \
  --swarm-force-ext "$SWARM_FORCE_EXT" \
  --p4d-super-passwd-secret-arn "$P4D_SUPER_PASSWD_SECRET_ARN" \
  --swarm-user-secret-arn "$SWARM_USER_SECRET_ARN" \
  --swarm-passwd-secret-arn "$SWARM_PASSWD_SECRET_ARN" \
  --custom-config-file "$CUSTOM_CONFIG_FILE"

log "========================================="
log "P4 Code Review native EC2 setup completed successfully"
log "P4 Code Review should be accessible at: https://$SWARM_HOST"
log "Data path: $MOUNT_PATH"
log "========================================="
