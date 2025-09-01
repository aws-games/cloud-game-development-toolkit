# Amazon Managed Grafana Integration Guide

## Overview

This guide shows how to create a centralized Amazon Managed Grafana (AMG) module and consume logs from the DDC module for monitoring and observability.

## Architecture

```
DDC Module → CloudWatch Logs → Amazon Managed Grafana → Dashboards
```

## Prerequisites

- DDC module deployed with `enable_centralized_logging = true`
- AWS CLI configured with appropriate permissions
- Terraform >= 1.11

## Step 1: Create AMG Module Structure

### Directory Structure
```
modules/
└── monitoring/
    └── amazon-managed-grafana/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── versions.tf
        ├── iam.tf
        ├── README.md
        └── examples/
            └── single-region/
                ├── main.tf
                ├── variables.tf
                ├── outputs.tf
                └── versions.tf
```

## Step 2: AMG Module Implementation

### main.tf
```hcl
# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "main" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  data_sources            = ["CLOUDWATCH"]
  
  name        = var.workspace_name
  description = var.workspace_description
  
  # Notification channels
  notification_destinations = var.notification_destinations
  
  # Network access control
  network_access_control {
    prefix_list_ids = var.allowed_prefix_lists
    vpce_ids       = var.vpc_endpoint_ids
  }
  
  tags = var.tags
}

# IAM role for Grafana to access CloudWatch
resource "aws_grafana_role_association" "cloudwatch" {
  role         = "ADMIN"
  user_ids     = var.admin_user_ids
  workspace_id = aws_grafana_workspace.main.id
}
```

### variables.tf
```hcl
variable "workspace_name" {
  type        = string
  description = "Name for the Grafana workspace"
}

variable "workspace_description" {
  type        = string
  description = "Description for the Grafana workspace"
  default     = "Centralized monitoring for CGD Toolkit services"
}

variable "admin_user_ids" {
  type        = list(string)
  description = "List of AWS SSO user IDs to grant admin access"
}

variable "notification_destinations" {
  type        = list(string)
  description = "SNS topic ARNs for notifications"
  default     = ["SNS"]
}

variable "allowed_prefix_lists" {
  type        = list(string)
  description = "Prefix list IDs for network access control"
  default     = []
}

variable "vpc_endpoint_ids" {
  type        = list(string)
  description = "VPC endpoint IDs for private access"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
```

### iam.tf
```hcl
# Service-linked role for Grafana to access CloudWatch
data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "grafana_cloudwatch" {
  name               = "${var.workspace_name}-grafana-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json
  
  tags = var.tags
}

# Policy for CloudWatch access
data "aws_iam_policy_document" "grafana_cloudwatch_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:DescribeQueries"
    ]
    
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData"
    ]
    
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name   = "${var.workspace_name}-grafana-cloudwatch-policy"
  role   = aws_iam_role.grafana_cloudwatch.id
  policy = data.aws_iam_policy_document.grafana_cloudwatch_policy.json
}
```

## Step 3: Example Implementation

### examples/single-region/main.tf
```hcl
module "amazon_managed_grafana" {
  source = "../../"
  
  workspace_name        = "cgd-monitoring-${var.environment}"
  workspace_description = "Centralized monitoring for CGD Toolkit - ${var.environment}"
  
  admin_user_ids = var.grafana_admin_user_ids
  
  tags = {
    Environment = var.environment
    Project     = "cgd-toolkit"
    Service     = "monitoring"
  }
}

# Data source to get DDC log groups
data "aws_cloudwatch_log_groups" "ddc_logs" {
  log_group_name_prefix = "cgd-unreal-cloud-ddc-${var.region}"
}
```

## Step 4: Consuming DDC Logs in Grafana

### Log Group Locations
```
DDC Application Logs:    cgd-unreal-cloud-ddc-us-east-1/application/ddc
ScyllaDB Logs:          cgd-unreal-cloud-ddc-us-east-1/service/scylla  
NLB Access Logs:        cgd-unreal-cloud-ddc-us-east-1/infrastructure/nlb
ALB Access Logs:        cgd-unreal-cloud-ddc-us-east-1/infrastructure/alb
EKS Control Plane:      /aws/eks/cgd-unreal-cloud-ddc-cluster-us-east-1/cluster
```

### Sample Grafana Queries

#### DDC Application Errors
```
fields @timestamp, @message
| filter @message like /ERROR/
| filter @logGroup like /cgd-unreal-cloud-ddc.*\/application\/ddc/
| sort @timestamp desc
| limit 100
```

#### ScyllaDB Performance
```
fields @timestamp, @message
| filter @logGroup like /cgd-unreal-cloud-ddc.*\/service\/scylla/
| filter @message like /query/
| stats count() by bin(5m)
```

