# Perforce Multi-AZ Replica Example

This example demonstrates how to deploy a Perforce server with replicas across multiple availability zones for high availability and load distribution.

## Architecture

- **Primary P4 Server**: `perforce.yourdomain.com` (AZ 1a)
- **Standby Replica**: `standby.perforce.yourdomain.com` (AZ 1b) - Standby replica for HA
- **Read-only Replica**: `ci.perforce.yourdomain.com` (AZ 1c) - Read-only replica for CI/CD

## Benefits

- **High Availability**: Survive single AZ failures within region
- **Load Distribution**: Spread read operations across replicas
- **CI/CD Optimization**: Dedicated replica for build systems
- **Zero Downtime Maintenance**: Promote standby during primary maintenance

## Prerequisites

1. AWS credentials configured for multiple regions
2. Route53 hosted zone for your domain
3. Sufficient service limits in all target regions

## Usage

1. Set your Route53 hosted zone:
   ```bash
   export TF_VAR_route53_public_hosted_zone_name="yourdomain.com"
   ```

2. Deploy the infrastructure:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Access your Perforce servers:
   - Primary: `perforce.yourdomain.com:1666`
   - Standby: `standby.perforce.yourdomain.com:1666`
   - CI/Build: `ci.perforce.yourdomain.com:1666`

## Multi-AZ Configuration

### Replica Types
- **Standby**: Full replica that can be promoted to primary during failover
- **Read-only**: Optimized for read operations, perfect for CI/CD systems

### Health Checks
- Route53 health checks monitor replica availability
- Automatic DNS failover for high availability

## Failover Process

### Promote Standby Replica
1. Stop primary server
2. SSH to standby replica instance
3. Run: `p4d -r /p4/1 -p 1666 -d -J off`
4. Update DNS to point primary FQDN to standby IP

## Network Requirements

### Security Groups
- P4 replication traffic within VPC (port 1666)
- SSH access (port 22) from your IP
- HTTP/HTTPS for web services

## Monitoring

- CloudWatch metrics for all instances
- Route53 health checks for replica availability
- Cross-region replication lag monitoring

## Cleanup

```bash
terraform destroy
```

**Note**: Multi-AZ resources will be destroyed in dependency order.