# ScyllaDB CloudWatch Agent Issue

## Problem
ScyllaDB instances fail to start when centralized logging is enabled due to CloudWatch agent dependency failures.

## Root Cause
When `enable_centralized_logging = true`, the module installs CloudWatch agent on ScyllaDB instances via user data:

```bash
yum install -y amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent
```

This causes systemd dependency failures:
```
systemd[1]: Dependency failed for Scylla Server.
systemd[1]: scylla-server.service: Job scylla-server.service/start failed with result 'dependency'.
```

## Impact
- ScyllaDB service won't start (port 9042 unavailable)
- DDC application pods crash with connection refused errors
- Deployment fails after ~30+ minutes of timeouts

## Solution
Disabled CloudWatch agent installation for ScyllaDB instances only:

**File:** `modules/unreal/unreal-cloud-ddc/modules/ddc-infra/locals.tf`
```hcl
# Line 18: Changed from var.enable_centralized_logging to false
scylla_logging_enabled = false  # Disabled due to CloudWatch agent dependency issues
```

## Result
- ScyllaDB starts successfully without CloudWatch agent
- Other services (EKS, NLB, DDC app) retain centralized logging
- DDC deployment completes successfully

## Future Fix Options

### 1. Delay CloudWatch Agent Startup
Modify user data to configure CloudWatch agent but prevent immediate startup:
```bash
# Install but don't start immediately
yum install -y amazon-cloudwatch-agent
systemctl disable amazon-cloudwatch-agent

# Create systemd override to depend on scylla-server
mkdir -p /etc/systemd/system/amazon-cloudwatch-agent.service.d
cat > /etc/systemd/system/amazon-cloudwatch-agent.service.d/override.conf << EOF
[Unit]
After=scylla-server.service
Requires=scylla-server.service
EOF

systemctl daemon-reload
systemctl enable amazon-cloudwatch-agent
```

### 2. Use Systems Manager Quick Setup
Deploy CloudWatch agent via SSM after instance boot:
- Avoids boot-time dependency conflicts
- Automated through SSM agent
- Better lifecycle management

### 3. Custom Log Collection Script
Replace CloudWatch agent with lightweight log shipper:
```bash
#!/bin/bash
# Simple log shipper that doesn't interfere with systemd
aws logs put-log-events --log-group-name "${log_group}" \
  --log-stream-name "${instance_id}-scylla" \
  --log-events file:///var/log/scylla/scylla.log
```

### 4. Custom AMI (Recommended)
Bake CloudWatch agent into custom ScyllaDB AMI:
- Pre-configure systemd dependencies correctly
- Ensure clean boot every time
- Most robust and repeatable solution
- Handle complex AMI environments properly