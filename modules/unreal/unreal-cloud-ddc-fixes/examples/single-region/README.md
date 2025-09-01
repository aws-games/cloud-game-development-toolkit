# Single Region DDC Deployment Example

This example demonstrates deploying Unreal Cloud DDC in a single AWS region for small to medium-sized game development teams.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Game Devs     │───▶│   Public NLB     │───▶│   EKS Cluster   │
│ (UE Clients)    │    │ ddc.example.com  │    │  DDC Services   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
┌─────────────────┐             │               ┌─────────────────┐
│  Ops/DevOps     │─────────────┼──────────────▶│   ScyllaDB      │
│ (Monitoring)    │             │               │   (Metadata)    │
└─────────────────┘             │               └─────────────────┘
                                │                        │
                       ┌──────────────────┐    ┌─────────────────┐
                       │ Monitoring ALB   │    │   S3 Bucket     │
                       │monitoring.ddc... │    │  (Asset Data)   │
                       └──────────────────┘    └─────────────────┘
```

## When to Use Single Region

### ✅ Ideal Scenarios
- **Small teams** (5-20 developers)
- **Co-located teams** (same geographic region)
- **Prototyping/MVP** projects
- **Budget-conscious** deployments
- **Getting started** with Cloud DDC

### ❌ Not Recommended For
- **Distributed global teams** (use multi-region)
- **Large studios** (50+ developers across regions)
- **Strict disaster recovery** requirements
- **Regulatory compliance** requiring data locality

## DNS and Certificate Architecture

### Domain Structure
```
yourcompany.com (Route53 Hosted Zone)
├── ddc.yourcompany.com (DDC Service - NLB)
└── monitoring.ddc.yourcompany.com (Monitoring - ALB)
```

### Certificate Management
- **Single wildcard certificate**: `*.ddc.yourcompany.com`
- **Covers both services**: DDC and monitoring
- **DNS validation**: Automatic via Route53
- **Managed by parent module**: No certificate creation in example

### Load Balancer Configuration
```hcl
# NLB (DDC Service)
- Port 80: Direct TCP forwarding to EKS
- Port 443: TLS termination with certificate

# ALB (Monitoring)  
- Port 80: HTTP → HTTPS redirect
- Port 443: HTTPS with certificate
```

## User Access Patterns

### DevOps Team (Full Access)
```hcl
# Configure in security.tf
resource "aws_security_group" "devops_team" {
  # EKS API access for kubectl/Terraform
  # DDC service access for testing
  # Monitoring dashboard access
}

# Pass to module
existing_security_groups = [aws_security_group.devops_team.id]
```

**Access Includes:**
- EKS cluster management (kubectl)
- DDC service endpoints
- Monitoring dashboards
- AWS Console/CLI

### Operations Team (Monitoring Only)
```hcl
# Configure monitoring-specific access
ddc_monitoring_config = {
  additional_alb_security_groups = [aws_security_group.ops_team.id]
}
```

**Access Includes:**
- Grafana dashboards
- ScyllaDB monitoring
- CloudWatch metrics
- Alert management

### Game Developers (Service Only)
```hcl
# Configure in security.tf
resource "aws_security_group" "game_developers" {
  # Only DDC service access (ports 80, 443, 8091)
  # No EKS or monitoring access
}

# Pass to module
existing_security_groups = [aws_security_group.game_developers.id]
```

**Access Includes:**
- DDC service endpoints only
- No backend infrastructure access
- Unreal Engine DDC configuration

## Remote Developer Considerations

### Challenge: Dynamic IP Addresses
Remote developers often have changing IP addresses, making static security group rules impractical.

### Solutions

#### Option 1: VPN-Based Access (Recommended)
```hcl
# All developers use company VPN
resource "aws_security_group" "vpn_users" {
  ingress {
    from_port   = 80
    to_port     = 8091
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # VPN network
  }
}

# Configure EKS access for DevOps via VPN
eks_api_access_cidrs = ["10.0.0.0/8"]
```

#### Option 2: Regional Office Networks
```hcl
# Multiple office locations
variable "office_networks" {
  default = [
    "203.0.113.0/24",  # Main Office
    "198.51.100.0/24", # Remote Office
  ]
}

