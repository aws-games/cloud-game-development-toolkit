# Local-Only Example

## Overview
Demonstrates VDI deployment with local Windows users and Secrets Manager authentication. No Active Directory complexity.

## Prerequisites
1. AWS credentials configured
2. VPC and subnet for deployment

## Deployment
```bash
terraform init
terraform apply
```

## What Gets Created
- **Local User**: john-doe (Windows local account)
- **VDI Instance**: Single workstation with software packages
- **Authentication**: Secrets Manager with 3 accounts per VDI:
  - Administrator (EC2 key pair - break-glass)
  - VDIAdmin (Secrets Manager - automation)
  - john-doe (Secrets Manager - daily use)

## Connection

### Method 1: Secrets Manager (Recommended)
```bash
# Get secret ARN
SECRET_ARN=$(terraform output -raw secrets_manager | jq -r '."vdi-001".secret_arn')

# Get passwords
aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text | jq
```

### Method 2: EC2 Key Pair (Break-glass)
```bash
# Get private key
terraform output -raw private_keys | jq -r '."vdi-001"' > temp_key.pem
chmod 600 temp_key.pem

# Get Administrator password
INSTANCE_ID=$(terraform output -raw vdi_connection_info | jq -r '."vdi-001".instance_id')
aws ec2 get-password-data --instance-id $INSTANCE_ID --priv-launch-key temp_key.pem
```

### Connect via DCV
1. Get instance IP: `terraform output vdi_connection_info`
2. Open browser: `https://<instance-ip>:8443`
3. Login with retrieved credentials

## Software Packages
- Chocolatey (package manager)
- Visual Studio 2022 Community
- Git
- Perforce client tools

Check installation progress via CloudWatch logs or SSM status commands in outputs.