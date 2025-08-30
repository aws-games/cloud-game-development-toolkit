# Unreal Cloud DDC Single Region Example

This example demonstrates how to deploy **[Unreal Cloud DDC](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)** in a single AWS region using the unified Terraform module.

## Architecture

![unreal-cloud-ddc-single-region](../../modules/applications/assets/media/diagrams/unreal-cloud-ddc-single-region.png)

## Connectivity Overview

**📖 For comprehensive connectivity and deployment guidance, see the [main module README](../../README.md#connectivity--deployment-guide).**

This example demonstrates **Scenario 1: External Access** deployment with:

- **EKS public and private access** enabled (default configuration)
- **Security groups** restricting access to specified IP ranges
- **Public load balancers** for DDC API and monitoring access
- **Private services** (EKS pods, ScyllaDB) in private subnets

## Important

### Key Configuration Requirements

#### Provider Configuration

This example uses the unified module. **All provider aliases must be defined** even for single-region:

```hcl
providers = {
  aws.primary        = aws
  aws.secondary      = aws          # Required but unused
  awscc.primary      = awscc
  awscc.secondary    = awscc        # Required but unused
  kubernetes.primary = kubernetes   # Must be configured with EKS endpoint
  kubernetes.secondary = kubernetes # Required but unused
  helm.primary       = helm         # Must be configured with EKS endpoint
  helm.secondary     = helm         # Required but unused
}
```

**Critical:** The Kubernetes and Helm providers must be configured with EKS cluster connection details:

```hcl
provider "kubernetes" {
  host                   = module.unreal_cloud_ddc.primary_region.eks_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.primary_region.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.primary_region.eks_cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.unreal_cloud_ddc.primary_region.eks_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.primary_region.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.primary_region.eks_cluster_name]
    }
  }
}
```

#### EKS Access Configuration

**Required for external access:** Configure EKS endpoint access for your deployment scenario:

```hcl
# Get your public IP for external access
data "http" "public_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Configure EKS access in infrastructure_config
infrastructure_config = {
  # Default: both endpoints enabled for maximum flexibility
  eks_cluster_public_access = true   # Allows external Terraform, CI/CD, kubectl
  eks_cluster_private_access = true  # Allows VPC-based access
  eks_cluster_public_endpoint_access_cidr = ["${chomp(data.http.public_ip.response_body)}/32"]
  # ... other config
}
```

**For private-only deployments (VPN/CodeBuild):**

```hcl
infrastructure_config = {
  eks_cluster_public_access = false  # Disable public access
  eks_cluster_private_access = true  # Keep private access
  eks_cluster_public_endpoint_access_cidr = []  # No public IPs
  # ... other config
}
```

### Region Configuration

**Important**: The deployment will create resources in the **exact region specified** in the `regions` variable, regardless of your AWS CLI/session default region.

```hcl
regions = {
  primary = { region = "us-east-1" }  # Resources deployed HERE, not your session region
}
```

**Key constraints:**

- Keys must be exactly `"primary"` (cannot use `"main"`, `"east"`, etc.)
- Region string must be explicit (not `data.aws_region.current.name`)
- Your AWS session region does **not** affect where resources are deployed

**⚠️ Avoid using data sources for regions:**

```hcl
# DON'T DO THIS - risky and unpredictable
regions = {
  primary = { region = data.aws_region.current.name }
}

# DO THIS - explicit and safe
regions = {
  primary = { region = "us-east-1" }
}
```

**Why explicit regions are safer:**

- **Predictable**: Always deploys to the same region
- **Team-safe**: Works regardless of individual AWS profile configurations
- **CI/CD-safe**: No dependency on runtime environment
- **Change-safe**: Won't propose region changes when team members have different default regions

### GitHub Credentials Setup

Before deployment, you must create GitHub credentials in AWS Secrets Manager **in the same region** as your deployment (matching your `regions.primary.region` value) to access the Unreal Cloud DDC container image. The secret must be prefixed with `ecr-pullthroughcache/` and follow the naming pattern `ecr-pullthroughcache/{project_prefix}-{name}-github-credentials`.

Example secret name: `ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials`

Secret format:

```json
{
  "username": "GITHUB-USER-NAME",
  "accessToken": "GITHUB-ACCESS-TOKEN"
}
```

### Deployment Time

The deployment takes approximately 30 minutes, with EKS cluster and node group creation requiring around 20 minutes.

### Post-Deployment

The example deploys Route53 DNS records for accessing your Unreal DDC services:

- **DDC Service**: `ddc.<your-domain>` - Main DDC API endpoint
- **Monitoring**: `monitoring.ddc.<your-domain>` - ScyllaDB monitoring dashboard

Where `<your-domain>` is the value you provided for `route53_public_hosted_zone_name`.

**DNS Record Locations:**

- **Public Records**: All DNS records are created in your existing **public hosted zone**
- **Private Zone**: The module also creates a private hosted zone for internal service discovery

These records point to load balancers which may take additional time to become fully available after deployment completes. You can view the provisioning status in the EC2 Load Balancing console.

The Unreal Cloud DDC module creates a Service Account and valid bearer token for testing. This bearer token is stored in AWS Secrets Manager.

### Post-Deployment Testing

#### Quick Sanity Check

After deployment, test your setup using the provided sanity check script:

```bash
cd assets/scripts
./sanity_check.sh
```

This script automatically tests the DDC API by putting and getting test data.

#### Manual Testing

To manually validate you can put an object:

```bash
curl http://<unreal_ddc_url>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H 'Authorization: ServiceAccount <secret-manager-token>'
```

#### Comprehensive Testing

For comprehensive testing, use the [benchmarking tools](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Benchmarks) with an x2idn.32xlarge instance:

```bash
docker run --network host jupiter_benchmark --seed --seed-remote --host http://<unreal_ddc_url> --namespace ddc \
--header="Authorization: ServiceAccount <unreal-cloud-ddc-bearer-token>" all
```

**Note**: Specify the namespace as `ddc` since the token only has access to that namespace.

### Monitoring

The deployment includes a ScyllaDB monitoring stack with Prometheus, Alertmanager, and Grafana for real-time insights into database performance. Access the Grafana dashboard using the `monitoring_url` provided in the Terraform outputs. For more information, see the [ScyllaDB Monitoring Stack Documentation](https://monitoring.docs.scylladb.com/branch-4.10/intro.html).

### Security Group Access Control

This example demonstrates flexible security group patterns for controlling access to different DDC components:

#### Simple Pattern (Current Example)

```hcl
# Get IP once, use everywhere
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Create security group with rules
resource "aws_security_group" "allow_my_ip" {
  name = "allow_my_ip"
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_my_ip.id
  cidr_ipv4 = "${chomp(data.http.my_ip.response_body)}/32"
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
}

# Use same IP for EKS API access
ddc_infra_config = {
  eks_api_access_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]
}
```

#### Multi-Team Access Pattern

```hcl
locals {
  access_cidrs = {
    devops = {
      hq_office = "203.0.113.0/24"
      vpn_range = "10.0.0.0/8"
    }
    game_devs = {
      studio_a = "198.51.100.0/24"
      studio_b = "192.0.2.0/24"
    }
  }

  devops_cidrs = values(local.access_cidrs.devops)
  game_dev_cidrs = values(local.access_cidrs.game_devs)
}

# DevOps security group (EKS + Monitoring access)
resource "aws_security_group" "devops_access" {
  name = "devops-access"
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "devops_https" {
  for_each = toset(local.devops_cidrs)
  security_group_id = aws_security_group.devops_access.id
  cidr_ipv4 = each.value
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
}

# Game developers security group (DDC access only)
resource "aws_security_group" "game_dev_access" {
  name = "game-dev-access"
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "game_dev_ddc" {
  for_each = toset(local.game_dev_cidrs)
  security_group_id = aws_security_group.game_dev_access.id
  cidr_ipv4 = each.value
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

module "unreal_cloud_ddc" {
  existing_security_groups = [aws_security_group.devops_access.id]  # Global DevOps access

  ddc_infra_config = {
    eks_api_access_cidrs = local.devops_cidrs  # Only DevOps can kubectl
    additional_nlb_security_groups = [aws_security_group.game_dev_access.id]  # Game devs can use DDC
  }

  ddc_monitoring_config = {
    # Only DevOps can see monitoring (no additional_alb_security_groups)
  }
}
```

### Production Recommendations

**It is recommended that for production use you change the authentication mode from Service Account to Bearer and use an IDP for authentication with TLS termination.**

<!-- BEGIN_TF_DOCS -->
