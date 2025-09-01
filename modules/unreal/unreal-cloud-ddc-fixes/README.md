# Unreal Cloud DDC (Derived Data Cache) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

Deploy Unreal Engine's Cloud DDC infrastructure on AWS for distributed game development teams.

> **⚠️ Can't access the Unreal Cloud DDC link?** You need Epic Games GitHub organization access. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) to join the organization and get access to DDC resources. **Note: This is critical to use DDC. You must do this or the deployment will not work.**

## 🔧 Version Requirements

**⚠️ Important Version Dependencies:**

- **Terraform 1.11+** - Required for enhanced region support and multi-region deployments
- **AWS Provider 6.0+** - Required for enhanced region support enabling simplified multi-region deployments
- **Helm Provider 2.16.0+ (< 3.0.0)** - Required for Kubernetes integration and application deployment

These versions enable enhanced security and simplified multi-region configuration patterns used throughout this module.

## ✨ Features

- **Single module call** deploys complete DDC infrastructure (EKS, ScyllaDB, S3, Load Balancers)
- **Multi-region support** with cross-region replication
- **Access method control** - External (internet) or Internal (VPC) access patterns
- **Security by default** - Private subnets, least privilege IAM, no 0.0.0.0/0 ingress
- **Regional DNS endpoints** - `us-east-1.ddc.example.com` pattern for optimal routing

## 🏢 Architecture

### Single Region Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Game Devs     │───▶│   Public NLB     │───▶│   EKS Cluster   │
│ (UE Clients)    │    │us-east-1.ddc... │    │  DDC Services   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │               ┌─────────────────┐
                                │               │   ScyllaDB      │
                                │               │   (Metadata)    │
                                │               └─────────────────┘
                                │                        │
                                │               ┌─────────────────┐
                                │               │   S3 Bucket     │
                                │               │  (Asset Data)   │
                                │               └─────────────────┘
```

### Traffic Flow Details

**HTTP Traffic Flow:**
```
Game Developer → HTTP Request → Public NLB (TCP:80) → EKS Service → DDC Pod
```

**HTTPS Traffic Flow:**
```
Game Developer → HTTPS Request → Public NLB (SSL termination, TCP:443) → EKS Service → DDC Pod
```

**SSL Termination**: Certificate attached to NLB listener, created and validated at example level.

**Components:**
- **EKS Cluster**: Kubernetes cluster with specialized node groups (system, worker, NVME)
- **ScyllaDB**: High-performance database cluster for DDC metadata
- **S3 Bucket**: Object storage for cached game assets
- **Network Load Balancer**: External access with regional DNS endpoints
- **Private Subnets**: All compute resources deployed privately for security

### Multi-Region Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US East       │───▶│us-east-1.ddc... │───▶│ EKS us-east-1   │
│  Game Devs      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US West       │───▶│us-west-2.ddc... │───▶│ EKS us-west-2   │◀─┐
│  Game Devs      │    │                  │    │                 │  │
└─────────────────┘    └──────────────────┘    └─────────────────┘  │
                                                         │           │
                                               ┌─────────────────┐  │
                                               │   ScyllaDB      │  │
                                               │  Multi-Region   │──┘
                                               └─────────────────┘
```

**Multi-Region Benefits:**
- **Regional independence**: Each region operates independently
- **Cross-region replication**: ScyllaDB automatically syncs data
- **Reduced latency**: Users connect to geographically closest region
- **Disaster recovery**: Built-in failover capabilities

## 🧩 Submodules

This module uses a parent-child architecture with specialized submodules:

### DDC Infrastructure (`ddc-infra`)
Creates core AWS resources: EKS cluster with specialized node groups, ScyllaDB database cluster on dedicated EC2 instances, S3 storage buckets, and load balancers for external access.

### DDC Services (`ddc-services`)
Deploys Unreal Cloud DDC applications to the EKS cluster using Helm charts, manages container orchestration, and configures service networking with load balancer integration.

## 🎒 Prerequisites

### Required Tools & Access

