# Required SSM Parameters for Testing

## Overview

The DDC module tests require these SSM parameters to be created in the CI AWS account before tests can run.

## Required Parameters

### 1. Route53 Public Hosted Zone Name
```bash
aws ssm put-parameter \
  --name "/cgd-toolkit/tests/unreal-cloud-ddc/route53-public-hosted-zone-name" \
  --value "your-domain.com" \
  --type "String" \
  --description "Public hosted zone name for DDC testing"
```

### 2. GitHub Container Registry Credentials
```bash
aws ssm put-parameter \
  --name "/cgd-toolkit/tests/unreal-cloud-ddc/ghcr-credentials-secret-manager-arn" \
  --value "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/github-abc123" \
  --type "String" \
  --description "ARN of GitHub credentials secret for DDC container access"
```

## Validation

Test parameter existence:
```bash
aws ssm get-parameter --name "/cgd-toolkit/tests/unreal-cloud-ddc/route53-public-hosted-zone-name"
aws ssm get-parameter --name "/cgd-toolkit/tests/unreal-cloud-ddc/ghcr-credentials-secret-manager-arn"
```

## Test Execution

Once parameters are created:
```bash
cd /path/to/unreal-cloud-ddc
terraform init
terraform test
```