#### NLB Connection Patterns
```
fields @timestamp, @message
| filter @logGroup like /cgd-unreal-cloud-ddc.*\/infrastructure\/nlb/
| parse @message /(?<client_ip>\d+\.\d+\.\d+\.\d+)/
| stats count() by client_ip
| sort count desc
```

#### EKS Control Plane Issues
```
fields @timestamp, @message
| filter @logGroup = "/aws/eks/cgd-unreal-cloud-ddc-cluster-us-east-1/cluster"
| filter @message like /ERROR/ or @message like /WARN/
| sort @timestamp desc
```

## Step 5: Dashboard Templates

### DDC Overview Dashboard
```json
{
  "dashboard": {
    "title": "DDC Service Overview",
    "panels": [
      {
        "title": "DDC Application Errors",
        "type": "logs",
        "targets": [
          {
            "expression": "fields @timestamp, @message | filter @message like /ERROR/ | filter @logGroup like /cgd-unreal-cloud-ddc.*\\/application\\/ddc/",
            "logGroups": ["cgd-unreal-cloud-ddc-us-east-1/application/ddc"]
          }
        ]
      },
      {
        "title": "Request Rate",
        "type": "stat",
        "targets": [
          {
            "expression": "fields @timestamp | filter @logGroup like /cgd-unreal-cloud-ddc.*\\/application\\/ddc/ | stats count() by bin(1m)",
            "logGroups": ["cgd-unreal-cloud-ddc-us-east-1/application/ddc"]
          }
        ]
      }
    ]
  }
}
```

## Step 6: Deployment Steps

### 1. Deploy AMG Module
```bash
cd examples/single-region
terraform init
terraform plan -var="grafana_admin_user_ids=[\"user-123\", \"user-456\"]"
terraform apply
```

### 2. Access Grafana Workspace
```bash
# Get workspace URL
terraform output grafana_workspace_url

# Access via AWS Console or direct URL
# Login with AWS SSO credentials
```

### 3. Configure Data Sources
1. Navigate to Configuration → Data Sources
2. CloudWatch should be pre-configured
3. Test connection to ensure proper permissions

### 4. Import Dashboard Templates
1. Navigate to + → Import
2. Upload dashboard JSON or use dashboard ID
3. Configure log group variables

## Step 7: Advanced Configuration

### Multi-Region Setup
```hcl
# Query logs from multiple regions
locals {
  log_groups = [
    "cgd-unreal-cloud-ddc-us-east-1/application/ddc",
    "cgd-unreal-cloud-ddc-us-west-2/application/ddc"
  ]
}
```

### Alerting Rules
```hcl
resource "aws_grafana_workspace_api_key" "alerts" {
  key_name        = "alerts-api-key"
  key_role        = "EDITOR"
  seconds_to_live = 3600
  workspace_id    = aws_grafana_workspace.main.id
}
```

### Custom Metrics
```
# Create custom metrics from logs
fields @timestamp, @message
| filter @message like /cache_hit/
| stats count() as cache_hits by bin(5m)
```

## Step 8: Cost Optimization

### Log Retention Strategy
- **Application logs**: 30 days (frequent debugging)
- **Infrastructure logs**: 90 days (compliance)
- **Service logs**: 60 days (performance analysis)

### Query Optimization
- Use specific time ranges
- Filter early in queries
- Limit result sets
- Use sampling for high-volume logs

## Step 9: Security Best Practices

### Network Security
```hcl
network_access_control {
  prefix_list_ids = [aws_ec2_managed_prefix_list.office_ips.id]
  vpce_ids       = [aws_vpc_endpoint.grafana.id]
}
```

### IAM Permissions
- Use least privilege access
- Separate read-only and admin roles
- Regular access reviews

### User Management with IAM Identity Center

For automated user and group management, use the official AWS IAM Identity Center Terraform module:

