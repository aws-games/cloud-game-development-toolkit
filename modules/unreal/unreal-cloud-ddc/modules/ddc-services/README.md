# Unreal Cloud DDC Services

This submodule deploys the DDC application services on Kubernetes using Helm charts.

## Components

- **ECR Pull-Through Cache**: Caches GitHub Container Registry images locally
- **DDC Application**: Helm deployment of Unreal Cloud DDC services
- **Kubernetes Resources**: Service accounts, namespaces, and RBAC

## Usage

This submodule is part of the main Unreal Cloud DDC module. For complete documentation, see the [main module](../../README.md).

## Requirements

- EKS cluster (provided by ddc-infra submodule)
- GitHub credentials in AWS Secrets Manager with `ecr-pullthroughcache/` prefix
- Valid Epic Games organization access for container images

## Configuration

Key variables:

- `unreal_cloud_ddc_version`: DDC version to deploy
- `ghcr_credentials_secret_manager_arn`: GitHub credentials for image pulling
- `region`: AWS region for ECR pull-through cache

<!-- BEGIN_TF_DOCS -->
