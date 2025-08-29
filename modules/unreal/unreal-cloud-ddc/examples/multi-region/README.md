# Unreal Cloud DDC Multi-Region

This example deploys **[Unreal Cloud DDC](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)** across two AWS regions with cross-region replication. The deployment is a comprehensive solution that leverages several AWS services to create a robust and efficient data caching system with high availability and low-latency access for global development teams.

## Architecture

- **Primary Region**: Complete DDC infrastructure with EKS, ScyllaDB, and S3
- **Secondary Region**: Replicated DDC infrastructure for high availability and performance  
- **VPC Peering**: Secure cross-region connectivity between VPCs
- **Cross-Region Replication**: Automatic ScyllaDB data synchronization between regions
- **DNS**: Region-specific DDC endpoints plus centralized monitoring
- **Monitoring**: Single monitoring stack in primary region (monitors both regions)

## DNS Endpoints

After deployment, you'll have access to these endpoints:
- `ddc-primary.<your-domain>` - Primary region DDC service
- `ddc-secondary.<your-domain>` - Secondary region DDC service
- `monitoring.ddc.<your-domain>` - Monitoring dashboard (primary region only)

Where `<your-domain>` is the value you provided for `route53_public_hosted_zone_name`.

**DNS Record Locations:**
- **Public Records**: All user-facing DNS records are created in your existing **public hosted zone**
- **Private Zone**: The module creates a private hosted zone for internal cross-region service discovery

## Important

### Provider Configuration

This example requires separate provider configurations for each region:

```hcl
providers = {
  aws.primary        = aws.primary
  aws.secondary      = aws.secondary
  awscc.primary      = awscc.primary
  awscc.secondary    = awscc.secondary
  kubernetes.primary = kubernetes.primary
  kubernetes.secondary = kubernetes.secondary
  helm.primary       = helm.primary
  helm.secondary     = helm.secondary
}
```

### Region Configuration

**Critical**: The deployment will create resources in the **exact regions specified** in locals.tf:

```hcl
regions = {
  primary = {
    name  = "us-east-1"
    alias = "primary"
  }
  secondary = {
    name  = "us-east-2"
    alias = "secondary"
  }
}
```

### Network Architecture

- **Primary VPC**: `10.0.0.0/16` with public/private subnets
- **Secondary VPC**: `10.1.0.0/16` with public/private subnets
- **VPC Peering**: Enables cross-region ScyllaDB communication
- **Security Groups**: Allow ScyllaDB ports (7000, 7001, 9042) between regions

### GitHub Credentials Setup

Before deployment, create GitHub credentials in AWS Secrets Manager in **both regions**:

Example secret names:
- Primary: `ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials`
- Secondary: `ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials`

Secret format:
```json
{
  "username": "GITHUB-USER-NAME",
  "accessToken": "GITHUB-ACCESS-TOKEN"
}
```

### Deployment Timeline

- **Infrastructure (EKS, VPC, ScyllaDB)**: ~20-25 minutes
- **Helm Charts and Application Deployment**: ~5-10 minutes
- **Total**: ~30 minutes

### Post-Deployment

The example deploys Route53 DNS records for accessing your Unreal DDC services:
- **Primary DDC**: `ddc-primary.<your-domain>` - Primary region DDC API endpoint
- **Secondary DDC**: `ddc-secondary.<your-domain>` - Secondary region DDC API endpoint  
- **Monitoring**: `monitoring.ddc.<your-domain>` - ScyllaDB monitoring dashboard (primary region only)

Where `<your-domain>` is your `route53_public_hosted_zone_name` value.

These records point to load balancers which may take additional time to become fully available after deployment completes. The Unreal Cloud DDC module creates a Service Account and valid bearer token for testing, stored in AWS Secrets Manager.

### Monitoring

The deployment includes a ScyllaDB monitoring stack with Prometheus, Alertmanager, and Grafana deployed in the **primary region only**. This single monitoring instance provides real-time insights into database performance across both regions through cross-region connectivity. Access the Grafana dashboard using the `monitoring_url` provided in the Terraform outputs. For more information, see the [ScyllaDB Monitoring Stack Documentation](https://monitoring.docs.scylladb.com/branch-4.10/intro.html).

### Production Recommendations

**It is recommended that for production use you change the authentication mode from Service Account to Bearer and use an IDP for authentication with TLS termination.**

## Outputs

| Name | Description |
|------|-------------|
| `primary_ddc_url` | Primary region DDC service endpoint |
| `secondary_ddc_url` | Secondary region DDC service endpoint |
| `monitoring_url` | ScyllaDB monitoring dashboard (primary region) |