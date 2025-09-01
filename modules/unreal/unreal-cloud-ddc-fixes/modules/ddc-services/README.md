# Unreal Cloud DDC Services

This submodule deploys the DDC application services on Kubernetes using Helm charts and manages the integration between Terraform-created load balancers and Kubernetes services.

## Architecture Overview

This module implements an advanced integration pattern that combines Terraform infrastructure management with Kubernetes service discovery.

## Components

### Core Services
- **ECR Pull-Through Cache**: Caches GitHub Container Registry images locally in your AWS account
- **DDC Application**: Helm deployment of Unreal Cloud DDC services with ScyllaDB and S3 integration
- **Kubernetes Resources**: Service accounts, namespaces, and RBAC configurations
- **EKS Addons**: CoreDNS, VPC-CNI, EBS CSI driver, and optional certificate manager

### Load Balancer Integration
- **ClusterIP Service**: Internal Kubernetes service with target group annotation
- **Automatic Registration**: EKS service controller registers pod IPs to NLB target group
- **Health Monitoring**: Kubernetes health checks integrated with AWS target group health

## Usage

This submodule is part of the main Unreal Cloud DDC module. For complete documentation, see the [main module](../../README.md).

## Requirements

- EKS cluster (provided by ddc-infra submodule)
- GitHub credentials in AWS Secrets Manager with `ecr-pullthroughcache/` prefix
- Valid Epic Games organization access for container images
- Target group ARN from parent module

## Configuration

Key variables:

- `unreal_cloud_ddc_version`: DDC version to deploy (e.g., "1.2.0")
- `ghcr_credentials_secret_manager_arn`: GitHub credentials for image pulling
- `region`: AWS region for ECR pull-through cache
- `nlb_target_group_arn`: Target group ARN from parent module NLB
- `ddc_bearer_token`: Authentication token for DDC API access
- `scylla_ips`: ScyllaDB node IPs for database connection
- `s3_bucket_id`: S3 bucket for asset storage

<!-- BEGIN_TF_DOCS -->
