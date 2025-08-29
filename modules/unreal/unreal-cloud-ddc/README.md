# Unreal Cloud DDC Terraform Module

This module deploys **[Unreal Cloud DDC](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)** infrastructure on AWS, providing a complete derived data cache solution for Unreal Engine projects.

## Features

- **Single module call** deploys complete DDC infrastructure (EKS, ScyllaDB, S3, Load Balancers)
- **Multi-region support** with cross-region replication (maximum 2 regions)
- **Unified provider management** - handles both single and multi-region deployments
- **Automatic dependency management** between infrastructure and applications
- **Built-in monitoring** with ScyllaDB monitoring stack (Prometheus, Grafana, Alertmanager)
- **Security by default** with VPC isolation, IAM roles, and encrypted storage

## Architecture

### Single Region
![unreal-cloud-ddc-single-region](./modules/applications/assets/media/diagrams/unreal-cloud-ddc-single-region.png)

### Multi-Region
- **Primary Region**: Complete DDC infrastructure with EKS, ScyllaDB, and S3
- **Secondary Region**: Replicated infrastructure for high availability
- **VPC Peering**: Secure cross-region connectivity
- **Cross-Region Replication**: Automatic data synchronization
- **DNS**: Region-specific endpoints for optimal routing

## Prerequisites

- **GitHub Credentials**: Access token stored in AWS Secrets Manager (prefixed with `ecr-pullthroughcache/`) to pull Unreal Cloud DDC container images
- **Route53 Hosted Zone**: For DNS records and SSL certificate validation (recommended)
- **VPC Infrastructure**: Existing VPC with public and private subnets
- **AWS CLI**: Configured with appropriate permissions for deployment and testing
- **kubectl**: For post-deployment verification and troubleshooting

**Important**: The module currently supports a maximum of 2 regions (primary and secondary).

### Region Configuration

**Critical**: Resources are deployed to the **exact regions specified** in the `regions` variable, not your AWS CLI default region.

```terraform
# Single-region
regions = {
  primary = { region = "us-east-1" }  # Deploys to us-east-1
}

# Multi-region  
regions = {
  primary   = { region = "us-east-1" }  # Primary cluster in us-east-1
  secondary = { region = "us-east-2" }  # Secondary cluster in us-east-2
}
```

**Requirements:**
- Keys must be exactly `"primary"` and `"secondary"` (fixed by module)
- Region values must be explicit strings (no data sources)
- Your AWS session/profile region does not affect deployment location

**⚠️ Why we recommend explicit regions over data sources:**

While you *could* use `data.aws_region.current.name`, this creates risks:

```terraform
# Risky - depends on runtime environment
regions = {
  primary = { region = data.aws_region.current.name }
}

# Safe - explicit and predictable
regions = {
  primary = { region = "us-east-1" }
}
```

**Problems with data sources:**
- **Team inconsistency**: Different developers' AWS profiles may have different default regions
- **Terraform plan changes**: `terraform plan` may show region changes when run by different team members
- **CI/CD unpredictability**: Pipeline environment may have different default region than development
- **Accidental deployments**: Easy to accidentally deploy to wrong region if AWS profile changes

**Benefits of explicit regions:**
- **Predictable**: Always deploys to the same location
- **Team-safe**: Works consistently across all team members
- **CI/CD-reliable**: No dependency on runtime AWS configuration
- **Change-safe**: No unexpected region changes in Terraform plans

## Examples

For example configurations, please see the [examples](./examples/).

## Usage

### Single Region Deployment

```terraform
module "unreal_cloud_ddc" {
  source = "../../modules/unreal/unreal-cloud-ddc"
  
  providers = {
    aws.primary        = aws
    awscc.primary      = awscc
    kubernetes.primary = kubernetes
    helm.primary       = helm
  }
  
  # VPC Configuration
  vpc_ids = {
    primary = aws_vpc.main.id
  }
  
  # Infrastructure Configuration
  infrastructure_config = {
    name           = "my-game-ddc"
    project_prefix = "cgd"
    environment    = "dev"
    
    # EKS Configuration
    kubernetes_version     = "1.33"
    eks_node_group_subnets = aws_subnet.private[*].id
    
    # ScyllaDB Configuration
    scylla_subnets       = aws_subnet.private[*].id
    scylla_instance_type = "i4i.2xlarge"
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = aws_subnet.public[*].id
  }
  
  # Application Configuration
  application_config = {
    name           = "my-game-ddc"
    project_prefix = "cgd"
    
    # Credentials (must be prefixed with ecr-pullthroughcache/)
    ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/cgd-my-game-ddc-github-credentials"
    
    # Application Settings
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
    unreal_cloud_ddc_version   = "1.2.0"
  }
}
```

