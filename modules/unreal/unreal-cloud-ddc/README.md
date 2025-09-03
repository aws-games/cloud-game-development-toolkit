# Unreal Cloud DDC (Derived Data Cache) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **⚠️ IMPORTANT**
>
> **You MUST have Epic Games GitHub organization access to use this module.** Without access, container image pulls will fail and deployment will not work. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) to join the organization before proceeding.
>
> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

## Version Requirements

Consult the `versions.tf` file for requirements

**Critical Version Dependencies:**

- **Terraform >= 1.11** - Required for enhanced region support and multi-region deployments
- **AWS Provider >= 6.0** - Required for enhanced region support enabling simplified multi-region configuration
- **AWSCC Provider >= 1.0** - Required for Amazon Keyspaces keyspace creation
- **Kubernetes Provider >= 2.33.0** - Required for EKS cluster management and service deployment
- **Helm Provider >= 2.16.0, < 3.0.0** - Required for DDC application deployment

**DDC Application Version:**

- **Use DDC version 1.2.0** - Stable and tested
- **Avoid DDC version 1.3.0** - Has configuration parsing bugs that cause pod crashes

These version requirements enable the security patterns and multi-region capabilities used throughout this module.

## Features

- **Complete DDC Infrastructure** - Single module deploys EKS cluster, database, S3 storage, and load balancers
- **Dual Database Support** - Choose between Amazon Keyspaces (managed) or ScyllaDB (self-managed)
- **Multi-Region Support** - Cross-region replication with automatic datacenter configuration
- **Security by Default** - Private subnets, least privilege IAM, restricted network access
- **Access Method Control** - External (internet) or internal (VPC-only) access patterns
- **Regional DNS Endpoints** - e.g. `<region>.ddc.example.com` pattern for optimal routing
- **Automatic Keyspace Management** - SSM automation fixes DDC replication strategy issues
- **Container Integration** - ECR pull-through cache for Epic Games container images

## Database Options

**Amazon Keyspaces (Recommended)**
- **Fully managed** - No database administration required
- **Serverless scaling** - Automatically handles traffic spikes and high throughput
- **Global tables** - Built-in multi-region replication
- **IAM authentication** - No credential management needed
- **Pay-per-request** - Cost-effective for variable workloads
- **High availability** - 99.99% SLA with automatic failover
- **Best for** - Most teams, production environments, global deployments

**ScyllaDB (Advanced Use Cases)**
- **Dedicated resources** - Guaranteed compute and memory allocation
- **Full control** - Complete configuration flexibility and custom tuning
- **Predictable costs** - Fixed EC2 pricing for consistent high-volume workloads
- **Advanced optimization** - Fine-grained performance tuning capabilities
- **Best for** - Large studios with dedicated database expertise, predictable high-volume workloads

### When to Choose Each Option

| Scenario | Recommended Database | Reason |
|----------|---------------------|--------|
| **Small to medium teams** | Amazon Keyspaces | No database administration overhead |
| **Variable workloads** | Amazon Keyspaces | Pay-per-request scales with usage |
| **Global teams** | Amazon Keyspaces | Built-in global tables |
| **Production environments** | Amazon Keyspaces | Managed service reliability |
| **Predictable high-volume workloads** | ScyllaDB | Fixed costs, dedicated resources |
| **Advanced database tuning needs** | ScyllaDB | Full configuration control |
| **Dedicated database team** | ScyllaDB | Can leverage advanced tuning |

## Architecture

**Core Components:**

- **EKS Cluster**: Kubernetes cluster with specialized node groups (system, worker, NVME)
- **Database**: Amazon Keyspaces (managed) or ScyllaDB (self-managed) for DDC metadata
- **S3 Bucket**: Object storage for cached game assets
- **Network Load Balancer**: External access with regional DNS endpoints
- **Route53 Private Hosted Zone**: DNS for internal routing between services (when needed)
- **Private Subnets**: All compute resources deployed privately for security

### Single Region Architecture

> **⚠️ TODO - ADD ARCHITECTURE DIAGRAM HERE**

#### Traffic Flow

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

### Multi-Region Architecture

> **⚠️ TODO - ADD ARCHITECTURE DIAGRAM HERE**

#### Traffic Flow

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

## Prerequisites

### Required Access & Tools

1. **Epic Games GitHub Organization Access** (CRITICAL ⚠️)

   - Must be member of Epic Games GitHub organization
   - Required to pull DDC container images
   - Follow [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)

2. **AWS Account Setup**

   - AWS CLI configured with deployment permissions
   - Route53 hosted zone for DNS records
   - VPC with public and private subnets

3. **GitHub Container Registry Access**

   - GitHub Personal Access Token with `packages:read` permission
   - Token stored in AWS Secrets Manager with `ecr-pullthroughcache/` prefix

4. **Network Planning**
   - Office/VPN IP ranges for security group access
   - VPC CIDR planning for multi-region deployments

### GitHub Container Registry Setup

#### Step 1: Create GitHub Personal Access Token

**Create a GitHub Personal Access Token (Classic) to access Epic Games container images:**

1. **Go to GitHub Settings**

   - Navigate to [GitHub.com](https://github.com) and sign in
   - Click your profile picture → **Settings**

2. **Access Developer Settings**

   - Scroll down to **Developer settings** (bottom of left sidebar)
   - Click **Personal access tokens** → **Tokens (classic)**

3. **Generate New Token**

   - Click **Generate new token** → **Generate new token (classic)**
   - Enter a descriptive **Note**: `DDC Container Registry Access`
   - Set **Expiration**: Choose appropriate duration (90 days recommended)

4. **Configure Permissions**

   - **REQUIRED**: Check `read:packages` - _Download packages from GitHub Package Registry_
   - Leave all other permissions unchecked

5. **Generate and Save Token**
   - Click **Generate token**
   - **CRITICAL**: Copy the token immediately - you cannot view it again
   - Store in AWS Secrets Manager (next step)

⚠️ **Prerequisites**: You must be a member of the Epic Games GitHub organization to access their private container registry. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) for organization access.

**Store credentials in AWS Secrets Manager:**

> **🚨 IMPORTANT**
>
> The name of the secret must EXACTLY start with `ecr-pullthroughcache/` or it will not work. Also, you must use a classic access token. The naming after the `ecr-pullthroughcache/` generally doesn't matter, but has some things to be aware of. See [these Amazon ECR docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-secret.html) for more information. Since this value is a personal token that you must create in your own GitHub account, we recommend naming such as `ecr-pullthroughcache/your-github-username/name-of-the-token-in-GitHub`

