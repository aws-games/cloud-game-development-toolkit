# Steps to Add Complete Logging Support

## Current Status ✅

**Already Implemented:**
- ✅ S3 bucket with proper permissions
- ✅ CloudWatch Log Groups with per-category retention
- ✅ NLB access logs configuration
- ✅ IAM permissions for ScyllaDB CloudWatch Agent

## Remaining Tasks

### 1. EKS Control Plane Logs
**Complexity: Easy** 🟢  
**Time: 15 minutes**

#### What It Does
Enables Kubernetes API server, scheduler, and controller manager logs.

#### Implementation
**File:** `modules/ddc-infra/eks.tf`

```hcl
resource "aws_eks_cluster" "unreal_cloud_ddc_cluster" {
  # ... existing configuration ...
  
  # Add this block
  enabled_cluster_log_types = var.enable_centralized_logging ? [
    "api",
    "audit", 
    "authenticator",
    "controllerManager",
    "scheduler"
  ] : []
}
```

#### Notes
- Logs go to AWS-managed log group: `/aws/eks/{cluster-name}/cluster`
- Cannot redirect to custom log groups
- Will incur additional CloudWatch costs

---

### 2. ScyllaDB CloudWatch Agent
**Complexity: Medium** 🟡  
**Time: 1-2 hours**

#### What It Does
Collects ScyllaDB application logs from EC2 instances and ships to CloudWatch.

#### Implementation

**Step 2.1: Create CloudWatch Agent Configuration**
**File:** `modules/ddc-infra/scylla.tf`

```hcl
# CloudWatch Agent configuration for ScyllaDB
resource "aws_ssm_parameter" "scylla_cloudwatch_config" {
  count = var.enable_centralized_logging ? 1 : 0
  name  = "/cgd/${local.name_prefix}/scylla/cloudwatch-agent-config"
  type  = "String"
  
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user = "cwagent"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path        = "/var/log/scylla/scylla.log"
              log_group_name   = "${local.name_prefix}/service/scylla"
              log_stream_name  = "{instance_id}/scylla.log"
              timezone         = "UTC"
            },
            {
              file_path        = "/var/log/scylla/scylla-jmx.log"
              log_group_name   = "${local.name_prefix}/service/scylla"
              log_stream_name  = "{instance_id}/scylla-jmx.log"
              timezone         = "UTC"
            }
          ]
        }
      }
    }
  })
  
  tags = var.tags
}
```

**Step 2.2: Update ScyllaDB User Data**
**File:** `modules/ddc-infra/scylla.tf`

```hcl
locals {
  scylla_user_data_primary_node = base64encode(templatefile("${path.module}/templates/scylla-userdata.sh", {
    # ... existing variables ...
    enable_cloudwatch_agent = var.enable_centralized_logging
    cloudwatch_config_param = var.enable_centralized_logging ? aws_ssm_parameter.scylla_cloudwatch_config[0].name : ""
  }))
}
```

**Step 2.3: Create User Data Template**
**File:** `modules/ddc-infra/templates/scylla-userdata.sh`

```bash
#!/bin/bash
# ... existing ScyllaDB setup ...

%{ if enable_cloudwatch_agent }
# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:${cloudwatch_config_param}
%{ endif }
```

#### Testing
```bash
# SSH to ScyllaDB instance
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

# Check CloudWatch Log Group
aws logs describe-log-streams --log-group-name "cgd-unreal-cloud-ddc/service/scylla"
```

---

### 3. DDC Container Logs (Fluent Bit)
**Complexity: Hard** 🔴  
**Time: 3-4 hours**

#### What It Does
Collects DDC application logs from Kubernetes containers and ships to CloudWatch.

#### Implementation

**Step 3.1: Add Fluent Bit to EKS Blueprints**
**File:** `modules/ddc-services/main.tf`

```hcl
module "eks_blueprints_addons" {
  # ... existing configuration ...
  
  aws_for_fluentbit = var.enable_centralized_logging ? {
    enable = true
    values = [templatefile("${path.module}/templates/fluent-bit-values.yaml", {
      log_group_name = "${local.name_prefix}/application/ddc"
      cluster_name   = var.cluster_name
      region         = var.region
    })]
  } : {}
}
```

**Step 3.2: Create Fluent Bit Configuration**
**File:** `modules/ddc-services/templates/fluent-bit-values.yaml`

