#!/bin/bash
# User data script for P4 Code Review ECS instance
# Handles EBS volume attachment and mounting for persistent Swarm data

set -e
set -o pipefail

# Configuration variables (injected by Terraform)
CLUSTER_NAME="${cluster_name}"
REGION="${region}"
DEVICE_NAME="${device_name}"
MOUNT_PATH="${mount_path}"
VOLUME_TAG_KEY="SwarmDataVolume"
VOLUME_TAG_VALUE="true"
CLUSTER_TAG_KEY="SwarmCluster"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/swarm-setup.log
}

log "========================================="
log "Starting P4 Code Review instance setup"
log "========================================="

# 1. Configure ECS agent to join the cluster
log "Configuring ECS agent to join cluster: $CLUSTER_NAME"
cat >> /etc/ecs/ecs.config <<EOF
ECS_CLUSTER=$CLUSTER_NAME
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_INSTANCE_ATTRIBUTES={"SwarmInstance": "true"}
EOF

# Enable and start ECS agent asynchronously to avoid cloud-init deadlock
# (ECS service has After=cloud-final.service, so starting it synchronously would block)
systemctl enable --now ecs &

log "ECS agent configuration applied, service starting in background"

# 2. Get instance metadata
log "Fetching instance metadata..."
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
INSTANCE_AZ=$(ec2-metadata --availability-zone | cut -d ' ' -f 2)

log "Instance ID: $INSTANCE_ID"
log "Instance AZ: $INSTANCE_AZ"

# 3. Find the EBS volume by tags
log "Searching for EBS volume with tags: $VOLUME_TAG_KEY=$VOLUME_TAG_VALUE and $CLUSTER_TAG_KEY=$CLUSTER_NAME"

VOLUME_ID=$(aws ec2 describe-volumes \
    --region "$REGION" \
    --filters \
        "Name=tag:$VOLUME_TAG_KEY,Values=$VOLUME_TAG_VALUE" \
        "Name=tag:$CLUSTER_TAG_KEY,Values=$CLUSTER_NAME" \
        "Name=availability-zone,Values=$INSTANCE_AZ" \
    --query 'Volumes[0].VolumeId' \
    --output text)

if [ "$VOLUME_ID" == "None" ] || [ -z "$VOLUME_ID" ]; then
    log "ERROR: Could not find EBS volume with required tags in AZ $INSTANCE_AZ"
    exit 1
fi

log "Found EBS volume: $VOLUME_ID"

# 4. Check if volume is already attached to this instance
ATTACHMENT_STATE=$(aws ec2 describe-volumes \
    --region "$REGION" \
    --volume-ids "$VOLUME_ID" \
    --query 'Volumes[0].Attachments[?InstanceId==`'"$INSTANCE_ID"'`].State' \
    --output text)

if [ "$ATTACHMENT_STATE" == "attached" ]; then
    log "Volume $VOLUME_ID is already attached to this instance"
else
    log "Attaching volume $VOLUME_ID to instance $INSTANCE_ID at $DEVICE_NAME"

    aws ec2 attach-volume \
        --region "$REGION" \
        --volume-id "$VOLUME_ID" \
        --instance-id "$INSTANCE_ID" \
        --device "$DEVICE_NAME"

    # Wait for attachment to complete
    log "Waiting for volume attachment..."
    aws ec2 wait volume-in-use \
        --region "$REGION" \
        --volume-ids "$VOLUME_ID"

    log "Volume attached successfully"
fi

# 5. Wait for device to appear
log "Waiting for device $DEVICE_NAME to be available..."
DEVICE_READY=false
for i in {1..30}; do
    if [ -e "$DEVICE_NAME" ]; then
        DEVICE_READY=true
        log "Device $DEVICE_NAME is ready"
        break
    fi
    log "Attempt $i/30: Device not yet available, waiting..."
    sleep 2
done

if [ "$DEVICE_READY" = false ]; then
    log "ERROR: Device $DEVICE_NAME did not appear after 60 seconds"
    exit 1
fi

# 6. Check if the device has a filesystem, if not create one
log "Checking filesystem on $DEVICE_NAME..."
if ! blkid "$DEVICE_NAME" > /dev/null 2>&1; then
    log "No filesystem detected on $DEVICE_NAME, creating ext4 filesystem..."
    mkfs -t ext4 "$DEVICE_NAME"
    log "Filesystem created successfully"
else
    log "Existing filesystem detected on $DEVICE_NAME"
fi

# 7. Create mount point if it doesn't exist
if [ ! -d "$MOUNT_PATH" ]; then
    log "Creating mount point: $MOUNT_PATH"
    mkdir -p "$MOUNT_PATH"
fi

# 8. Mount the volume
log "Mounting $DEVICE_NAME to $MOUNT_PATH..."
mount "$DEVICE_NAME" "$MOUNT_PATH"

log "Volume mounted successfully"

# 9. Set proper permissions for Swarm container
log "Setting permissions on $MOUNT_PATH..."
chmod 755 "$MOUNT_PATH"
# Swarm container runs as user 1000 by default
chown -R 1000:1000 "$MOUNT_PATH" || log "Warning: Could not change ownership to 1000:1000, may need to be done by container"

# 10. Add entry to /etc/fstab for automatic mounting on reboot
# Check if entry already exists
if ! grep -q "$DEVICE_NAME" /etc/fstab; then
    log "Adding entry to /etc/fstab for persistent mounting..."
    echo "$DEVICE_NAME $MOUNT_PATH ext4 defaults,nofail 0 2" >> /etc/fstab
    log "fstab entry added"
else
    log "fstab entry already exists"
fi

# 11. Verify mount
if mountpoint -q "$MOUNT_PATH"; then
    log "SUCCESS: $MOUNT_PATH is mounted"
    df -h "$MOUNT_PATH"
else
    log "ERROR: $MOUNT_PATH is not mounted"
    exit 1
fi

log "========================================="
log "P4 Code Review instance setup completed successfully"
log "========================================="