### Multi-Region Deployment

```terraform
module "unreal_cloud_ddc" {
  source = "../../modules/unreal/unreal-cloud-ddc"
  
  providers = {
    aws.primary          = aws
    aws.secondary        = aws.us_west_2
    awscc.primary        = awscc
    awscc.secondary      = awscc.us_west_2
    kubernetes.primary   = kubernetes
    kubernetes.secondary = kubernetes.us_west_2
    helm.primary         = helm
    helm.secondary       = helm.us_west_2
  }
  
  # Multi-region Configuration
  regions = {
    primary   = { region = "us-east-1" }
    secondary = { region = "us-west-2" }
  }
  
  # VPC Configuration
  vpc_ids = {
    primary   = aws_vpc.us_east_1.id
    secondary = aws_vpc.us_west_2.id
  }
  
  # Infrastructure Configuration (shared across regions)
  infrastructure_config = {
    name           = "global-game-ddc"
    project_prefix = "cgd"
    environment    = "prod"
    
    # EKS Configuration
    kubernetes_version     = "1.33"
    eks_node_group_subnets = aws_subnet.us_east_1_private[*].id  # Primary region subnets
    
    # ScyllaDB Configuration
    scylla_subnets       = aws_subnet.us_east_1_private[*].id
    scylla_instance_type = "i4i.4xlarge"  # Larger for production
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = aws_subnet.us_east_1_public[*].id
  }
  
  # Application Configuration (shared across regions)
  application_config = {
    name           = "global-game-ddc"
    project_prefix = "cgd"
    
    # Credentials (must be prefixed with ecr-pullthroughcache/)
    ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/cgd-global-game-ddc-github-credentials"
    
    # Application Settings
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
    unreal_cloud_ddc_version   = "1.2.0"
  }
}
```

### Provider Configuration

**Important**: All provider aliases must be defined even for single-region deployments due to the unified module design.

#### Single Region
For single-region, point secondary providers to the same configurations as primary:

```terraform
providers = {
  aws.primary        = aws          # Creates AWS resources
  aws.secondary      = aws          # Required but unused
  awscc.primary      = awscc        # Creates Cloud Control resources
  awscc.secondary    = awscc        # Required but unused
  kubernetes.primary = kubernetes   # Deploys to EKS cluster
  kubernetes.secondary = kubernetes # Required but unused
  helm.primary       = helm         # Installs Helm charts
  helm.secondary     = helm         # Required but unused
}
```

#### Multi-Region
For multi-region, provide separate provider configurations:

```terraform
# Provider mapping: module_alias = your_provider_alias
providers = {
  aws.primary        = aws.primary        # Module expects "aws.primary" -> your "aws.primary" provider
  aws.secondary      = aws.secondary      # Module expects "aws.secondary" -> your "aws.secondary" provider
  awscc.primary      = awscc.primary      # Module expects "awscc.primary" -> your "awscc.primary" provider
  awscc.secondary    = awscc.secondary    # Module expects "awscc.secondary" -> your "awscc.secondary" provider
  kubernetes.primary = kubernetes.primary # Module expects "kubernetes.primary" -> your "kubernetes.primary" provider
  kubernetes.secondary = kubernetes.secondary # Module expects "kubernetes.secondary" -> your "kubernetes.secondary" provider
  helm.primary       = helm.primary       # Module expects "helm.primary" -> your "helm.primary" provider
  helm.secondary     = helm.secondary     # Module expects "helm.secondary" -> your "helm.secondary" provider
}

# Define your providers (aliases can be renamed, but must match the mapping above):
provider "aws" {
  alias  = "primary"                    # This alias name can be changed (e.g., "east")
  region = var.regions.primary.region   # Uses regions variable - references module input
}

provider "aws" {
  alias  = "secondary"                  # This alias name can be changed (e.g., "west")
  region = var.regions.secondary.region # Uses regions variable - references module input
}

# Configure regions in terraform.tfvars (these keys are fixed by the module):
regions = {
  primary   = { region = "us-east-1" }   # Key "primary" is required by module
  secondary = { region = "us-east-2" }   # Key "secondary" is required by module
}

# Resources will be deployed to us-east-1 and us-east-2, regardless of your AWS session region
```

**Naming Constraints:**
- **Left side of providers block**: Fixed by module (cannot change `aws.primary`, `aws.secondary`, etc.)
- **Right side of providers block**: Your choice (can rename `aws.primary` to `aws.east`, etc.)
- **Provider alias names**: Your choice (can be anything, just must match the right side)
- **regions map keys**: Fixed by module (must be `primary` and `secondary`)
- **Region values**: Your choice (any valid AWS regions)