# Configure access
eks_api_access_cidrs = var.office_networks
```

#### Option 3: Dynamic IP Management
```hcl
# Use current IP detection (for development/testing)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# Add to security group
eks_api_access_cidrs = [local.my_ip_cidr]
```

**⚠️ Production Recommendation:** Use VPN or office networks for production deployments.

## Unreal Engine Configuration

### DDC Setup for Single Region

```ini
; DefaultEngine.ini - Add to your project
[InstalledDerivedDataBackendGraph]
; Local cache (fastest, individual)
Local=(Type=FileSystem, ReadOnly=false, Clean=false, Flush=false, PurgeTransient=true, DeleteUnused=true, UnusedFileAge=17, FoldersToClean=-1, Path="%GAMEDIR%DerivedDataCache")

; Cloud DDC (shared, team)
Cloud=(Type=HTTPDerivedDataBackend, Host="https://ddc.yourcompany.com", EngineDDCGraph=Local)

; Hierarchical setup: try Cloud first, fallback to Local
Hierarchy=(Type=Hierarchical, Inner=Cloud, Outer=Local)
```

### Performance Optimization
```ini
; Optional: Adjust cache settings for your team size
[Core.System]
; Increase cache size for better hit rates
MaxDerivedDataCacheSize=10240  ; 10GB cache

; Enable compression for slower connections
[DerivedDataCache]
EnableCompression=true
```

### Team Coordination
```ini
; Shared team configuration
; All developers should use identical DDC settings
; Commit DefaultEngine.ini to version control
; Document any project-specific cache requirements
```

## Deployment Guide

### Prerequisites

1. **AWS Account Setup:**
   - AWS CLI configured with appropriate permissions
   - Route53 hosted zone created
   - Terraform >= 1.0 installed

2. **GitHub Container Registry Access:**
   - Create GitHub personal access token
   - Store in AWS Secrets Manager with prefix `ecr-pullthroughcache/`

3. **Network Planning:**
   - Identify office/VPN IP ranges
   - Plan VPC CIDR blocks
   - Consider future multi-region expansion

### Step 1: Configure Variables

```hcl
# terraform.tfvars
route53_public_hosted_zone_name = "yourcompany.com"
regions = ["us-east-1"]  # Single region

# GitHub credentials for DDC container images
ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/github-credentials"

# Optional: Customize instance types
# scylla_instance_type = "i4i.xlarge"
# kubernetes_version = "1.31"
```

### Step 2: Review Security Configuration

```hcl
# security.tf - Customize for your team
resource "aws_security_group" "allow_my_ip" {
  name_prefix = "ddc-access-"
  vpc_id      = aws_vpc.unreal_cloud_ddc_vpc.id

  # Adjust these rules for your access patterns
  ingress {
    from_port   = 80
    to_port     = 8091
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]  # Replace with VPN/office network
  }
}
```

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs for UE configuration
terraform output endpoints
```

### Step 4: Configure Unreal Engine

```bash
# Get DDC endpoint from Terraform output
DDC_ENDPOINT=$(terraform output -raw endpoints | jq -r '.ddc')

# Update your project's DefaultEngine.ini
echo "[InstalledDerivedDataBackendGraph]" >> Config/DefaultEngine.ini
echo "Cloud=(Type=HTTPDerivedDataBackend, Host=\"$DDC_ENDPOINT\")" >> Config/DefaultEngine.ini
```

### Step 5: Verify Deployment

```bash
# Test DDC connectivity
curl -I https://ddc.yourcompany.com/health

# Check monitoring dashboard
open https://monitoring.ddc.yourcompany.com

# Verify EKS cluster (DevOps only)
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>
kubectl get pods -n unreal-cloud-ddc
```

## Monitoring and Operations

### Health Checks

**DDC Service Health:**
```bash
# Check service status
curl https://ddc.yourcompany.com/health

# Expected response: HTTP 200 OK
```

**ScyllaDB Health:**
```bash
# Access monitoring dashboard
open https://monitoring.ddc.yourcompany.com

# Check cluster status, node health, cache hit rates
```

**EKS Cluster Health:**
```bash
# DevOps team access
kubectl get nodes
kubectl get pods -n unreal-cloud-ddc
kubectl top nodes
```