```hcl
# IAM Identity Center setup
module "iam_identity_center" {
  source = "aws-ia/iam-identity-center/aws"
  version = "~> 0.3.0"
  
  # Create groups for different access levels
  sso_groups = {
    grafana_admins = {
      group_name        = "GrafanaAdmins"
      group_description = "Full Grafana workspace administration"
    }
    grafana_editors = {
      group_name        = "GrafanaEditors"
      group_description = "Grafana dashboard editors"
    }
    grafana_viewers = {
      group_name        = "GrafanaViewers"
      group_description = "Read-only Grafana access"
    }
  }
  
  # Create users
  sso_users = {
    admin_user = {
      group_membership = ["GrafanaAdmins"]
      user_name        = "grafana.admin"
      given_name       = "Grafana"
      family_name      = "Administrator"
      display_name     = "Grafana Admin"
      email            = "admin@yourcompany.com"
    }
    dev_user = {
      group_membership = ["GrafanaEditors"]
      user_name        = "dev.user"
      given_name       = "Developer"
      family_name      = "User"
      display_name     = "Dev User"
      email            = "dev@yourcompany.com"
    }
  }
}

# Use the created users in Grafana role associations
resource "aws_grafana_role_association" "admins" {
  role         = "ADMIN"
  user_ids     = [module.iam_identity_center.sso_users["admin_user"].user_id]
  workspace_id = aws_grafana_workspace.main.id
}

resource "aws_grafana_role_association" "editors" {
  role         = "EDITOR"
  user_ids     = [module.iam_identity_center.sso_users["dev_user"].user_id]
  workspace_id = aws_grafana_workspace.main.id
}
```

**Module Reference**: [AWS IAM Identity Center Terraform Module](https://registry.terraform.io/modules/aws-ia/iam-identity-center/aws/latest)

**Benefits**:
- **Automated user provisioning** - Create users and groups via Terraform
- **Group-based access** - Organize users by role (admin, editor, viewer)
- **Consistent permissions** - Standardized access patterns
- **Integration ready** - Works seamlessly with Grafana role associations

## Troubleshooting

### Common Issues

#### No Data in Grafana
1. Check CloudWatch permissions
2. Verify log group names
3. Confirm time range settings
4. Test CloudWatch Logs Insights directly

#### Permission Errors
1. Verify IAM role associations
2. Check service-linked role permissions
3. Confirm workspace data source configuration

#### Query Performance
1. Add time range filters
2. Use specific log group filters
3. Limit result sets
4. Consider log sampling

## Next Steps

1. **Deploy AMG module** with DDC integration
2. **Create custom dashboards** for your use cases
3. **Set up alerting** for critical metrics
4. **Implement log sampling** for high-volume environments
5. **Add more data sources** (Prometheus, X-Ray, etc.)
6. **Configure custom domain** (optional - external to module)

## Step 10: Custom Domain Configuration (Optional)

### Overview
Amazon Managed Grafana supports custom domains for branded access URLs instead of the default AWS-generated URL.

### Supported Domain Types

#### External Domains
```
monitoring.cgd.yourdomain.com     # Public domain
dashboards.yourstudio.com         # Studio-branded domain
grafana.yourcompany.io            # Company domain
```

#### Internal Domains
```
monitoring.cgd.yourdomain.internal # Private internal domain
grafana.corp.internal              # Corporate internal domain
dashboards.local                   # Local network domain
```

### Prerequisites
- **Domain ownership** - You must own/control the domain
- **SSL certificate** - Valid certificate in AWS Certificate Manager
- **DNS management** - Ability to create CNAME records

### Implementation Steps

#### 1. Request SSL Certificate
```bash
# For external domains (public validation)
aws acm request-certificate \
  --domain-name monitoring.cgd.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# For internal domains (DNS validation)
aws acm request-certificate \
  --domain-name monitoring.cgd.yourdomain.internal \
  --validation-method DNS \
  --region us-east-1
```

#### 2. Configure Custom Domain (AWS Console)
1. Navigate to Amazon Managed Grafana console
2. Select your workspace
3. Go to "Network access" tab
4. Click "Configure custom domain"
5. Enter domain name and select certificate
6. Save configuration

#### 3. Update DNS Records

**External Domain (Route 53 Public Zone):**
```hcl
resource "aws_route53_record" "grafana_custom" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "monitoring.cgd.yourdomain.com"
  type    = "CNAME"
  ttl     = 300
  records = ["g-abc123def456.grafana-workspace.us-east-1.amazonaws.com"]
}
```

**Internal Domain (Route 53 Private Zone):**
```hcl
resource "aws_route53_record" "grafana_internal" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "monitoring.cgd.yourdomain.internal"
  type    = "CNAME"
  ttl     = 300
  records = ["g-abc123def456.grafana-workspace.us-east-1.amazonaws.com"]
}
```

**Note**: Custom domain configuration is performed outside the AMG module through AWS Console or separate Terraform resources, as it requires domain ownership verification and certificate management.

## Cost Estimation

### Amazon Managed Grafana
- **Workspace**: ~$9/month per active user
- **Data source queries**: Included
- **Dashboard storage**: Included

### CloudWatch Logs
- **Ingestion**: $0.50 per GB
- **Storage**: $0.03 per GB/month
- **Queries**: $0.005 per GB scanned

### Total Estimated Cost
- **Small deployment**: $50-100/month
- **Medium deployment**: $200-500/month
- **Large deployment**: $1000+/month