- **Epic Games Organization Access**: Must be member of Epic Games GitHub organization to access DDC container images
- **GitHub Personal Access Token**: Stored in AWS Secrets Manager with `packages:read` permission
- **AWS CLI**: Configured with appropriate permissions for deployment
- **kubectl**: For EKS cluster access and verification
- **Terraform >= 1.11**: For enhanced region support
- **Route53 Hosted Zone**: For DNS records and SSL certificate validation

### Network Infrastructure Requirements

**Required VPC Configuration:**
- **2 public subnets** - For load balancers (follows private-first design)
- **2 private subnets** - For EKS nodes and ScyllaDB instances
- **Coverage across 2 Availability Zones** - For high availability
- **Internet Gateway** - For outbound internet access
- **NAT Gateways** - For private subnet internet access

### GitHub Container Registry Access

**Critical Setup Steps:**

1. **Join Epic Games GitHub Organization**: Follow [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)

2. **Create GitHub Personal Access Token** with `packages:read` permission

3. **Store credentials in AWS Secrets Manager**:
```bash
aws secretsmanager create-secret \
  --name "ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

## 📚 Examples

For complete working examples, see the [examples directory](./examples/).

**Available Examples:**
- [Single Region](./examples/single-region/) - Basic single-region deployment with external access
- [Multi-Region](./examples/multi-region/) - Multi-region setup with cross-region replication

## 🚀 Deployment Instructions

### Step 1: Configure GitHub Credentials

Create and store GitHub credentials in AWS Secrets Manager:

```bash
# Store GitHub credentials as JSON (required format)
aws secretsmanager create-secret \
  --name "ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

### Step 2: Configure Terraform

Set up your Terraform configuration. See the [examples](./examples/) for complete working configurations.

**Basic Configuration:**
```hcl
module "unreal_cloud_ddc" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc-fixes?ref=main"
  
  # Access method (external = internet access, internal = VPC only)
  access_method = "external"
  
  # Networking (REQUIRED)
  vpc_id = aws_vpc.main.id
  public_subnets = aws_subnet.public[*].id   # Required for external access
  private_subnets = aws_subnet.private[*].id # Required for services
  
  # Security - your office/VPN network
  allowed_external_cidrs = ["203.0.113.0/24"]
  
  # DNS
  route53_public_hosted_zone_name = "yourcompany.com"
  
  # DDC Infrastructure
  ddc_infra_config = {
    region = "us-east-1"
    scylla_replication_factor = 3
  }
  
  # DDC Services
  ddc_services_config = {
    unreal_cloud_ddc_version = "1.2.0"
    ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials"
  }
}
```

### Step 3: Deploy Infrastructure

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

## ✅ Verifying and Testing DDC Deployment

### Basic Verification

**Configure kubectl access:**
```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

**Check DDC pods are running:**
```bash
kubectl get pods -n unreal-cloud-ddc
```

### Manual Connectivity Test

**Test DDC API connectivity:**
```bash
# Get bearer token from AWS Secrets Manager
TOKEN=$(aws secretsmanager get-secret-value --secret-id <bearer-token-secret-arn> --query SecretString --output text)

# Test health endpoint
curl http://us-east-1.ddc.yourcompany.com/api/v1/health -H "Authorization: ServiceAccount $TOKEN"

# Test functionality
curl http://us-east-1.ddc.yourcompany.com/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa \
  -X PUT --data 'test' \
  -H 'content-type: application/octet-stream' \
  -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' \
  -H "Authorization: ServiceAccount $TOKEN"
```

## 🔌 Connecting Unreal Engine to DDC

### Configuration Steps

**Get connection information from Terraform outputs:**
```bash
terraform output ddc_connection
```

**Configure Unreal Engine project (`Config/DefaultEngine.ini`):**
```ini
[DDC]
; Use your deployed DDC service
DefaultBackend=Shared

