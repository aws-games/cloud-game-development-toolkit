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

### Security Group Access Control

This example demonstrates region-specific security group patterns for multi-region deployments:

#### Simple Pattern (Current Example)

```hcl
# Get IP once, use in both regions
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Use same IP for both regions
ddc_infra_config = {
  eks_api_access_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]
}
```

#### Multi-Region Access Pattern

```hcl
locals {
  # Different access patterns per region
  region_access = {
    "us-east-1" = {
      devops = ["203.0.113.0/24", "10.0.0.0/8"]      # HQ + VPN
      game_devs = ["198.51.100.0/24"]                 # Primary studio
    }
    "us-west-2" = {
      devops = ["192.0.2.0/24", "10.0.0.0/8"]        # West office + VPN
      game_devs = ["172.16.0.0/16"]                   # West studio
    }
  }

  # Current region access
  current_devops_cidrs = local.region_access[local.region].devops
  current_game_dev_cidrs = local.region_access[local.region].game_devs
}

# Region-specific security groups
resource "aws_security_group" "devops_access" {
  name = "devops-access-${local.region}"
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "devops_access" {
  for_each = toset(local.current_devops_cidrs)
  security_group_id = aws_security_group.devops_access.id
  cidr_ipv4 = each.value
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
}

resource "aws_security_group" "game_dev_access" {
  name = "game-dev-access-${local.region}"
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "game_dev_access" {
  for_each = toset(local.current_game_dev_cidrs)
  security_group_id = aws_security_group.game_dev_access.id
  cidr_ipv4 = each.value
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

module "unreal_cloud_ddc" {
  existing_security_groups = [aws_security_group.devops_access.id]

  ddc_infra_config = {
    eks_api_access_cidrs = local.current_devops_cidrs
    additional_nlb_security_groups = [aws_security_group.game_dev_access.id]
  }

  # Monitoring only in primary region
  ddc_monitoring_config = local.region == "us-east-1" ? {
    # ... monitoring config
  } : null
}
```

### Production Recommendations

**It is recommended that for production use you change the authentication mode from Service Account to Bearer and use an IDP for authentication with TLS termination.**

<!-- BEGIN_TF_DOCS -->
