#!/usr/bin/env bash

if lsblk /dev/nvme1n1 ; then
  echo "/dev/nvme1n1 exists"
  if [ $(lsblk --json -fs /dev/nvme1n1 | jq -r ".blockdevices[0].fstype") != "xfs" ] ; then
    echo "/dev/nvme1n1 is NOT xfs - formatting..."
    mkfs -t xfs /dev/nvme1n1
  fi

  if [ $(lsblk --json /dev/nvme1n1 | jq -r "[.blockdevices[0].mountpoints[] | select(. != null)] | length") -eq "0" ] ; then
    echo "/dev/nvme1n1 is not mounted - mounting..."
    mount /dev/nvme1n1 /tmp
    chmod 777 /tmp
  fi
fi