; Configure the shared DDC backend
Shared=(Type=S3, Remote=true, Bucket=<s3-bucket-name>, Region=<aws-region>, BaseUrl=http://<ddc-endpoint>)

; Optional: Configure local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)
```

### Multi-Region Configuration

For distributed teams, configure region-specific endpoints:

```ini
[DDC]
; Primary region DDC
Primary=(Type=S3, Remote=true, Bucket=primary-bucket, Region=us-east-1, BaseUrl=http://us-east-1.ddc.yourcompany.com)

; Secondary region DDC (fallback)
Secondary=(Type=S3, Remote=true, Bucket=secondary-bucket, Region=us-west-2, BaseUrl=http://us-west-2.ddc.yourcompany.com)

; Try primary first, then secondary, then local
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

## User Personas

### 1. DevOps Team (Infrastructure Provisioners)

**Responsibilities:**
- Deploy and manage DDC infrastructure
- Configure networking and security
- Handle certificates and DNS
- Monitor infrastructure health

**Access Requirements:**
```hcl
# EKS API access for kubectl/Terraform
allowed_external_cidrs = ["203.0.113.0/24"]  # Office/VPN network

# Full access to all services
existing_security_groups = [aws_security_group.devops_team.id]
```

**Tools Used:**
- Terraform (this module)
- kubectl (EKS management)
- AWS Console

### 2. Game Developers (Service Consumers)

**Responsibilities:**
- Use DDC for faster asset iteration
- Configure Unreal Engine DDC settings
- Report performance issues

**Access Requirements:**
```hcl
# DDC service access only (not backend infrastructure)
existing_security_groups = [aws_security_group.game_developers.id]
```

**Tools Used:**
- Unreal Engine Editor
- DDC configuration files

## Deployment Patterns

### Single Region Deployment

**When to Use:**
- ✅ **Small teams** (5-20 developers)
- ✅ **Co-located teams** (same geographic region)
- ✅ **Prototyping/MVP** projects
- ✅ **Budget-conscious** deployments

**Benefits:**
- Lower cost (single region)
- Simpler management
- Faster deployment

### Multi-Region Deployment

**When to Use:**
- ✅ **Distributed teams** (US + Europe + Asia)
- ✅ **Large studios** (50+ developers)
- ✅ **Performance-critical** workflows
- ✅ **Disaster recovery** requirements

**Benefits:**
- Reduced latency for global teams
- Built-in disaster recovery
- Regional data compliance

## Multi-Region Considerations

### DNS Strategy

**Regional Endpoints (Recommended):**
- **External**: `us-east-1.ddc.example.com`, `us-west-2.ddc.example.com`
- **Internal**: `us-east-1.ddc.internal`, `us-west-2.ddc.internal`

**Benefits:**
- ✅ **Explicit control** - developers choose region
- ✅ **Easy debugging** - clear which region
- ✅ **Simple DNS** - no complex routing
- ✅ **UE configuration** - set specific endpoint

## Security & Access Patterns

### Network Architecture

**Private-First Design:**
- Services always deployed in private subnets
- User access method determines load balancer placement
- **NLB-First Strategy**: All traffic routed through load balancers

### Access Method Control

All modules support configurable access patterns via `access_method` variable:

```hcl
variable "access_method" {
  type = string
  description = "external/public: Internet → Public NLB | internal/private: VPC → Private NLB"
  default = "external"
  
  validation {
    condition = contains(["external", "internal", "public", "private"], var.access_method)
    error_message = "Must be 'external'/'public' or 'internal'/'private'"
  }
}
```

**External Access (Default):**
```hcl
access_method = "external"  # or "public"
```
- **Creates**: Public NLB for internet access
- **DNS**: Regional endpoints (us-east-1.ddc.example.com)
- **Security**: Restricted CIDR blocks (no 0.0.0.0/0)
- **Connection**: Users connect via public internet with controlled access

**Internal Access:**
```hcl
access_method = "internal"  # or "private"
```
- **Creates**: Private NLB for VPC-only access
- **DNS**: Regional endpoints (us-east-1.ddc.internal)
- **Security**: VPC CIDR blocks for automatic inclusion
- **Connection**: Users need VPC access via VPN, Direct Connect, or VDI

### Security Best Practices

```hcl
variable "allowed_external_cidrs" {
  type = list(string)
  description = "CIDR blocks for external access. Use prefix lists for multiple IPs."
  
  validation {
    condition = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for security. Specify actual CIDR blocks."
  }
}
```

## 🔧 Troubleshooting

### Common Issues

**EKS Cluster Creation Fails:**
- **Cause**: Insufficient IAM permissions or VPC/subnet issues
- **Solution**: Verify AWS credentials and VPC configuration

**DDC API Connection Timeout:**
- **Cause**: Security group restrictions or DNS issues
- **Solution**: Check `allowed_external_cidrs` includes your IP

**GitHub Container Registry Access Denied:**
- **Cause**: Missing Epic Games organization access or invalid PAT
- **Solution**: Verify Epic Games membership and PAT permissions

### Debugging Commands

```bash
# Check current IP
curl https://checkip.amazonaws.com/

# Test DNS resolution
nslookup us-east-1.ddc.yourcompany.com

# Check EKS cluster status
aws eks describe-cluster --name <cluster-name>

# Verify kubectl access
kubectl get nodes
```

## Best Practices

### Security
- ✅ Use private subnets for all compute resources
- ✅ Implement least-privilege access with specific CIDR blocks
- ✅ Enable VPC Flow Logs for network monitoring
- ✅ Use AWS Secrets Manager for credentials

### Performance  
- ✅ Deploy close to development teams (regional endpoints)
- ✅ Use appropriate instance types for workload
- ✅ Monitor cache hit rates
- ✅ Implement proper ScyllaDB tuning

### Operations
- ✅ Set up automated backups for S3 and ScyllaDB
- ✅ Document runbooks for common issues
- ✅ Test disaster recovery procedures
- ✅ Use regional DNS for optimal routing

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.16.0, < 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.33.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ddc_infra"></a> [ddc\_infra](#module\_ddc\_infra) | ./modules/ddc-infra | n/a |
| <a name="module_ddc_services"></a> [ddc\_services](#module\_ddc\_services) | ./modules/ddc-services | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_lb.shared_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_target_group.shared_nlb_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.ddc_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_security_group.external_nlb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.internal_nlb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_method"></a> [access\_method](#input\_access\_method) | Access method for the DDC service. 'external'/'public' creates public NLB for internet access. 'internal'/'private' creates private NLB for VPC-only access. | `string` | `"external"` | no |
| <a name="input_allowed_external_cidrs"></a> [allowed\_external\_cidrs](#input\_allowed\_external\_cidrs) | List of CIDR blocks allowed to access DDC service externally. Cannot include 0.0.0.0/0 for security. | `list(string)` | `[]` | no |
| <a name="input_ddc_infra_config"></a> [ddc\_infra\_config](#input\_ddc\_infra\_config) | Configuration for DDC infrastructure deployment | <pre>object({<br/>    region                    = string<br/>    scylla_replication_factor = number<br/>    kubernetes_version        = optional(string, "1.31")<br/>    create_seed_node          = optional(bool, true)<br/>    existing_scylla_seed      = optional(string, null)<br/>  })</pre> | `null` | no |
| <a name="input_ddc_services_config"></a> [ddc\_services\_config](#input\_ddc\_services\_config) | Configuration for DDC services deployment | <pre>object({<br/>    unreal_cloud_ddc_version            = string<br/>    ghcr_credentials_secret_manager_arn = string<br/>    namespace                           = optional(string, "unreal-cloud-ddc")<br/>  })</pre> | `null` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of private subnet IDs for EKS nodes and ScyllaDB instances | `list(string)` | `[]` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | List of public subnet IDs for load balancers | `list(string)` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deployment | `string` | n/a | yes |
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | Route53 public hosted zone name for DNS records | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where DDC infrastructure will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ddc_connection"></a> [ddc\_connection](#output\_ddc\_connection) | DDC connection information for this region |
| <a name="output_ddc_infra"></a> [ddc\_infra](#output\_ddc\_infra) | DDC infrastructure outputs |
| <a name="output_ddc_services"></a> [ddc\_services](#output\_ddc\_services) | DDC services outputs |
| <a name="output_dns_endpoints"></a> [dns\_endpoints](#output\_dns\_endpoints) | DNS endpoints for DDC services |
<!-- END_TF_DOCS -->