```bash
aws secretsmanager create-secret \
  --name "ecr-pullthroughcache/<Whatever you want to name this>" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

> **ℹ️ Note**
>
> You may want to target a specific region with --region if deploying to a region different from your AWS CLI default. For multi-region deployments, create the secret in each region where DDC will be deployed. Each region's ECR pull-through cache requires its own copy of the GitHub credentials to authenticate with Epic Games' container registry and create the private ECR repository.
> This private ECR repo is used by Helm to install Unreal DDC on the EKS cluster.

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples). They provide a good reference for not only the ways to declare and customize the module configuration, but how to provision and reference the infrastructure mentioned in the prerequisites. As mentioned earlier, we avoid creating infrastructure that is more general (e.g. VPCs, Subnets, Security Groups, etc.) as this can be highly nuanced . All examples show sample configurations of these resources created external to the module, but please customize based on your own needs.

This module provides examples for both database options:

**Amazon Keyspaces Examples (Recommended):**
- **[Single Region Basic](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples/single-region-basic)** - Keyspaces deployment for small to medium teams
- **[Multi-Region Basic](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples/multi-region-basic)** - Keyspaces with global tables for distributed teams

**ScyllaDB Examples (Advanced):**
- **[Single Region Scylla](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples/single-region-scylla)** - Self-managed ScyllaDB deployment
- **[Multi-Region Scylla](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples/multi-region-scylla)** - ScyllaDB with cross-region replication

## Deployment Instructions

### Step 1: Declare and configure the module

Note, this is just a condensed sample. See the examples for the related required infrastructure.

**Single Region Example**

```terraform
module "unreal_cloud_ddc" {
  source = "../../"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  # - Shared -
  region = local.primary_region
  existing_vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_load_balancer_subnets = aws_subnet.public_subnets[*].id
  existing_service_subnets = aws_subnet.private_subnets[*].id
  existing_security_groups = [aws_security_group.allow_my_ip.id]

  # DNS Configuration
  existing_route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  existing_certificate_arn = aws_acm_certificate.ddc.arn

  # - DDC Infra Configuration -
  ddc_infra_config = {
    region = local.primary_region
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    eks_api_access_cidrs   = ["${chomp(data.http.my_ip.response_body)}/32"]
    scylla_subnets = aws_subnet.private_subnets[*].id
  }

  # - DDC Services Configuration -
  ddc_services_config = {
    region = local.primary_region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}
```

### Step 2: Deploy Infrastructure

> **⚠️ IMPORTANT**
>
> This module creates **internet-accessible** services by default. Review security configurations and restrict access to your organization's IP ranges before deployment.

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs for UE configuration
# terraform output ddc_connection
```

## Verification & Testing

### Networking

**1. Basic Health Check**

**[Request]**

```bash
# Test DDC health endpoint
curl <DDC Route53 DNS Endpoint>/health/live
```

**[Response]**

After running this you should get a response that looks as the following:

```bash
HEALTHY%
```

**2. PUT a file in Unreal Cloud DDC**

**[Request]**

```bash
# Test PUT operation (write to cache)
curl -X PUT "<DDC Route53 DNS Endpoint>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa" \
  --data "test" \
  -H "content-type: application/octet-stream" \
  -H "X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E" \
  -H "Authorization: ServiceAccount <Value of the Bearer token from the AWS Secrets Manager secret"
```

**[Response]**

After running this you should get a response that looks as the following:

```bash
HTTP/1.1 200 OK
Server: http
Date: Wed, 29 Jan 2025 19:15:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server-Timing: blob.put.FileSystemStore;dur=0.1451;desc="PUT to store: 'FileSystemStore'",blob.put.AmazonS3Store;dur=267.0449;desc="PUT to store: 'AmazonS3Store'",blob.get-metadata.FileSystemStore;dur=0.0406;desc="Blob GET Metadata from: 'FileSystemStore'",ref.finalize;dur=7.1407;desc="Finalizing the ref",ref.put;dur=25.2064;desc="Inserting ref"

{"needs":[]}}%
```

> ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️NOTE TO KEVON - YOU MAY NEED TO USE HTTP⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️

**3. GET the file you wrote to Unreal Cloud DDC**

**[Request]**

```bash
# Test GET operation (read from cache)
curl "<DDC Route53 DNS Endpoint>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json" \
  -H "Authorization: ServiceAccount <Value of the Bearer token from the AWS Secrets Manager secret"
```

**[Response]**

After running this you should get a response that looks as the following:

```bash
HTTP/1.1 200 OK
Server: http
Date: Wed, 29 Jan 2025 19:16:46 GMT
Content-Type: application/json
Content-Length: 66
Connection: keep-alive
X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E
X-Jupiter-LastAccess: 01/29/2025 19:16:46
Server-Timing: ref.get;dur=0.0299;desc="Fetching Ref from DB"

{"RawHash":"4878ca0425c739fa427f7eda20fe845f6b2e46ba","RawSize":4}%
```

#### ⚠️ Troubleshooting ⚠️

If the above command do not work, try to test access to the Network Load Balancer directly

**Example:**

```bash
# Test DDC health endpoint
curl <Network Load Balancer Endpoint>/health/live

# Expected response: "Healthy"
```

### Application

**1. Verify the Unreal Cloud DDC EKS Cluster Status**

**[Request]**

```bash
# Configure kubectl access
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Check pod status
kubectl get pods -n unreal-cloud-ddc

```

**[Response]**