```yaml
cloudWatchLogs:
  enabled: true
  region: ${region}
  logGroupName: ${log_group_name}
  logStreamPrefix: "ddc-"

input:
  enabled: true
  tag: "kube.*"
  path: "/var/log/containers/*ddc*.log"
  parser: "docker"
  dockerMode: true
  dockerModeFlush: 5

filter:
  enabled: true
  match: "kube.*"
  kubeURL: "https://kubernetes.default.svc:443"
  kubeCAFile: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  kubeTokenFile: "/var/run/secrets/kubernetes.io/serviceaccount/token"

output:
  enabled: true
  match: "*"
  region: ${region}
  logGroupName: ${log_group_name}
  logStreamName: "$kubernetes['pod_name']"
  autoCreateGroup: false
```

**Step 3.3: Update DDC Services Configuration**
**File:** `modules/ddc-services/variables.tf`

```hcl
variable "enable_centralized_logging" {
  type = bool
  description = "Enable centralized logging for DDC services"
  default = true
}

variable "log_group_name" {
  type = string
  description = "CloudWatch log group name for DDC application logs"
}
```

#### Testing
```bash
# Check Fluent Bit pods
kubectl get pods -n amazon-cloudwatch -l app.kubernetes.io/name=aws-for-fluent-bit

# Check DDC pod logs
kubectl logs -n unreal-cloud-ddc deployment/unreal-cloud-ddc

# Check CloudWatch Log Group
aws logs describe-log-streams --log-group-name "cgd-unreal-cloud-ddc/application/ddc"
```

---

### 4. Route 53 DNS Query Logs (Optional)
**Complexity: Easy** 🟢  
**Time: 30 minutes**  
**Cost Impact: HIGH** 💰

#### What It Does
Logs all DNS queries to Route 53 hosted zones.

#### Implementation
**File:** `route53.tf`

```hcl
# DNS Query Logs (expensive - disabled by default)
resource "aws_route53_query_log" "public_zone" {
  count           = var.enable_dns_query_logs ? 1 : 0
  destination_arn = aws_cloudwatch_log_group.dns_queries[0].arn
  hosted_zone_id  = aws_route53_zone.public.zone_id
  
  depends_on = [aws_cloudwatch_log_destination_policy.dns_logs]
}

resource "aws_cloudwatch_log_group" "dns_queries" {
  count             = var.enable_dns_query_logs ? 1 : 0
  name              = "${local.name_prefix}/infrastructure/dns"
  retention_in_days = var.log_retention_by_category.infrastructure
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-dns-query-logs"
    LogType = "Infrastructure"
    Description = "Route 53 DNS query logs - all DNS lookups"
  })
}

# Required for Route 53 to write to CloudWatch
resource "aws_cloudwatch_log_destination_policy" "dns_logs" {
  count            = var.enable_dns_query_logs ? 1 : 0
  destination_name = aws_cloudwatch_log_destination.dns_logs[0].name
  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "route53.amazonaws.com"
      }
      Action = "logs:PutLogEvents"
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}
```

**Add Variable:**
```hcl
variable "enable_dns_query_logs" {
  type = bool
  description = "Enable Route 53 DNS query logging (WARNING: Can be expensive for high-traffic zones)"
  default = false
}
```

#### Cost Warning
```
Example: 1M DNS queries/day = $5/day = $150/month
Popular game: 10M queries/day = $50/day = $1,500/month
```

---

## Implementation Priority

### Phase 1: Low-Hanging Fruit
1. **EKS Control Plane Logs** (15 min) - Easy win
2. **Route 53 DNS Logs** (30 min) - If needed, but watch costs

### Phase 2: Medium Effort
3. **ScyllaDB CloudWatch Agent** (1-2 hours) - Good database visibility

### Phase 3: Complex but Valuable
4. **DDC Container Logs** (3-4 hours) - Most valuable for application debugging

## Testing Strategy

### Validation Checklist
- [ ] S3 bucket receives NLB access logs
- [ ] EKS control plane logs appear in `/aws/eks/{cluster}/cluster`
- [ ] ScyllaDB logs appear in `cgd-unreal-cloud-ddc/service/scylla`
- [ ] DDC container logs appear in `cgd-unreal-cloud-ddc/application/ddc`
- [ ] DNS query logs appear in `cgd-unreal-cloud-ddc/infrastructure/dns` (if enabled)

### Cost Monitoring
```bash
# Monitor CloudWatch costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## Notes

- **Start with Phase 1** for quick wins
- **Monitor costs** especially for DNS query logs
- **Test incrementally** - enable one log source at a time
- **Consider log sampling** for high-volume applications
- **Use CloudWatch Insights** for log analysis and dashboards