### Performance Monitoring

**Key Metrics to Monitor:**
- DDC cache hit rate (target: >80%)
- ScyllaDB latency (target: <10ms)
- EKS node utilization (target: <80%)
- Network throughput

**Alerting Setup:**
- Configure CloudWatch alarms
- Set up PagerDuty/Slack notifications
- Monitor certificate expiration
- Track storage usage

### Backup and Recovery

**Automated Backups:**
- S3 bucket versioning enabled
- ScyllaDB snapshots scheduled
- EKS configuration backed up

**Recovery Procedures:**
- Document restore procedures
- Test recovery processes regularly
- Maintain runbooks for common issues

## Cost Optimization

### Single Region Cost Factors

**Major Cost Components:**
1. **EKS Cluster:** ~$73/month (control plane)
2. **EC2 Instances:** Variable based on node types
3. **ScyllaDB Instances:** i4i.xlarge ~$400/month each
4. **Load Balancers:** NLB + ALB ~$40/month
5. **S3 Storage:** Variable based on cache size

**Optimization Strategies:**
```hcl
# Use smaller instances for development
scylla_instance_type = "i4i.large"  # Instead of xlarge

# Reduce node group sizes
nvme_managed_node_desired_size = 1  # Instead of 2
worker_managed_node_desired_size = 0  # Scale to zero when not needed

# Enable cluster autoscaling
system_managed_node_min_size = 0
system_managed_node_max_size = 3
```

### Cost Monitoring
```bash
# Use AWS Cost Explorer
# Tag resources for cost allocation
# Monitor usage patterns
# Right-size instances based on utilization
```

## Scaling to Multi-Region

### When to Consider Multi-Region

**Indicators:**
- Team grows beyond 20-30 developers
- Developers distributed across time zones
- Performance complaints from remote locations
- Disaster recovery requirements

### Migration Path

1. **Deploy secondary region:**
   ```bash
   cd ../multi-region
   # Configure secondary region
   terraform apply
   ```

2. **Update DNS configuration:**
   ```hcl
   # Switch to region-specific endpoints
   us-east-1.ddc.yourcompany.com
   us-west-2.ddc.yourcompany.com
   ```

3. **Update UE configuration:**
   ```ini
   ; Region-specific configuration
   Cloud=(Type=HTTPDerivedDataBackend, Host="https://us-east-1.ddc.yourcompany.com")
   ```

4. **Test and validate:**
   - Verify cross-region replication
   - Test failover scenarios
   - Update monitoring dashboards

## Troubleshooting

### Common Issues

**Certificate Validation Fails:**
```bash
# Check DNS records
dig TXT _validation.ddc.yourcompany.com

# Verify Route53 hosted zone
aws route53 list-hosted-zones
```

**EKS Access Denied:**
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Verify IP address
curl https://checkip.amazonaws.com/

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>
```

**DDC Connection Timeout:**
```bash
# Test NLB connectivity
telnet ddc.yourcompany.com 80

# Check target group health
aws elbv2 describe-target-health --target-group-arn <arn>

# Verify security group rules
```

**ScyllaDB Performance Issues:**
```bash
# Access monitoring dashboard
open https://monitoring.ddc.yourcompany.com

# Check node status, disk usage, memory utilization
# Review slow query logs
# Verify replication factor
```

### Getting Help

**Internal Support:**
1. Check monitoring dashboards
2. Review CloudWatch logs
3. Consult team runbooks

**External Resources:**
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ScyllaDB Documentation](https://docs.scylladb.com/)
- [Unreal Engine DDC Documentation](https://docs.unrealengine.com/5.0/en-US/derived-data-cache/)

## Next Steps

### Production Readiness
- [ ] Implement comprehensive monitoring
- [ ] Set up automated backups
- [ ] Configure disaster recovery procedures
- [ ] Document operational runbooks
- [ ] Train team on DDC usage

### Advanced Features
- [ ] Integrate with CI/CD pipelines
- [ ] Set up automated scaling
- [ ] Implement cost optimization
- [ ] Consider multi-region expansion

### Team Adoption
- [ ] Train developers on UE DDC configuration
- [ ] Establish cache usage guidelines
- [ ] Monitor adoption and performance
- [ ] Gather feedback for improvements