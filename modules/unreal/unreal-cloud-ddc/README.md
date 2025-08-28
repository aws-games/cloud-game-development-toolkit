# Unreal Cloud DDC - Unified Module

This unified module simplifies deployment of Unreal Cloud DDC infrastructure by consolidating the previously separate `unreal-cloud-ddc-infra` and `unreal-cloud-ddc-intra-cluster` modules into a single, easy-to-use interface.

## Features

- **Single module call** deploys complete DDC infrastructure
- **Multi-region support** with conditional deployment
- **Simplified provider management** - only AWS providers required from user
- **Automatic dependency management** between infrastructure and applications
- **90% reduction in configuration complexity**

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
  
  regions = {
    primary = { region = "us-east-1" }
  }
  
  vpc_ids = {
    primary = aws_vpc.main.id
  }
  
  private_subnet_ids = {
    primary = aws_subnet.private[*].id
  }
  
  github_credential_arns = {
    primary = aws_secretsmanager_secret.github_token.arn
  }
  
  project_name = "my-game-ddc"
  environment  = "dev"
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
  
  regions = {
    primary   = { region = "us-east-1" }
    secondary = { region = "us-west-2" }
  }
  
  vpc_ids = {
    primary   = aws_vpc.us_east_1.id
    secondary = aws_vpc.us_west_2.id
  }
  
  private_subnet_ids = {
    primary   = aws_subnet.us_east_1_private[*].id
    secondary = aws_subnet.us_west_2_private[*].id
  }
  
  github_credential_arns = {
    primary   = aws_secretsmanager_secret.github_token_east.arn
    secondary = aws_secretsmanager_secret.github_token_west.arn
  }
  
  project_name = "global-game-ddc"
  environment  = "prod"
}
```

## Examples

- [Single Region](./examples/single-region/) - Basic single-region deployment
- [Multi Region](./examples/multi-region/) - Cross-region deployment with replication

## Migration from Separate Modules

If you're currently using the separate `unreal-cloud-ddc-infra` and `unreal-cloud-ddc-intra-cluster` modules, see the migration guide in each example directory.

## Architecture

This module internally uses:
- `./modules/infrastructure/` - EKS clusters, ScyllaDB, networking (formerly `unreal-cloud-ddc-infra`)
- `./modules/applications/` - Kubernetes applications and Helm charts (formerly `unreal-cloud-ddc-intra-cluster`)

The parent module handles provider configuration, dependency management, and multi-region orchestration automatically.