## Configuration Reference

### Infrastructure Config Object

The `infrastructure_config` object configures EKS clusters, ScyllaDB, and load balancers:

```terraform
infrastructure_config = {
  # General
  name           = "unreal-cloud-ddc"  # Resource naming
  project_prefix = "cgd"               # Prefix for all resources
  environment    = "dev"               # Environment tag
  
  # EKS Configuration
  kubernetes_version     = "1.33"                    # Latest supported version
  eks_node_group_subnets = ["subnet-123", "subnet-456"]  # Private subnets recommended
  
  # Node Groups (optional, defaults provided)
  nvme_managed_node_instance_type   = "i3en.large"   # High-performance storage nodes
  worker_managed_node_instance_type = "c5.large"     # DDC worker nodes
  system_managed_node_instance_type = "m5.large"     # System components
  
  # ScyllaDB Configuration
  scylla_subnets       = ["subnet-789", "subnet-012"]  # Private subnets
  scylla_instance_type = "i4i.2xlarge"                 # NVME instance required
  scylla_architecture  = "x86_64"                      # or "arm64"
  
  # Load Balancer (optional)
  create_application_load_balancer             = true
  monitoring_application_load_balancer_subnets = ["subnet-pub1", "subnet-pub2"]
  alb_certificate_arn                          = "arn:aws:acm:..."
}
```

### Application Config Object

The `application_config` object configures Kubernetes applications and Helm charts:

```terraform
application_config = {
  # General
  name           = "unreal-cloud-ddc"
  project_prefix = "cgd"
  
  # Credentials (REQUIRED - follows name_prefix pattern)
  ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:region:account:secret:ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials"
  
  # Application Settings (optional, defaults provided)
  unreal_cloud_ddc_namespace           = "unreal-cloud-ddc"
  unreal_cloud_ddc_version             = "1.2.0"
  unreal_cloud_ddc_service_account_name = "unreal-cloud-ddc-sa"
  
  # Certificate Management (optional)
  enable_certificate_manager          = false
  certificate_manager_hosted_zone_arn = ["arn:aws:route53:..."]
}
```

### Multi-Region Configuration

For multi-region deployments, specify both primary and secondary regions:

```terraform
regions = {
  primary   = { region = "us-east-1" }
  secondary = { region = "us-west-2" }
}

vpc_ids = {
  primary   = aws_vpc.primary.id
  secondary = aws_vpc.secondary.id
}
```

## Migration from Separate Modules

### Before (Separate Modules)
```terraform
# Old approach - multiple module calls
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # ... VPC configuration
}

module "unreal_cloud_ddc_infra" {
  source = "./unreal-cloud-ddc-infra"
  # ... 50+ variables
}

module "unreal_cloud_ddc_intra_cluster" {
  source = "./unreal-cloud-ddc-intra-cluster"
  # ... 30+ variables
  depends_on = [module.unreal_cloud_ddc_infra]
}
```

### After (Unified Module)
```terraform
# New approach - single module call
module "unreal_cloud_ddc" {
  source = "../../modules/unreal/unreal-cloud-ddc"
  
  vpc_ids               = { primary = aws_vpc.main.id }
  infrastructure_config = { /* simplified config */ }
  application_config    = { /* simplified config */ }
}
```

### Migration Steps
1. **Backup existing state**: `terraform state pull > backup.tfstate`
2. **Update configuration** to use unified module structure
3. **Import existing resources** or deploy fresh (recommended)
4. **Test thoroughly** before production migration

## Architecture

This module internally uses:
- `./modules/infrastructure/` - EKS clusters, ScyllaDB, networking (formerly `unreal-cloud-ddc-infra`)
- `./modules/applications/` - Kubernetes applications and Helm charts (formerly `unreal-cloud-ddc-intra-cluster`)

### Key Improvements
- **Automatic dependency management** - Applications wait for infrastructure
- **Provider consolidation** - Only AWS providers needed from user
- **Graceful cleanup** - Proper destroy order prevents hanging resources
- **Multi-region orchestration** - Conditional deployment based on regions map

## Requirements

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl (for post-deployment verification)

### AWS Permissions
The module requires permissions for:
- EKS (clusters, node groups, addons)
- EC2 (instances, security groups, networking)
- IAM (roles, policies, OIDC providers)
- S3 (buckets for DDC storage)
- Secrets Manager (GitHub credentials)
- Route53 (optional, for DNS)
- ACM (optional, for TLS certificates)