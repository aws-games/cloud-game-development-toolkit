#!/bin/bash

echo "Setting up Packer variables..."

# Create a Packer variables file
cat << EOF > ci.pkrvars.hcl
region = "${AWS_REGION}"
vpc_id = "${AWS_VPC_ID}"
subnet_id = "${AWS_SUBNET_ID}"
profile = "${AWS_PROFILE}"
public_key = "${PUBLIC_KEY}"
EOF