 <!-- Expected: All pods should be "Running" -->

```bash
TODO
```

### Database

**1. Check the status of the database nodes**

Connect to any of the Scylla Nodes and run the following command (SSM with Session Manager recommended):

**[Request]**

```bash
nodetool status
```

**[Response]**

```bash
TODO
```

**2. Check the keyspaces are present**

On the instance, start cqlsh session:

```bash
cqlsh
```

**[Request]**

Check if all keyspaces are there

```bash
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces:

- jupiter
- jupiter_ddc_local

**2. Check the keyspace configuration**

On the instance, start cqlsh session:

```bash
cqlsh
```

**[Request]**

Check if all keyspaces are there

```bash
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces:

- jupiter
- jupiter_ddc_local

## Client Connection Guide

> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

### Unreal Engine Configuration

**1. Get connection details:**
You can either see the relevant details in the Terraform outputs after a successful apply, or separately run the following command to get all of the outputs. Ensure you have defined the outputs you would like to use at in the same directory you initialized Terraform in.

**[Request]**

```bash
# Get all outputs
terraform output -json
```

**[Response]**

**2/ Configure project (`Config/DefaultEngine.ini`):**

```ini
[DDC]
; Production configuration
Cloud=(Type=HTTPDerivedDataBackend, Host="<DDS Route53 DNS Endpoint>")

; Optional: Local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)

; Hierarchical setup (try cloud first, then local)
Hierarchical=(Type=Hierarchical, Inner=Cloud, Inner=Local)
```

### Multi-Region Configuration

You can also have a multi-region configuration which has benefits for geographically distributed teams:

For distributed teams:

```ini
[DDC]
; Region 1 (Primary in this case)
Primary=(Type=HTTPDerivedDataBackend, Host="<DDS Route53 DNS Endpoint for Region 1>")

; Region 2
Secondary=(Type=HTTPDerivedDataBackend, Host="https://us-west-2.ddc.yourcompany.com")

; Try primary first, then secondary, then local
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

> **Note:** while the Hierarchical setup mentions `Primary` and `Secondary` you can have more than 2 AWS regions used. This is just setting the priority order for cache usage. This is helpful to set for both latency and DR considerations. For more information on this see [these docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine).

## Database Migration Guide

### Overview

This module supports migrating between ScyllaDB and Amazon Keyspaces with minimal downtime. The migration process preserves your existing DDC infrastructure while switching the database backend.

### Migration Options

**Option A: Cache Rebuild (Simple)**
- **Process**: Switch databases, let DDC rebuild cache from source assets
- **Downtime**: 2-5 minutes (automatic during terraform apply)
- **Performance Impact**: Significant degradation until cache repopulates (hours to days)
- **Complexity**: Low
- **Best for**: Development environments, small teams, acceptable performance impact

**Option B: Data Migration (Recommended for Production)**
- **Process**: Export/import cache data between databases (user-managed)
- **Downtime**: Highly variable - depends on data volume and migration method
- **Performance Impact**: Minimal post-migration
- **Complexity**: Medium to High
- **Best for**: Production environments, large studios, preserving cache optimization
- **Note**: Module supports active/active setup - users must handle data export/import manually

### ScyllaDB → Amazon Keyspaces Migration

#### Prerequisites
- Existing ScyllaDB deployment
- AWS CLI configured
- kubectl access to EKS cluster
- CQL client (cqlsh) installed

#### Option A: Cache Rebuild Migration

**Step 1: Enable Migration Mode & Create Keyspaces**
```hcl
# terraform/main.tf
database_migration_mode = true        # Enable dual database support
database_migration_target = "scylla"   # Keep DDC on Scylla initially

# Keep existing ScyllaDB config
scylla_config = {
  current_region = {
    replication_factor = 3
    node_count = 3
  }
  enable_cross_region_replication = false
}

# Add Amazon Keyspaces config (must match ScyllaDB settings)
amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false  # Must match ScyllaDB
  peer_regions = []  # Must match ScyllaDB peer_regions
}
```

**Step 2: Create Keyspaces (DDC stays on Scylla)**
```bash
terraform apply
# - Creates: Keyspaces keyspace and tables (EMPTY)
# - Keeps: DDC using Scylla (no service interruption)
# - Ready: For data migration or direct switch
```

**Step 3: Switch DDC to Keyspaces**
```hcl
# terraform/main.tf - Switch DDC target
database_migration_mode = true
database_migration_target = "keyspaces"  # Switch DDC to Keyspaces

scylla_config = { ... }  # Keep both configs
amazon_keyspaces_config = { ... }
```

```bash
terraform apply
# - Switches: DDC to Keyspaces (2-5 minutes downtime)
# - Result: DDC starts with empty cache, rebuilds on-demand
```

**Step 4: Verify Migration**
```bash
# Configure kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify DDC uses Keyspaces
kubectl exec <ddc-pod> -n unreal-cloud-ddc -- env | grep Database__Type
# Should show: Database__Type=keyspaces

# Test DDC functionality
curl <ddc-endpoint>/health/live
curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/test" --data "migration-test"
```

**Step 5: Remove ScyllaDB Config**
```hcl
# terraform/main.tf - Remove ScyllaDB config
database_migration_mode = true  # Keep enabled for cleanup

# Remove ScyllaDB config entirely
# scylla_config = { ... }  # DELETE THIS BLOCK

# Keep Keyspaces config
amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false
}
```

**Step 6: Cleanup ScyllaDB Resources**
```bash
terraform apply
# Destroys ScyllaDB EC2 instances and related resources
```

**Step 7: Disable Migration Mode**
```hcl
# terraform/main.tf
database_migration_mode = false  # Back to normal operation

amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false
}
```

```bash
terraform apply
# Should show: No changes. Infrastructure is up-to-date.
```

#### Option B: Data Migration (Production Recommended)

**Step 1-2: Same as Option A** (Enable migration mode, create Keyspaces, DDC stays on Scylla)

**Step 3: Export ScyllaDB Data (User-Managed)**
```bash
# Connect to ScyllaDB node
aws ssm start-session --target <scylla-instance-id>

# Export all DDC tables (user must determine actual table names and schemas)
cqlsh -e "DESCRIBE KEYSPACE jupiter_local_ddc_<region_suffix>;"
cqlsh -e "COPY jupiter_local_ddc_<region_suffix>.<table_name> TO '/tmp/<table_name>.csv'"

# User must handle data transfer method (S3, direct copy, etc.)
# Time varies significantly based on data volume and method chosen
```

**Step 4: Import to Amazon Keyspaces (User-Managed)**
```bash
# User must handle data import process
# Import method depends on data volume, format, and requirements
# Consider using AWS DMS, custom scripts, or CQL COPY commands

# Example CQL import (actual implementation varies):
cqlsh cassandra.<region>.amazonaws.com 9142 --ssl \
  -e "COPY jupiter_local_ddc_<region_suffix>.<table_name> FROM '<table_name>.csv'"

# Note: Users must handle IAM authentication, data format compatibility,
# and error handling based on their specific requirements
```

**Step 5: Verify Data Migration**
```bash
# Test DDC with existing cache data
curl "<ddc-endpoint>/api/v1/refs/ddc/default/<existing-cache-key>.json"
# Should return cached data without rebuilding
```

**Step 6: Switch DDC to Keyspaces (with migrated data)**
```hcl
# terraform/main.tf - Switch DDC target
database_migration_mode = true
database_migration_target = "keyspaces"  # Switch DDC to Keyspaces

scylla_config = { ... }  # Keep both configs
amazon_keyspaces_config = { ... }
```

```bash
terraform apply
# - Switches: DDC to Keyspaces (2-5 minutes downtime)
# - Result: DDC uses migrated cache data, minimal performance impact
```

**Step 7-9: Same as Option A** (Remove ScyllaDB config, cleanup, disable migration mode)

### Amazon Keyspaces → ScyllaDB Migration

The reverse migration follows the same pattern:

1. **Enable migration mode** with both database configs
2. **Export from Keyspaces** using CQL COPY commands
3. **Import to ScyllaDB** after it's created
4. **Remove Keyspaces config** and cleanup

### Multi-Region Migration Considerations

**Critical Requirements:**
- All regions must be migrated simultaneously
- `enable_cross_region_replication` must match between databases
- `peer_regions` must be identical across database configs

**Example Multi-Region Config Sync:**
```hcl
# ScyllaDB config
scylla_config = {
  enable_cross_region_replication = true
  peer_regions = {
    "us-west-2" = { replication_factor = 2 }
    "eu-west-1" = { replication_factor = 2 }
  }
}

