#!/bin/bash
set -euo pipefail

# =============================================================================
# NVMe Instance Store Setup for Lore ECS
# Formats NVMe instance store (if present) and configures ECS agent.
# Runs before ECS agent starts (cloud-init → multi-user.target ordering).
# =============================================================================

MOUNT_PATH="${mount_path}"
ECS_CLUSTER="${cluster_name}"
CONTAINER_UID="${container_uid}"

# Detect NVMe instance store devices (exclude EBS NVMe volumes)
# Uses /sys/block model file — more reliable than nvme-cli across AMIs
INSTANCE_STORE_DEVICES=()
for device in /dev/nvme*n1; do
  [ -e "$device" ] || continue
  devname=$(basename "$device")
  model=$(cat "/sys/block/$devname/device/model" 2>/dev/null || echo "")
  if [[ "$model" == *"Instance Storage"* ]]; then
    INSTANCE_STORE_DEVICES+=("$device")
  fi
done

# Format and mount (RAID-0 if multiple devices, single device otherwise)
if [ $${#INSTANCE_STORE_DEVICES[@]} -gt 1 ]; then
  dnf install -y mdadm >/dev/null 2>&1 || true
  mdadm --create /dev/md0 --level=0 --raid-devices=$${#INSTANCE_STORE_DEVICES[@]} \
    "$${INSTANCE_STORE_DEVICES[@]}" --force
  mkfs.xfs -f /dev/md0
  mkdir -p "$MOUNT_PATH"
  mount -o noatime,nodiratime,discard /dev/md0 "$MOUNT_PATH"
  RAID_UUID=$(blkid -s UUID -o value /dev/md0)
  echo "UUID=$RAID_UUID $MOUNT_PATH xfs noatime,nodiratime,discard,nofail 0 2" >> /etc/fstab
  chown "$CONTAINER_UID:$CONTAINER_UID" "$MOUNT_PATH"
elif [ $${#INSTANCE_STORE_DEVICES[@]} -eq 1 ]; then
  mkfs.xfs -f "$${INSTANCE_STORE_DEVICES[0]}"
  mkdir -p "$MOUNT_PATH"
  mount -o noatime,nodiratime,discard "$${INSTANCE_STORE_DEVICES[0]}" "$MOUNT_PATH"
  DEV_UUID=$(blkid -s UUID -o value "$${INSTANCE_STORE_DEVICES[0]}")
  echo "UUID=$DEV_UUID $MOUNT_PATH xfs noatime,nodiratime,discard,nofail 0 2" >> /etc/fstab
  chown "$CONTAINER_UID:$CONTAINER_UID" "$MOUNT_PATH"
else
  mkdir -p "$MOUNT_PATH"
  chown "$CONTAINER_UID:$CONTAINER_UID" "$MOUNT_PATH"
  echo "WARNING: No NVMe instance store found. Using root volume at $MOUNT_PATH"
fi

# Configure ECS agent
cat >> /etc/ecs/ecs.config <<EOF
ECS_CLUSTER=$ECS_CLUSTER
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_ENI=true
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
EOF
