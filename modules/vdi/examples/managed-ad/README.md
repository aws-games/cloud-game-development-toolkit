# Managed AD Example

## Overview
Demonstrates VDI deployment with AWS Managed Active Directory integration, including AD users, groups, and domain joining.

## Prerequisites
1. AWS credentials configured
2. VPC with at least 2 subnets in different AZs (for Managed AD)

## Deployment

### Option 1: Set AD Admin Password in Code
```hcl
# In main.tf, replace placeholder:
ad_admin_password = "your-secure-password-here"
```

### Option 2: Set AD Admin Password After Deployment
```bash
# Deploy without AD admin password
terraform apply

# Get directory ID from outputs
DIRECTORY_ID=$(terraform output -raw active_directory | jq -r '.directory_id')

# Set admin password via AWS CLI
aws ds reset-user-password \
  --directory-id $DIRECTORY_ID \
  --user-name Admin \
  --new-password "YourSecurePassword123!"
```

## What Gets Created
- **AWS Managed AD**: `cgd.internal` domain
- **AD Users**: jane-smith, bob-jones
- **AD Groups**: developers, leads
- **VDI Instances**: 2 workstations with domain joining
- **Authentication**: AD-managed passwords with automatic rotation

## Connection
1. Get instance IPs: `terraform output vdi_connection_info`
2. Connect via DCV: `https://<instance-ip>:8443`
3. Login with AD credentials: `DOMAIN\username`

## Security Notes
- Always use strong passwords for AD admin
- Change default passwords immediately after deployment
- Consider using AWS Secrets Manager for password storage