# Keyspaces config - MUST MATCH
amazon_keyspaces_config = {
  enable_cross_region_replication = true  # MATCH
  peer_regions = ["us-west-2", "eu-west-1"]  # MATCH (keys from ScyllaDB)
}
```

### Migration Troubleshooting

**Common Issues:**

1. **Validation Error: "Database configurations must match"**
   - Ensure `enable_cross_region_replication` is identical
   - Verify `peer_regions` match exactly

2. **DDC Connection Failures**
   - Check EKS IRSA permissions for Keyspaces
   - Verify security group access for ScyllaDB

3. **Data Import Failures**
   - Ensure table schemas match between databases
   - Check IAM permissions for Keyspaces access
   - Verify CQL syntax compatibility

4. **Performance Issues Post-Migration**
   - Option A: Expected during cache rebuild
   - Option B: Check data import completeness

### Migration Recommendations

| Scenario | Recommended Option | Reason |
|----------|-------------------|--------|
| **Development/Testing** | Option A (Cache Rebuild) | Simple, acceptable performance impact |
| **Production/Large Studios** | Option B (Data Migration) | Preserves cache optimization |
| **Small Cache Size** | Option A (Cache Rebuild) | Migration overhead not worth it |
| **Large Cache Size** | Option B (Data Migration) | Avoid lengthy rebuild process |
| **Time-Sensitive Migration** | Option A (Cache Rebuild) | Faster migration process |
| **Performance-Critical** | Option B (Data Migration) | Maintains cache performance |

## Troubleshooting

### Common Issues

#### 1. Pod Crashes with Unix Socket Error

**Symptoms**: `CrashLoopBackOff`, logs show `Invalid url: 'unix:///nginx/jupiter-http.sock'`

**Cause**: For the EKS Cluster, we use an existing Network Load Balancer (NLB)which is created during deployment, instead of letting EKS create its own NLBs using the Load Balancer Controller. You can see this in our Helm Chart, where we use `ClusterIP` mode. This is to prevent race conditions with destroy. This is because the following occurs:

Without `ClusterIP` and external NLB:

`terraform apply` ✅:

1. Infra is provisioned using AWS Provider (including EKS and NLB)
2. Helm and Kubernetes Providers are used to configure the EKS Cluster (will create networking resources like NLB, Target Groups)
3. Load Balancer Controller creates load balancers and related infrastructure

`terraform destroy` ❌:

1. AWS Provider is used to destroy infra and potentially the EKS Cluster is deleted before Helm and Kubernetes is able to reset the configuration it applied to the cluster. This configuration if using `LoadBalancer` type created actual AWS infrastructure which would be orphaned in the AWS account and likely cause race conditions due to dependencies

With `ClusterIP` and external NLB:
`terraform apply` ✅:

1. Infra is provisioned using AWS Provider (including EKS and NLB)
2. Helm and Kubernetes Providers are used to configure the EKS Cluster
3. Load Balancer Controller creates load balancers and related infrastructure

`terraform destroy` ✅:

1. Helm and Kubernetes Providers are used to reset EKS configuration. There are no NLB to destroy since none were created, just associated with the exting NLB and Target Groups.
1. AWS Provider is used to destroy AWS infra and potentially the EKS Cluster is deleted before Helm and Kubernetes is able to reset the configuration it applied to the cluster. This configuration if using `LoadBalancer` type created actual AWS infrastructure which would be orphaned in the AWS account and likely cause race conditions due to dependencies

However, Unreal Cloud DDC expects NGINX and will use that networking configuration along with the default created load balancers (by load balancer controller). So to solve for this, we had to modify the configuration to use standard HTTP instead of NGINX

**Solution**: Verify NGINX is disabled in Helm values:

```bash
helm get values cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc | grep -A5 nginx
# Should show: enabled: false
```

#### 2. DDC API Connection Timeout

**Symptoms**: `curl` commands timeout or return connection refused

**Solutions**:

1. Check security group allows your IP: `curl https://checkip.amazonaws.com/`
2. Verify DNS resolution: `nslookup us-east-1.ddc.yourcompany.com`
3. Check EKS cluster status: `kubectl get nodes`

#### GitHub Container Registry Access Denied

**Symptoms**: Pod image pull failures, `ImagePullBackOff` status

**Solutions**:

1. Verify Epic Games organization membership
2. Check GitHub PAT has `packages:read` permission
3. Confirm secret is stored correctly in AWS Secrets Manager

### Debug Commands

```bash
# Check current IP
curl https://checkip.amazonaws.com/

# Test DNS resolution
nslookup us-east-1.ddc.yourcompany.com

# Configure kubectl (REQUIRED before any kubectl commands)
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check pod logs
kubectl logs -f <pod-name> -n unreal-cloud-ddc

# Check service status
kubectl get svc -n unreal-cloud-ddc
```

## User Personas

### DevOps Team (Infrastructure Provisioners)

**Responsibilities:**

- Deploy and manage DDC infrastructure
- Configure networking and security
- Handle certificates and DNS
- Monitor infrastructure health

**Access Requirements:**

- EKS API access for kubectl/Terraform
- Full access to all AWS services
- Office/VPN network access

### Game Developers (Service Consumers)

**Responsibilities:**

- Use DDC for faster asset iteration
- Configure Unreal Engine DDC settings
- Report performance issues

**Access Requirements:**

- DDC service access only (not backend infrastructure)
- Unreal Engine Editor access

## Deployment Patterns

### Single Region Deployment

**When to Use:**

- Small teams (5-20 developers)
- Co-located teams (same geographic region)
- Prototyping/MVP projects
- Budget-conscious deployments

**Benefits:**

- Lower cost (single region)
- Simpler management
- Faster deployment

### Multi-Region Deployment

**When to Use:**

- Distributed teams (US + Europe + Asia)
- Large studios (50+ developers)
- Performance-critical workflows
- Disaster recovery requirements

**Benefits:**

- Reduced latency for global teams
- Built-in disaster recovery
- Regional data compliance

## Security & Access Patterns

For detailed configuration options and deployment patterns, see the [examples](examples/) directory:

