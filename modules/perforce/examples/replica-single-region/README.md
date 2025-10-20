# Perforce Single-Region Replica Example

This example demonstrates how to deploy a Perforce server with replicas in the same AWS region for high availability and load distribution.

## Architecture

- **Primary P4 Server**: `perforce.yourdomain.com` (AZ 1a)
- **Standby Replica**: `standby.perforce.yourdomain.com` (AZ 1b) - Can be promoted to primary
- **Read-only Replica**: `ci.perforce.yourdomain.com` (AZ 1c) - For CI/CD systems

## Benefits

- **High Availability**: Survive single AZ failures
- **Load Distribution**: Spread read operations across replicas
- **CI/CD Optimization**: Dedicated replica for build systems
- **Zero Downtime Maintenance**: Promote standby during primary maintenance

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

## Replica Types

- **Standby**: Full replica that can be promoted to primary during failover
- **Read-only**: Optimized for read operations, perfect for CI/CD systems

## Failover Process

To promote the standby replica to primary:

1. Stop the primary server
2. SSH to the standby replica instance
3. Run: `p4d -r /p4/1 -p 1666 -d -J off`
4. Update DNS to point primary FQDN to standby IP

## Cleanup

```bash
terraform destroy
```