- **Single Region**: Basic deployment for small to medium teams
- **Multi-Region**: Cross-region deployment for global teams

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.16.0, < 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.14.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.33.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.11.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ddc_infra"></a> [ddc\_infra](#module\_ddc\_infra) | ./modules/ddc-infra | n/a |
| <a name="module_ddc_services"></a> [ddc\_services](#module\_ddc\_services) | ./modules/ddc-services | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lb.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.nlb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.scylla_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.scylla_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.service_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone_association.additional_vpcs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone_association) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_association.scylla_keyspace_replication_fix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.scylla_keyspace_replication_fix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_security_group_egress_rule.internal_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.nlb_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.nlb_to_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.eks_cluster_from_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.internal_scylla_cql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_from_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_http_cidrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_http_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_http_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_https_cidrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_https_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_https_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.ddc_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.bearer_token_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret_version.existing_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_vpc_associations"></a> [additional\_vpc\_associations](#input\_additional\_vpc\_associations) | Additional VPCs to associate with private zone (for cross-region access) | <pre>map(object({<br>    vpc_id = string<br>    region = string<br>  }))</pre> | `{}` | no |
| <a name="input_allowed_external_cidrs"></a> [allowed\_external\_cidrs](#input\_allowed\_external\_cidrs) | CIDR blocks for external access. Use prefix lists for multiple IPs. | `list(string)` | `[]` | no |
| <a name="input_amazon_keyspaces_config"></a> [amazon\_keyspaces\_config](#input\_amazon\_keyspaces\_config) | Amazon Keyspaces configuration for single and multi-region deployments.<br><br>    # Current Region Configuration<br>    current\_region.point\_in\_time\_recovery: Enable point-in-time recovery for tables<br><br>    # Multi-Region Configuration (Global Tables)<br>    enable\_cross\_region\_replication: Create global keyspace with multi-region replication<br>    peer\_regions: List of regions for global table replication<br><br>    # Example Single Region:<br>    amazon\_keyspaces\_config = {<br>      current\_region = {<br>        point\_in\_time\_recovery = false<br>      }<br>    }<br><br>    # Example Multi-Region (Global Tables):<br>    amazon\_keyspaces\_config = {<br>      enable\_cross\_region\_replication = true<br>      peer\_regions = ["us-west-2"]<br>      current\_region = {<br>        point\_in\_time\_recovery = true<br>      }<br>    } | <pre>object({<br>    current_region = object({<br>      point_in_time_recovery = optional(bool, false)<br>    })<br>    <br>    # Global tables for multi-region (like Secrets Manager replication)<br>    enable_cross_region_replication = optional(bool, false)<br>    peer_regions = optional(list(string), [])<br>  })</pre> | `null` | no |
| <a name="input_auto_cleanup_status_messages"></a> [auto\_cleanup\_status\_messages](#input\_auto\_cleanup\_status\_messages) | Show progress messages during cleanup operations with [DDC CLEANUP - COMPONENT]: format | `bool` | `true` | no |
| <a name="input_auto_cleanup_timeout"></a> [auto\_cleanup\_timeout](#input\_auto\_cleanup\_timeout) | Timeout in seconds for auto cleanup operations during destroy (Helm, TGB, etc.) | `number` | `300` | no |
| <a name="input_bearer_token_replica_regions"></a> [bearer\_token\_replica\_regions](#input\_bearer\_token\_replica\_regions) | List of AWS regions to replicate the bearer token secret to for multi-region access | `list(string)` | `[]` | no |
| <a name="input_centralized_logging"></a> [centralized\_logging](#input\_centralized\_logging) | Centralized logging configuration for DDC components by category.<br><br>IMPORTANT: This module only supports specific predefined components. Adding unsupported <br>components will result in log groups being created but no actual log shipping configured.<br><br>## Supported Components by Category:<br><br>### infrastructure (AWS managed services):<br>- "nlb" - Network Load Balancer access logs → S3 + CloudWatch<br>- "eks" - EKS control plane logs → CloudWatch<br><br>### application (Primary business logic):<br>- "ddc" - DDC application pod logs → CloudWatch (via Fluent Bit)<br><br>### service (Supporting services):<br>- "scylla" - ScyllaDB database logs → CloudWatch (via CloudWatch agent)<br><br>## Structure:<br>Log groups follow the pattern: {log\_group\_prefix}/{category}/{component}<br>- Default prefix: "{project\_prefix}-{service\_name}-{region}"<br>- Example: "cgd-unreal-cloud-ddc-us-east-1/infrastructure/nlb"<br><br>## Configuration:<br>- enabled: Enable/disable logging for this component (default: true)<br>- retention\_days: CloudWatch log retention in days (defaults: infra=90, app=30, service=60)<br>- log\_group\_prefix: Custom prefix to replace default naming (optional)<br><br>## Examples:<br><br># Enable all supported components with defaults<br>centralized\_logging = {<br>  infrastructure = { nlb = {}, eks = {} }<br>  application    = { ddc = {} }<br>  service        = { scylla = {} }<br>}<br><br># Custom retention and prefix<br>centralized\_logging = {<br>  infrastructure = { <br>    nlb = { retention\_days = 365 }<br>    eks = { retention\_days = 180 }<br>  }<br>  application = { <br>    ddc = { retention\_days = 14 }<br>  }<br>  service = { <br>    scylla = { retention\_days = 90 }<br>  }<br>  log\_group\_prefix = "mycompany-ddc-prod"<br>}<br><br># Disable specific components<br>centralized\_logging = {<br>  infrastructure = { <br>    nlb = { enabled = false }  # Disable NLB logging<br>    eks = {}                   # Enable EKS logging<br>  }<br>  application = { ddc = {} }<br>  service     = { scylla = {} }<br>}<br><br>## Cost Considerations:<br>- Shorter retention = lower costs<br>- infrastructure logs (90 days default) - needed for troubleshooting<br>- application logs (30 days default) - balance between debugging and cost<br>- service logs (60 days default) - database analysis and performance tuning<br><br>## Security:<br>All log groups are created with proper IAM permissions and encryption.<br>S3 bucket includes lifecycle policies for cost optimization. | <pre>object({<br>    infrastructure = optional(map(object({<br>      enabled        = optional(bool, true)<br>      retention_days = optional(number, 90)<br>    })), {})<br>    application = optional(map(object({<br>      enabled        = optional(bool, true)<br>      retention_days = optional(number, 30)<br>    })), {})<br>    service = optional(map(object({<br>      enabled        = optional(bool, true)<br>      retention_days = optional(number, 60)<br>    })), {})<br>    log_group_prefix = optional(string, null)<br>  })</pre> | `null` | no |
| <a name="input_create_bearer_token"></a> [create\_bearer\_token](#input\_create\_bearer\_token) | Create new DDC bearer token secret. Set to false in secondary regions to use existing token from primary region. | `bool` | `true` | no |
| <a name="input_create_private_dns_records"></a> [create\_private\_dns\_records](#input\_create\_private\_dns\_records) | Create private DNS records (set to false for secondary regions to avoid conflicts) | `bool` | `true` | no |
| <a name="input_database_migration_mode"></a> [database\_migration\_mode](#input\_database\_migration\_mode) | Enable database migration mode to temporarily allow both Scylla and Keyspaces configurations during migration.<br><br>CRITICAL WARNINGS:<br>- Only enable during active database migration<br>- Creates both database infrastructures simultaneously (increased costs)<br>- Requires manual coordination of database\_migration\_target<br>- Must be disabled after migration completion<br>- Not intended for long-term use<br><br>MIGRATION PROCESS:<br>1. Set database\_migration\_mode = true, database\_migration\_target = "scylla"<br>2. Apply (creates both databases, DDC stays on Scylla)<br>3. Optional: Migrate data manually<br>4. Set database\_migration\_target = "keyspaces"<br>5. Apply (switches DDC to Keyspaces)<br>6. Remove old database config<br>7. Set database\_migration\_mode = false | `bool` | `false` | no |
| <a name="input_database_migration_target"></a> [database\_migration\_target](#input\_database\_migration\_target) | Target database during migration when both are configured. 'scylla' or 'keyspaces'. Only used when database\_migration\_mode = true. | `string` | `"keyspaces"` | no |
| <a name="input_ddc_application_config"></a> [ddc\_application\_config](#input\_ddc\_application\_config) | DDC application configuration including namespaces and authentication.<br><br>    # Namespaces (Map of Objects)<br>    namespaces: Map where key = namespace name, value = configuration<br><br>    Example:<br>    namespaces = {<br>      "call-of-duty" = {<br>        description = "Call of Duty franchise"<br>        prevent\_deletion = true<br>      }<br>      "overwatch" = {<br>        description = "Overwatch franchise"<br>        prevent\_deletion = true<br>      }<br>      "dev-sandbox" = {<br>        description = "Development testing"<br>        deletion\_policy = "delete"<br>      }<br>    }<br><br>    # Authentication<br>    bearer\_token\_secret\_arn: ARN of existing DDC bearer token secret. If null, creates new token. | <pre>object({<br>    namespaces = map(object({<br>      description      = optional(string, "")<br>      prevent_deletion = optional(bool, false)<br>      deletion_policy  = optional(string, "retain") # "retain" or "delete"<br>    }))<br>    bearer_token_secret_arn = optional(string, null)<br>  })</pre> | <pre>{<br>  "namespaces": {<br>    "default": {<br>      "description": "Default DDC namespace"<br>    }<br>  }<br>}</pre> | no |
| <a name="input_ddc_infra_config"></a> [ddc\_infra\_config](#input\_ddc\_infra\_config) | Configuration object for DDC infrastructure (EKS, ScyllaDB, NLB, Kubernetes resources).<br>    Set to null to skip creating infrastructure.<br><br>    # General<br>    name: "The string included in the naming of resources related to Unreal Cloud DDC. Default is 'unreal-cloud-ddc'"<br>    project\_prefix: "The project prefix for this workload. This is appended to the beginning of most resource names."<br>    environment: "The current environment (e.g. dev, prod, etc.)"<br>    region: "The AWS region to deploy to"<br>    debug: "Enable debug mode"<br>    create\_seed\_node: "Whether this region creates the ScyllaDB seed node (bootstrap node for cluster formation)"<br>    existing\_scylla\_seed: "IP of existing ScyllaDB seed node (for secondary regions)"<br><br>    # EKS Configuration<br>    kubernetes\_version: "Kubernetes version to be used by the EKS cluster."<br>    eks\_node\_group\_subnets: "A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended."<br><br>    # EKS Access Configuration<br>    eks\_cluster\_public\_access: "Enable public endpoint access to EKS API server. Default: true (allows external Terraform, CI/CD, kubectl access). Set to false for VPN-only environments."<br>    eks\_cluster\_private\_access: "Enable private endpoint access to EKS API server from within VPC. Default: true (allows internal services, CodeBuild, VPC-based access)."<br>    eks\_api\_access\_cidrs: "List of CIDR blocks allowed to access the EKS API server for kubectl commands and Terraform operations. This controls WHO can manage the Kubernetes cluster, separate from DDC service access. Examples: ['203.0.113.0/24'] for office network, ['10.0.0.0/8'] for VPN users, or ['1.2.3.4/32'] for specific IP. Empty list blocks ALL public API access. IMPORTANT: This is different from security groups which control DDC service access for game clients."<br><br>    # ScyllaDB Configuration<br>    scylla\_replication\_factor: "Number of ScyllaDB replicas (3 for primary, 2 for secondary regions)"<br>    scylla\_subnets: "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."<br>    scylla\_instance\_type: "The type and size of the Scylla instance."<br>    scylla\_architecture: "The chip architecture to use when finding the scylla image." | <pre>object({<br>    # General<br>    name           = optional(string, "unreal-cloud-ddc")<br>    project_prefix = optional(string, "cgd")<br>    environment    = optional(string, "dev")<br>    region         = optional(string, null)<br>    # debug is inherited from parent module debug_mode<br>    create_seed_node = optional(bool, true)<br>    existing_scylla_seed = optional(string, null)<br>    scylla_source_region = optional(string, null)<br><br>    # EKS Configuration<br>    kubernetes_version      = optional(string, "1.33")<br>    eks_node_group_subnets = optional(list(string), [])<br><br>    # Node Groups<br>    nvme_managed_node_instance_type   = optional(string, "i3en.large")<br>    nvme_managed_node_desired_size    = optional(number, 2)<br>    nvme_managed_node_max_size        = optional(number, 2)<br>    nvme_managed_node_min_size        = optional(number, 1)<br><br>    worker_managed_node_instance_type = optional(string, "c5.large")<br>    worker_managed_node_desired_size  = optional(number, 1)<br>    worker_managed_node_max_size      = optional(number, 1)<br>    worker_managed_node_min_size      = optional(number, 0)<br><br>    system_managed_node_instance_type = optional(string, "m5.large")<br>    system_managed_node_desired_size  = optional(number, 1)<br>    system_managed_node_max_size      = optional(number, 2)<br>    system_managed_node_min_size      = optional(number, 1)<br><br>    # ScyllaDB Configuration<br>    scylla_replication_factor         = optional(number, 3)<br>    scylla_subnets                    = optional(list(string), [])<br>    scylla_ami_name                   = optional(string, "ScyllaDB 6.0.1")<br>    scylla_instance_type              = optional(string, "i4i.2xlarge")<br>    scylla_architecture               = optional(string, "x86_64")<br>    scylla_db_storage                 = optional(number, 100)<br>    scylla_db_throughput              = optional(number, 200)<br><br>    # EKS Access Configuration<br>    eks_api_access_cidrs = optional(list(string), [])<br>    eks_cluster_public_access               = optional(bool, true)<br>    eks_cluster_private_access              = optional(bool, true)<br><br>    # Kubernetes Configuration<br>    unreal_cloud_ddc_namespace            = optional(string, "unreal-cloud-ddc")<br>    unreal_cloud_ddc_service_account_name = optional(string, "unreal-cloud-ddc-sa")<br><br>    # Certificate Management<br>    certificate_manager_hosted_zone_arn = optional(list(string), [])<br>    enable_certificate_manager          = optional(bool, false)<br><br>    # Additional Security Groups (Targeted Access)<br>    additional_nlb_security_groups = optional(list(string), [])<br>    additional_eks_security_groups = optional(list(string), [])<br><br>    # Multi-region monitoring (from cwwalb branch)<br>    scylla_ips_by_region = optional(map(list(string)), {})<br>  })</pre> | `null` | no |
| <a name="input_ddc_services_config"></a> [ddc\_services\_config](#input\_ddc\_services\_config) | Configuration object for DDC service components (Helm charts only, no AWS infrastructure).<br>    Set to null to skip deploying services.<br><br>    # General<br>    name: "The string included in the naming of resources related to Unreal Cloud DDC applications."<br>    project\_prefix: "The project prefix for this workload."<br><br>    # Application Settings<br>    unreal\_cloud\_ddc\_version: "Version of the Unreal Cloud DDC Helm chart. DEFAULT: 1.2.0 (HIGHLY RECOMMENDED). DDC 1.3.0 has known configuration parsing bugs that cause crashes. Only change if testing fixes or newer versions."<br>    unreal\_cloud\_ddc\_helm\_values: "List of YAML files for Unreal Cloud DDC"<br>    ddc\_replication\_region\_url: "URL of primary region DDC for replication (secondary regions only)"<br><br>    # Cleanup Configuration<br>    auto\_cleanup: "Automatically clean up Helm releases during destroy to prevent orphaned AWS resources (ENIs, Load Balancers). If false, manual cleanup required before destroying EKS cluster. Default: true (recommended)."<br>    remove\_tgb\_finalizers: "Remove TargetGroupBinding finalizers immediately after creation to enable single-step destroy. When enabled: Allows 'terraform destroy' to complete without manual intervention. When disabled: Requires manual TGB cleanup before destroy. Default: false."<br><br>    # Credentials<br>    ghcr\_credentials\_secret\_manager\_arn: "ARN for credentials stored in secret manager. CRITICAL: Secret name MUST be prefixed with EXACTLY 'ecr-pullthroughcache/' AND have something after the slash (e.g., 'ecr-pullthroughcache/UnrealCloudDDC'). AWS will reject secrets named just 'ecr-pullthroughcache/' or with different prefixes."<br>    oidc\_credentials\_secret\_manager\_arn: "ARN for oidc credentials stored in secret manager." | <pre>object({<br>    # General<br>    name           = optional(string, "unreal-cloud-ddc")<br>    project_prefix = optional(string, "cgd")<br>    region         = optional(string, "us-west-2")<br><br>    # Application Settings<br>    unreal_cloud_ddc_version             = optional(string, "1.2.0")  # HIGHLY RECOMMENDED: Do not change unless testing fixes<br><br>    # Multi-region replication<br>    ddc_replication_region_url = optional(string, null)<br><br>    # Cleanup Configuration<br>    auto_cleanup = optional(bool, true)<br>    remove_tgb_finalizers = optional(bool, false)<br><br>    # Credentials<br>    ghcr_credentials_secret_manager_arn = string<br>    oidc_credentials_secret_manager_arn = optional(string, null)<br>  })</pre> | `null` | no |
| <a name="input_debug_mode"></a> [debug\_mode](#input\_debug\_mode) | Debug mode for development and troubleshooting. 'enabled' allows additional debug features including HTTP access. 'disabled' enforces production security settings. | `string` | `"disabled"` | no |
| <a name="input_ecr_secret_suffix"></a> [ecr\_secret\_suffix](#input\_ecr\_secret\_suffix) | Suffix for ECR pull-through cache secret name (after 'ecr-pullthroughcache/'). Defaults to project\_prefix-name pattern. | `string` | `null` | no |
| <a name="input_enable_auto_cleanup"></a> [enable\_auto\_cleanup](#input\_enable\_auto\_cleanup) | Enable automatic cleanup of all resources during destroy (Helm releases, ECR repos, TGB finalizers) | `bool` | `true` | no |
| <a name="input_existing_certificate_arn"></a> [existing\_certificate\_arn](#input\_existing\_certificate\_arn) | ACM certificate ARN for HTTPS listeners (required for internet-facing services unless debug\_mode enabled) | `string` | `null` | no |
| <a name="input_existing_eks_security_groups"></a> [existing\_eks\_security\_groups](#input\_existing\_eks\_security\_groups) | Additional security group IDs for EKS API access | `list(string)` | `[]` | no |
| <a name="input_existing_load_balancer_security_groups"></a> [existing\_load\_balancer\_security\_groups](#input\_existing\_load\_balancer\_security\_groups) | Additional security group IDs for load balancer access | `list(string)` | `[]` | no |
| <a name="input_existing_load_balancer_subnets"></a> [existing\_load\_balancer\_subnets](#input\_existing\_load\_balancer\_subnets) | Subnets for load balancers (public for internet-facing, private for internal) | `list(string)` | n/a | yes |
| <a name="input_existing_route53_public_hosted_zone_name"></a> [existing\_route53\_public\_hosted\_zone\_name](#input\_existing\_route53\_public\_hosted\_zone\_name) | The name of the public Route53 Hosted Zone for DDC resources (e.g., 'yourcompany.com'). Creates region-specific DNS like us-east-1.ddc.yourcompany.com | `string` | `null` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | Security group IDs for general access to public services | `list(string)` | `[]` | no |
| <a name="input_existing_service_subnets"></a> [existing\_service\_subnets](#input\_existing\_service\_subnets) | Subnets for services (EKS, databases, applications) | `list(string)` | n/a | yes |
| <a name="input_existing_vpc_id"></a> [existing\_vpc\_id](#input\_existing\_vpc\_id) | VPC ID where resources will be created | `string` | n/a | yes |
| <a name="input_external_prefix_list_id"></a> [external\_prefix\_list\_id](#input\_external\_prefix\_list\_id) | Managed prefix list ID for external access (recommended for multiple IPs) | `string` | `null` | no |
| <a name="input_internet_facing"></a> [internet\_facing](#input\_internet\_facing) | Whether load balancers should be internet-facing (true) or internal (false) | `bool` | `true` | no |
| <a name="input_is_primary_region"></a> [is\_primary\_region](#input\_is\_primary\_region) | Whether this is the primary region (for future use) | `bool` | `true` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources to. If not set, uses the default region from AWS credentials/profile. For multi-region deployments, this MUST be set to a different region than the default to avoid resource conflicts and duplicates. | `string` | `null` | no |
| <a name="input_scylla_config"></a> [scylla\_config](#input\_scylla\_config) | ScyllaDB configuration for single and multi-region deployments.<br><br>    # Current Region Configuration<br>    current\_region.datacenter\_name: ScyllaDB datacenter name (auto-generated: us-east-1 → us-east)<br>    current\_region.keyspace\_suffix: Keyspace naming suffix (auto-generated: us-east-1 → us\_east\_1)<br>    current\_region.replication\_factor: Number of data copies in this region (recommended: 3)<br>    current\_region.node\_count: Number of ScyllaDB nodes in this region<br><br>    # Multi-Region Configuration<br>    peer\_regions: Map of other regions for cross-region replication<br>    enable\_cross\_region\_replication: Whether to set up cross-region data sync<br><br>    # Naming Strategy<br>    keyspace\_naming\_strategy: How to name keyspaces<br>    - "region\_suffix": jupiter\_local\_ddc\_us\_east\_1 (matches cwwalb pattern)<br>    - "datacenter\_suffix": jupiter\_local\_ddc\_us\_east<br><br>    # Example Single Region:<br>    scylla\_config = {<br>      current\_region = {<br>        replication\_factor = 3<br>        node\_count = 3<br>      }<br>    }<br><br>    # Example Multi-Region:<br>    scylla\_config = {<br>      current\_region = {<br>        replication\_factor = 3<br>        node\_count = 3<br>      }<br>      peer\_regions = {<br>        "us-west-2" = {<br>          replication\_factor = 2<br>        }<br>      }<br>    } | <pre>object({<br>    # Current region configuration<br>    current_region = object({<br>      datacenter_name       = optional(string, null)  # Auto-generated from region if null<br>      keyspace_suffix       = optional(string, null)  # Auto-generated from region if null<br>      replication_factor    = optional(number, 3)<br>      node_count           = optional(number, 3)<br>    })<br><br>    # Multi-region peer configuration (for replication setup)<br>    peer_regions = optional(map(object({<br>      datacenter_name    = optional(string, null)  # Auto-generated from region if null<br>      replication_factor = optional(number, 2)<br>    })), {})<br><br>    # Advanced options<br>    enable_cross_region_replication = optional(bool, true)<br>    keyspace_naming_strategy       = optional(string, "region_suffix")  # "region_suffix" or "datacenter_suffix"<br>  })</pre> | `null` | no |
| <a name="input_ssm_retry_config"></a> [ssm\_retry\_config](#input\_ssm\_retry\_config) | SSM automation retry configuration for DDC keyspace initialization.<br><br>    max\_attempts: Maximum retry attempts to check for DDC readiness (default: 20 = 10 minutes)<br>    retry\_interval\_seconds: Seconds between retry attempts (default: 30)<br>    initial\_delay\_seconds: Initial delay before first check (default: 60)<br><br>    Total timeout: initial\_delay + (max\_attempts * retry\_interval)<br>    Default: 60s + (20 * 30s) = 660s (11 minutes) | <pre>object({<br>    max_attempts           = optional(number, 20)<br>    retry_interval_seconds = optional(number, 30)<br>    initial_delay_seconds  = optional(number, 60)<br>  })</pre> | <pre>{<br>  "initial_delay_seconds": 60,<br>  "max_attempts": 20,<br>  "retry_interval_seconds": 30<br>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IaC": "Terraform",<br>  "ModuleBy": "CGD-Toolkit",<br>  "ModuleName": "terraform-aws-unreal-cloud-ddc",<br>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc",<br>  "RootModuleName": "-"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_logs"></a> [access\_logs](#output\_access\_logs) | Access logs configuration |
| <a name="output_bearer_token_secret_arn"></a> [bearer\_token\_secret\_arn](#output\_bearer\_token\_secret\_arn) | ARN of the DDC bearer token secret |
| <a name="output_ddc_connection"></a> [ddc\_connection](#output\_ddc\_connection) | DDC connection information for this region |
| <a name="output_ddc_infra"></a> [ddc\_infra](#output\_ddc\_infra) | DDC infrastructure outputs |
| <a name="output_ddc_namespaces"></a> [ddc\_namespaces](#output\_ddc\_namespaces) | DDC namespace configuration |
| <a name="output_ddc_services"></a> [ddc\_services](#output\_ddc\_services) | DDC services outputs |
| <a name="output_dns_endpoints"></a> [dns\_endpoints](#output\_dns\_endpoints) | DNS endpoints for DDC services |
| <a name="output_internet_facing"></a> [internet\_facing](#output\_internet\_facing) | Whether load balancers are internet-facing or internal |
| <a name="output_kubectl_command"></a> [kubectl\_command](#output\_kubectl\_command) | kubectl command to connect to EKS cluster |
| <a name="output_load_balancers"></a> [load\_balancers](#output\_load\_balancers) | Load balancer information |
| <a name="output_module_info"></a> [module\_info](#output\_module\_info) | Module metadata and configuration summary |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | NLB DNS name |
| <a name="output_nlb_zone_id"></a> [nlb\_zone\_id](#output\_nlb\_zone\_id) | NLB zone ID |
| <a name="output_private_zone_name"></a> [private\_zone\_name](#output\_private\_zone\_name) | Private hosted zone name |
| <a name="output_scylla_alter_commands"></a> [scylla\_alter\_commands](#output\_scylla\_alter\_commands) | Generated ALTER commands for ScyllaDB keyspace replication |
| <a name="output_scylla_configuration"></a> [scylla\_configuration](#output\_scylla\_configuration) | ScyllaDB configuration details for debugging and validation |
| <a name="output_scylla_connection_info"></a> [scylla\_connection\_info](#output\_scylla\_connection\_info) | ScyllaDB connection information |
| <a name="output_security_groups"></a> [security\_groups](#output\_security\_groups) | Security group IDs created by this module |
| <a name="output_shared_private_zone_id"></a> [shared\_private\_zone\_id](#output\_shared\_private\_zone\_id) | Private hosted zone ID for cross-region DNS sharing |
| <a name="output_ssm_automation"></a> [ssm\_automation](#output\_ssm\_automation) | SSM automation configuration for keyspace fixes |
| <a name="output_version_info"></a> [version\_info](#output\_version\_info) | Version information for multi-region consistency checks |
<!-- END_TF_DOCS -->

## Contributing

See the [Contributing Guidelines](../../../CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../../../LICENSE) file for details.
