# Unreal Cloud DDC (Derived Data Cache) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **⚠️ IMPORTANT**
>
> **You MUST have Epic Games GitHub organization access to use this module.** Without access, container image pulls will fail and deployment will not work. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) to join the organization before proceeding.
>
> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

## Features

- **Complete DDC Infrastructure** - Single module deploys EKS cluster, ScyllaDB database, S3 storage, and load balancers
- **ScyllaDB Database** - High-performance, self-managed database with full configuration control
- **Multi-Region Support** - Cross-region replication with automatic datacenter configuration
- **Security by Default** - Private subnets, least privilege IAM, restricted network access
- **Flexible Access Patterns** - External (internet) or internal (VPC-only) access patterns
- **Regional DNS Endpoints** - e.g. `<region>.ddc.example.com` pattern for optimal routing
- **Automatic Keyspace Management** - SSM automation fixes DDC replication strategy issues
- **Container Integration** - Direct GHCR access for Epic Games container images

## User Personas

| User Type            | Responsibilities                                         | Access Requirements                | Tools Needed                       |
| -------------------- | -------------------------------------------------------- | ---------------------------------- | ---------------------------------- |
| **DevOps Engineers** | Deploy infrastructure, manage EKS clusters, troubleshoot | AWS CLI, kubectl, Terraform access | AWS credentials, Epic Games access |
| **Game Developers**  | Configure UE clients, use DDC endpoints                  | DDC endpoints, bearer tokens       | Unreal Engine, network access      |
| **Build Engineers**  | Integrate with CI/CD pipelines                           | DDC endpoints, automation access   | CI/CD tools, DDC credentials       |

## Prerequisites

### Required Tools & Access

#### Local Development Prerequisites

**Required Tools** (must be installed locally):

1. **AWS CLI** (v2.12.3+): For EKS authentication and resource management
2. **kubectl** (cluster version ±1): Kubernetes API client
3. **Helm** (v3.0+): Package manager for Kubernetes
4. **jq**: JSON processing (for GHCR credential extraction)
5. **Terraform** (v1.11+): Infrastructure as Code

**Installation**:

```bash
# macOS
brew install awscli kubectl helm jq terraform

# Linux (Ubuntu/Debian)
sudo apt-get install awscli kubectl helm jq
# Install Terraform separately: https://developer.hashicorp.com/terraform/install

# Windows (requires WSL or Git Bash)
choco install awscli kubernetes-cli kubernetes-helm jq terraform
```

**⚠️ Windows Prerequisites**:

**WSL2 or Git Bash Required**: Windows users must use WSL2 or Git Bash for:

- DDC application deployment (Terraform local-exec provisioners use bash)
- DDC functional testing scripts
- Manual kubectl/helm operations

#### Epic Games Access (CRITICAL ⚠️)

1. **Epic Games GitHub Organization Access**

   - Must be member of Epic Games GitHub organization
   - Required to pull DDC container images
   - Follow [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)

2. **GitHub Container Registry Access**
   - GitHub Personal Access Token with `packages:read` permission
   - Token stored in AWS Secrets Manager

#### AWS Infrastructure Prerequisites

3. **AWS Account Setup**

   - AWS CLI configured with deployment permissions
   - Route53 hosted zone for DNS records
   - VPC with public and private subnets

4. **Network Planning**
   - Office/VPN IP ranges for security group access
   - VPC CIDR planning for multi-region deployments

### Authentication Setup

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

**Store credentials in AWS Secrets Manager:**

```sh
aws secretsmanager create-secret \
  --name "github-ddc-credentials" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

## Architecture

**Core Components:**

- **EKS Cluster**: Kubernetes cluster with EKS Auto Mode for automatic node provisioning
- **ScyllaDB Database**: High-performance, self-managed database for DDC metadata
- **S3 Bucket**: Object storage for cached game assets
- **Network Load Balancer**: External access with regional DNS endpoints
- **Route53 Private Hosted Zone**: DNS for internal routing between services
- **Private Subnets**: All compute resources deployed privately for security
- **CodeBuild Projects**: Automated infrastructure setup and application deployment

### Terraform Actions Architecture

**The module uses [Terraform Actions](https://www.hashicorp.com/en/blog/day-2-infrastructure-management-with-terraform-actions) for reliable Kubernetes operations:**

```
Terraform Orchestration (Synchronous)
├── 1. AWS Resources
│   ├── EKS Cluster ✅
│   ├── ScyllaDB ✅
│   ├── IAM Roles ✅
│   └── CodeBuild Projects ✅
├── 2. Terraform Actions (Synchronous CodeBuild Execution)
│   ├── AWS Load Balancer Controller ✅
│   ├── Custom NodePools ✅
│   ├── Cert Manager (optional) ✅
│   ├── DDC Helm Deployment ✅
│   └── Functional Testing ✅
└── 3. Complete ✅
```

**Key Benefits:**
- **Synchronous execution**: Terraform waits for each CodeBuild operation to complete
- **No race conditions**: EKS cluster setup completes before application deployment
- **No permission chicken-and-egg problems**: CodeBuild has proper IAM roles from the start
- **Single terraform apply**: Everything happens in one coordinated workflow
- **Reliable**: Consistent CodeBuild environment vs. local machine dependencies
- **CI/CD friendly**: Works in pipelines without kubectl/helm installation

### Custom Helm Chart Architecture

**CGD Toolkit uses a custom wrapper chart to make Epic Games' DDC chart compatible with EKS Auto Mode:**

```
CGD Toolkit Wrapper Chart (ddc-wrapper/)
├── charts/
│   └── unreal-cloud-ddc-1.2.0+helm.tgz    # Epic's original chart (embedded)
└── templates/
    └── deployment-override.yaml            # Our custom override for EKS Auto Mode
```

**Why This Architecture:**

- **Epic's Chart**: Designed for manual node groups with custom AMIs that mount NVMe at `/data`
- **EKS Auto Mode**: Automatically mounts NVMe drives at `/mnt/.ephemeral` using Bottlerocket OS
- **Our Override**: Fixes the hostPath from `/data` to `/mnt/.ephemeral` for compatibility

**Critical NVMe Requirements:**

⚠️ **ONLY NVMe instance types are supported** (i4i, i3, i3en, etc.)

- **EKS Auto Mode**: Automatically formats and mounts NVMe drives at `/mnt/.ephemeral`
- **Bottlerocket OS**: Uses read-only root filesystem, cannot create `/data` directory
- **DDC Performance**: Requires high-speed NVMe storage for optimal cache performance
- **Instance Validation**: Terraform enforces NVMe-only instance families via validation rules

**What Our Override Does:**

```yaml
# Epic's original (doesn't work with EKS Auto Mode)
volumes:
  - name: nvme-cache
    hostPath:
      path: /data                    # ❌ Cannot create on read-only filesystem
      type: DirectoryOrCreate

# Our override (works with EKS Auto Mode)
volumes:
  - name: nvme-cache
    hostPath:
      path: /mnt/.ephemeral          # ✅ Where EKS Auto Mode mounts NVMe
      type: DirectoryOrCreate
```

**Migration Context:**

This override was necessary when migrating from:

- **Before**: Manual node groups + custom AMIs + user data scripts mounting NVMe at `/data`
- **After**: EKS Auto Mode + Bottlerocket OS + automatic NVMe mounting at `/mnt/.ephemeral`

Without this override, DDC pods fail with `mkdir /data: read-only file system` errors.

### EKS Auto Mode Compute Architecture

**Application-Driven Infrastructure:**

With EKS Auto Mode, **the DDC application requests infrastructure** (not Terraform):

- **No Terraform instance config**: EKS Auto Mode handles everything automatically
- **Pod requirements drive nodes**: Application specifies needs via nodeSelector and resource requests
- **Karpenter provisions nodes**: Reads pod requirements, creates matching EC2 instances on-demand
- **NVMe instance enforcement**: Custom NodePool restricts to NVMe families only

**NodePool Architecture:**

```
EKS Auto Mode
├── Default NodePools (c, m, r families)
│   └── ❌ No NVMe storage → DDC pods fail to schedule
└── Custom NodePool (i family only)
    └── ✅ NVMe storage → DDC pods schedule successfully
```

**Why Custom NodePool is Required:**

- **Default EKS Auto Mode**: Only supports `[c, m, r]` instance families (no NVMe)
- **DDC Requirements**: Needs NVMe storage for cache performance
- **Our Solution**: Custom NodePool that allows `[i]` family (NVMe instances)
- **Automatic Provisioning**: When DDC pods request `i4i.xlarge`, EKS Auto Mode creates them

### Single Region Architecture

![Single Region Architecture](./assets/media/diagrams/unreal-cloud-ddc-single-region-arch.png)

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

![Multi-Region Architecture](./assets/media/diagrams/unreal-cloud-ddc-multi-region-arch.png)

#### Traffic Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US East       │───▶│us-east-1.ddc... │───▶│ EKS us-east-1   │
│  Game Devs      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐  │
│   US West       │───▶│us-west-2.ddc... │───▶│ EKS us-west-2   │◀─┐
│  Game Devs      │    │                  │    │                 │  │
└─────────────────┘    └──────────────────┘    └─────────────────┘  │
                                                         │           │
                                               ┌─────────────────┐  │
                                               │   ScyllaDB      │──┘
                                               │  Multi-Region   │
                                               └─────────────────┘
```

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples). They provide complete Terraform configurations with VPC setup, security groups, and detailed connection instructions.

**Available Examples:**

- **[Single Region](examples/hybrid/single-region/)** - Basic deployment for most use cases, development environments
- **[Multi-Region](examples/hybrid/multi-region/)** - Global teams with cross-region replication, production with disaster recovery

**Access Configuration:** Examples use both public and private EKS API endpoints which supports flexible access patterns through simple configuration changes.

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/aws-games/cloud-game-development-toolkit.git
cd cloud-game-development-toolkit
```

### 2. Set Up Epic Games Access

Follow the [Prerequisites](#authentication-setup) section to:

- Join Epic Games GitHub organization
- Create GitHub Personal Access Token
- Store credentials in AWS Secrets Manager

### 3. Deploy Example

```bash
cd modules/unreal/unreal-cloud-ddc/examples/hybrid/single-region/
terraform init
terraform plan
terraform apply
```

### 4. Get Connection Info

```bash
terraform output
```

### 5. Configure Unreal Engine

Add to your project's `Config/DefaultEngine.ini`:

```ini
[DDC]
; Production configuration
Cloud=(Type=HTTPDerivedDataBackend, Host="<DDC_ENDPOINT_FROM_OUTPUT>")

; Optional: Local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)

; Hierarchical setup (try cloud first, then local)
Hierarchical=(Type=Hierarchical, Inner=Cloud, Inner=Local)
```

## Access Patterns

As outlined in the [general modules documentation](../README.md#access-patterns), CGD Toolkit modules follow standard access patterns. This module supports three access patterns with corresponding protocol strategies:

### **Private Access Pattern** - HTTP Internal (Recommended)

- **Infrastructure**: All services accessible only within VPC (requires VPN/Direct Connect)
- **Protocol**: HTTP (Epic Games approved for trusted networks)
- **DNS**: Internal only (`us-east-1.dev.ddc.cgd.internal`)
- **Certificates**: None required
- **Cost**: $0 for certificates
- **Configuration**: `internet_facing = false`, no `certificate_arn`

### **Hybrid Access Pattern** - HTTPS Split-Horizon

- **Infrastructure**: Public requests transition to private infrastructure
- **Protocol**: HTTPS (required for internet-facing components)
- **DNS**: Split-horizon (`us-east-1.dev.ddc.example.com` for both public and private)
- **Certificates**: Free ACM Public certificates
- **Cost**: $0 for certificates (requires public hosted zone)
- **Configuration**: `internet_facing = true`, `certificate_arn` provided

### **Public Access Pattern** - HTTPS Public

- **Infrastructure**: Fully internet-accessible services
- **Protocol**: HTTPS (required for internet traffic)
- **DNS**: Public only (`us-east-1.dev.ddc.example.com`)
- **Certificates**: Free ACM Public certificates
- **Cost**: $0 for certificates
- **Configuration**: `internet_facing = true`, public DNS records

### **HTTPS for Internal-Only Deployments**

If you require HTTPS for internal-only traffic (Private Access Pattern), you have two options:

#### **Option 1: Split-Horizon DNS** (Easier)

- **Requirement**: Public hosted zone for DNS validation
- **Setup**: Use hybrid pattern with internal-only load balancer
- **Certificates**: Free ACM Public certificates
- **DNS**: Same domain for public validation, private resolution
- **Cost**: $0 for certificates

#### **Option 2: Private Certificate Authority** (More Complex)

- **Requirement**: AWS Private CA or self-managed CA
- **Setup**: Internal certificates for `.internal` domains
- **Certificates**: Private CA issued certificates
- **DNS**: Pure internal DNS (`us-east-1.dev.ddc.cgd.internal`)
- **Cost**: ~$400/month for AWS Private CA

**Recommendation**: For most internal-only use cases, HTTP is sufficient and follows Epic Games' documented approach for trusted networks.

### EKS Access Pattern Nuances

**This module uses EKS, which creates some nuances in how these access patterns apply.** EKS is different from other AWS services because it's essentially a "hybrid service" by design:

- **Control Plane**: AWS-managed service (like S3) with public/private API endpoints
- **Data Plane**: Your EC2 nodes and pods running in your VPC subnets
- **Network Overlay**: Kubernetes networking that spans both AWS-managed and customer-managed components

This dual nature means the standard CGD Toolkit access patterns don't map perfectly to EKS. **EKS networking can be complicated** - we recommend reviewing the [AWS EKS Networking Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html) and [EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/network/) for comprehensive understanding.

**Important**: Don't be confused by EKS having both public and private API access enabled in hybrid mode - this is standard practice and doesn't violate the hybrid pattern. The EKS API is an AWS service (like S3), while your DDC application follows the hybrid pattern (public access transitioning to private infrastructure).

### EKS API Access Configuration

This module exposes EKS API access settings directly (no abstraction). Configure exactly like the AWS provider:

```hcl
ddc_infra_config = {
  # EKS API Access (matches AWS provider exactly)
  endpoint_public_access  = true                    # Internet access to EKS API
  endpoint_private_access = true                    # VPC access to EKS API
  public_access_cidrs     = ["203.0.113.0/24"]     # Restrict internet access
}
```

#### **Key Points:**

- **Public access**: EKS API accessible from internet (controlled by `public_access_cidrs`)
- **Private access**: EKS API accessible from VPC (no CIDR restrictions needed)
- **Both enabled**: Same API endpoint works from internet AND VPC
- **EKS API ≠ DDC service**: EKS API is an AWS service (like S3), secured by IAM + optional CIDRs

#### **Common Patterns:**

| Pattern           | Public  | Private | CIDRs             | Load Balancer             | Use Case         |
| ----------------- | ------- | ------- | ----------------- | ------------------------- | ---------------- |
| **Development**   | `true`  | `false` | `["0.0.0.0/0"]`   | `internet_facing = true`  | Easy access      |
| **Production**    | `true`  | `true`  | `["office-cidr"]` | `internet_facing = true`  | Restricted + VPC |
| **High Security** | `false` | `true`  | `null`            | `internet_facing = false` | VPC-only         |

#### **Fully Private Configuration:**

For complete private connectivity (VPC-only access):

```hcl
# EKS API - Private only
ddc_infra_config = {
  endpoint_public_access  = false  # No internet access to EKS API
  endpoint_private_access = true   # VPC access only
  public_access_cidrs     = null   # Not needed for private-only
}

# Load Balancer - Internal only
load_balancers_config = {
  nlb = {
    internet_facing = false         # Internal load balancer
    subnets         = aws_subnet.private_subnets[*].id  # Private subnets
  }
}
```

**Requirements for private-only:**

- VPN or Direct Connect for external access
- Private subnets for load balancer
- NAT Gateway for outbound internet (container pulls, etc.)
- VPC endpoints for AWS services (optional but recommended)

> **Learn More:**
>
> - [AWS EKS Networking](https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html)
> - [EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/network/)
> - [Terraform aws_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)

> **Note**: The DDC service (your application) and EKS API (AWS service) have separate access controls. Configure each based on your security requirements.

### Single Region Architecture

![Single Region Architecture](./assets/media/diagrams/unreal-cloud-ddc-single-region-arch.png)

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

![Multi-Region Architecture](./assets/media/diagrams/unreal-cloud-ddc-multi-region-arch.png)

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

## Authentication & Access Control

### EKS Cluster Access (Three-Layer Security)

EKS requires **three layers of security** for cluster management:

1. **Network Layer**: IP allowlist (`public_access_cidrs`) - controls who can reach the EKS API server
2. **Authentication**: AWS IAM - verifies who you are
3. **Authorization**: EKS access entries - defines what you can do in the cluster

### Cluster Creator Automatic Access

**Important**: The IAM principal that creates the EKS cluster automatically receives cluster admin permissions via `bootstrapClusterCreatorAdminPermissions=true` (default behavior).

**Implications:**

- The cluster creator can run kubectl commands without additional configuration
- CI/CD pipelines work automatically if they use the same IAM role that created the cluster
- No additional EKS access entries are required for the cluster creator

**EKS access entries are only required for:**

- Additional developers who need kubectl access
- Secondary CI/CD systems (ArgoCD, separate deployment pipelines)
- Operations teams for troubleshooting
- Service accounts for automated tools

**Common CI/CD Pattern (No Access Entries Needed):**

```yaml
# GitHub Actions using same role for create + manage
- name: Deploy Infrastructure
  run: |
    terraform apply  # Creates cluster, gets automatic admin access
    kubectl get pods # Works automatically, no additional config needed
```

### Two Separate Authentication Systems

#### 1. EKS Cluster Management (Additional Users Beyond Creator)

**Only needed for users OTHER than the cluster creator:**

```hcl
eks_access_entries = {
  "developers" = {
    principal_arn = "arn:aws:iam::123456789012:role/DeveloperRole"
    policy_associations = [{
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      access_scope = { type = "cluster" }
    }]
  }
  "cicd_secondary" = {
    principal_arn = "arn:aws:iam::123456789012:role/ArgoCD-Role"
    policy_associations = [{
      policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = { type = "cluster" }
    }]
  }
}
```

**Note**: The cluster creator (you or your CI/CD role) gets automatic admin access and doesn't need an explicit access entry.

#### 2. DDC Application Authentication (Unreal Engine clients, build systems)

Managed via ConfigMap containing DDC bearer tokens - completely separate from EKS cluster access.

### kubeconfig Setup

**We don't create kubeconfig** - the `aws eks update-kubeconfig` command creates and continuously updates it:

```bash
# Each user runs this with their own AWS credentials
aws eks update-kubeconfig --region us-east-1 --name my-cluster
kubectl get pods  # Uses their IAM permissions + EKS access entries
```

- **Temporary credentials**: Uses AWS IAM, refreshed automatically (15-minute tokens)
- **No long-term secrets**: Safe to regenerate anytime
- **Local file**: `~/.kube/config` on developer machine

## Compute Configuration (EKS Auto Mode)

### Application-Driven Infrastructure

With EKS Auto Mode, **the application requests infrastructure** (not Terraform):

- **No Terraform instance config**: EKS Auto Mode handles everything
- **Pod requirements drive nodes**: Application specifies needs via `ddc_application_config.compute`
- **Karpenter provisions nodes**: Reads pod requirements, creates matching EC2 instances on-demand
- **On-demand scaling**: Nodes created only when pods need them

```hcl
ddc_application_config = {
  compute = {
    instance_type    = "i4i.xlarge"  # NVMe for performance
    cpu_requests     = "2000m"       # 2 CPU cores per pod
    memory_requests  = "8Gi"         # 8GB RAM per pod
    replica_count    = 2             # Number of replicas
  }
}
```

### Destructive Changes

| Change            | Impact               | Recommendation          |
| ----------------- | -------------------- | ----------------------- |
| `instance_type`   | **Node replacement** | Plan maintenance window |
| `cpu_requests`    | **Maybe new nodes**  | Test in dev first       |
| `memory_requests` | **Maybe new nodes**  | Test in dev first       |
| `replica_count`   | **Pod scaling only** | Safe to change          |

**Terraform apply behavior**: Helm upgrade → pod rescheduling → EKS Auto Mode creates new nodes → old nodes drained

**Backup strategy**: `kubectl get all -n unreal-cloud-ddc -o yaml > backup.yaml`

**Advanced deployment patterns**: See [AWS EKS Blue/Green documentation](https://docs.aws.amazon.com/eks/latest/userguide/blue-green.html)

## Prerequisites

### Required Tools & Access

#### Local Development Prerequisites

**Required Tools** (must be installed locally):

1. **AWS CLI** (v2.12.3+): For EKS authentication and resource management
2. **kubectl** (cluster version ±1): Kubernetes API client
3. **Helm** (v3.0+): Package manager for Kubernetes
4. **jq**: JSON processing (for GHCR credential extraction)
5. **Terraform** (v1.11+): Infrastructure as Code

**Installation**:

```bash
# macOS
brew install awscli kubectl helm jq terraform

# Linux (Ubuntu/Debian)
sudo apt-get install awscli kubectl helm jq
# Install Terraform separately: https://developer.hashicorp.com/terraform/install

# Windows (requires WSL or Git Bash)
choco install awscli kubernetes-cli kubernetes-helm jq terraform
```

**⚠️ Windows Prerequisites**:

**WSL2 or Git Bash Required**: Windows users must use WSL2 or Git Bash for:

- DDC application deployment (Terraform local-exec provisioners use bash)
- DDC functional testing scripts
- Manual kubectl/helm operations

**Infrastructure Only**: Windows Command Prompt/PowerShell can deploy infrastructure (EKS, NLB, ScyllaDB) but cannot deploy DDC applications without bash support.

**AWS Credentials**: Must be configured via:

- `aws configure` (access keys)
- IAM roles (EC2 instance profiles, EKS service accounts)
- AWS SSO (`aws sso login`)

#### Epic Games Access (CRITICAL ⚠️)

1. **Epic Games GitHub Organization Access**

   - Must be member of Epic Games GitHub organization
   - Required to pull DDC container images
   - Follow [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)

2. **GitHub Container Registry Access**
   - GitHub Personal Access Token with `packages:read` permission
   - Token stored in AWS Secrets Manager

#### AWS Infrastructure Prerequisites

3. **AWS Account Setup**

   - AWS CLI configured with deployment permissions
   - Route53 hosted zone for DNS records
   - VPC with public and private subnets

4. **EKS Auto Mode Subnet Tagging (REQUIRED)**

   **⚠️ CRITICAL**: EKS Auto Mode requires specific subnet tags for load balancer creation. **The examples already include these tags**, but if you're using existing subnets, verify they have the required tags:

   **Required Tags:**
   - **Public subnets**: `kubernetes.io/role/elb = "1"` (internet-facing load balancers)
   - **Private subnets**: `kubernetes.io/role/internal-elb = "1"` (internal load balancers)
   - **All subnets**: `kubernetes.io/cluster/<cluster-name> = "owned"` (EKS cluster ownership)

   **✅ Examples Already Configured**: All examples in this module include the correct subnet tags automatically.

   **If Using Existing Subnets**, verify tags are present:

   ```bash
   # Check existing subnet tags
   aws ec2 describe-subnets --subnet-ids subnet-12345 --query 'Subnets[0].Tags'
   
   # Add missing tags if needed
   aws ec2 create-tags --resources subnet-12345 \
     --tags Key=kubernetes.io/role/elb,Value=1 \
            Key=kubernetes.io/cluster/my-cluster-name,Value=owned
   ```

   **Why Required**: EKS Auto Mode uses these tags to determine which subnets are eligible for different types of load balancers. Without proper tagging, load balancer creation will fail with subnet selection errors.

   **Tag Architecture**:
   ```
   Public Subnets (internet-facing LBs):
   ├── kubernetes.io/role/elb = "1"                    # EKS Auto Mode discovery
   ├── kubernetes.io/cluster/<cluster-name> = "owned"  # EKS cluster ownership
   └── Name = "project-public-subnet-1"                # Human identification
   
   Private Subnets (internal LBs):
   ├── kubernetes.io/role/internal-elb = "1"           # EKS Auto Mode discovery  
   ├── kubernetes.io/cluster/<cluster-name> = "owned"  # EKS cluster ownership
   └── Name = "project-private-subnet-1"               # Human identification
   ```

5. **Network Planning**
   - Office/VPN IP ranges for security group access
   - VPC CIDR planning for multi-region deployments

#### CI/CD Pipeline Prerequisites

**Container-based Approach** (recommended):

```yaml
# GitHub Actions example
jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: amazon/aws-cli:latest
    steps:
      - name: Install tools
        run: |
          # Install kubectl
          curl -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl
          chmod +x kubectl && mv kubectl /usr/local/bin/

          # Install Helm
          curl -fsSL https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar -xz
          mv linux-amd64/helm /usr/local/bin/

          # Install Terraform
          wget https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_amd64.zip
          unzip terraform_1.11.0_linux_amd64.zip && mv terraform /usr/local/bin/
      - name: Deploy
        run: |
          aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
          terraform init && terraform apply -auto-approve
```

**Why Container Approach**:

- **Consistent environment**: Same tools/versions every run
- **No persistent state**: Fresh environment each pipeline run
- **Faster startup**: Pre-built images with tools installed
- **Version control**: Pin exact tool versions

### Authentication Setup

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

```sh
aws secretsmanager create-secret \
  --name "github-ddc-credentials" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

> **ℹ️ Multi-Region Note**
>
> **For single-region deployments:** Create the secret in your deployment region.
>
> **For multi-region deployments:** Create the secret in your primary region, then manually replicate it to secondary regions using the AWS Console:
>
> 1. Go to AWS Secrets Manager Console
> 2. Find your secret (e.g., `github-ddc-credentials`)
> 3. Click "Replicate secret"
> 4. Select target regions
> 5. Confirm replication
>
> This is simpler than creating separate secrets in each region and ensures consistency.

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples). They provide a good reference for not only the ways to declare and customize the module configuration, but how to provision and reference the infrastructure mentioned in the prerequisites. As mentioned earlier, we avoid creating infrastructure that is more general (e.g. VPCs, Subnets, Security Groups, etc.) as this can be highly nuanced . All examples show sample configurations of these resources created external to the module, but please customize based on your own needs.

This module provides examples for different deployment scenarios:

- **[Single Region](examples/hybrid/single-region/)** - Basic deployment for most use cases
- **[Multi-Region](examples/hybrid/multi-region/)** - Global teams with cross-region replication

**Access Configuration:** Examples use both public and private EKS API endpoints which supports flexible access patterns through simple configuration changes. See the EKS API Access section for customization options.

## Single-Region Deployment Instructions

### Step 1: Declare and configure the module

Note, this is just a condensed sample. See the examples for the related required infrastructure.

**Single Region Example (Hybrid Access)**

```terraform
module "unreal_cloud_ddc" {
  source = "../../.."

  # Core Infrastructure
  project_prefix           = "cgd"
  vpc_id                   = aws_vpc.unreal_cloud_ddc_vpc.id
  certificate_arn          = aws_acm_certificate.ddc.arn
  route53_hosted_zone_name = var.route53_public_hosted_zone_name

  # Load Balancer Configuration
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.public_subnets[*].id
    }
  }

  # Security
  allowed_external_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]

  # DDC Application Configuration
  ddc_application_config = {
    ddc_namespaces = {
      "project1" = {
        description = "Main project"
      }
      "project2" = {
        description = "Secondary project"
      }
    }
  }

  # DDC Infrastructure Configuration
  ddc_infra_config = {
    region                 = "us-east-1"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id

    # EKS API Access Configuration (hybrid)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["${chomp(data.http.my_ip.response_body)}/32"]

    # ScyllaDB Configuration
    scylla_config = {
      current_region = {
        replication_factor = 3
      }
      subnets = aws_subnet.private_subnets[*].id
    }
  }

  # GHCR Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn

  # Centralized Logging
  enable_centralized_logging = true
  log_retention_days         = 30
}
```

### Step 2: Deploy Infrastructure

> **⚠️ IMPORTANT**
>
> This module creates **internet-accessible** services by default. Review security configurations and restrict access to your organization's IP ranges before deployment.

Initialize Terraform:

```sh
terraform init
```

Review planned changes:

```sh
terraform plan
```

Deploy infrastructure:

```sh
terraform apply
```

> **⏱️ EKS Cluster Creation Time**
>
> **EKS cluster creation typically takes 15-20 minutes.** This is normal AWS behavior, not a module issue.
>
> - **EKS Auto Mode**: 15-20 minutes (includes automatic compute/networking setup)
> - **Standard EKS**: 10-18 minutes (depending on configuration)
>
> **What's happening**: Control plane provisioning, networking setup, Auto Mode configuration, add-ons installation, and validation.
>
> **When to be concerned**: 25+ minutes may indicate an issue - check EKS Console for error messages.

### Deployment Validation

**Automatic validation runs during `terraform apply`:**

- **Single-region validation**: Enabled by default - tests DDC PUT/GET operations
- **Multi-region validation**: Disabled by default - requires `peer_region_ddc_endpoint`

**Configuration:**

```hcl
ddc_application_config = {
  # Default: validates DDC works after deployment
  enable_single_region_validation = true

  # For faster CI/CD, disable validation:
  # enable_single_region_validation = false

  # Multi-region: only enable on secondary regions
  # enable_multi_region_validation = true
  # peer_region_ddc_endpoint = "https://us-east-1.ddc.example.com"
}
```

View outputs for Unreal Engine configuration:

```sh
terraform output
```

## Multi-Region Deployment Guide

**Multi-region DDC deployments require careful coordination between regions to share global resources while maintaining regional isolation.** This section provides step-by-step instructions for proper multi-region setup.

### ⚠️ CRITICAL: DDC Namespace Consistency

**DDC namespaces MUST be identical across ALL regions (case-sensitive) or cross-region functionality will break.**

**Why This Matters:**

- Each DDC application needs identical DDC logical namespace configuration to handle requests
- ScyllaDB replicates data, but NOT DDC application logic or security policies
- Mismatched DDC logical namespaces cause requests to fail even if data exists in ScyllaDB
- DDC logical namespace names are case-sensitive ("Project1" ≠ "project1")
- This is about DDC logical namespaces (URL routing), NOT Kubernetes namespaces

**Best Practice:** Use Terraform locals to define shared configuration once:

```hcl
locals {
  # Shared DDC logical namespaces across ALL regions (NOT Kubernetes namespaces)
  shared_ddc_namespaces = {
    "project1" = { description = "Main project" }
    "project2" = { description = "Secondary project" }
  }

  # Shared compute configuration for consistent performance
  shared_compute_config = {
    instance_type    = "i4i.xlarge"
    cpu_requests     = "2000m"
    memory_requests  = "8Gi"
    replica_count    = 2
  }
}
```

### Overview

**Architecture Pattern:**

- **Primary Region**: Creates global IAM roles, OIDC provider, and bearer token
- **Secondary Region(s)**: Use shared global resources from primary region
- **Regional Resources**: Each region creates its own EKS cluster, ScyllaDB, S3 bucket, and load balancers

### Critical Variables for Multi-Region

#### Primary Region Configuration

```hcl
# Shared configuration (CRITICAL: Must be identical across regions)
locals {
  shared_ddc_namespaces = {
    "project1" = { description = "Main project" }
    "project2" = { description = "Secondary project" }
  }

  shared_compute_config = {
    instance_type    = "i4i.xlarge"
    cpu_requests     = "2000m"
    memory_requests  = "8Gi"
    replica_count    = 2
  }
}

module "unreal_cloud_ddc_primary" {
  source = "../../.."
  region = "us-east-1"

  # Multi-region Configuration - PRIMARY
  is_primary_region = true
  create_bearer_token = true
  bearer_token_replica_regions = ["us-west-1"]
  create_private_dns_records = true

  # DDC Application Configuration (using shared locals)
  ddc_application_config = {
    ddc_namespaces = local.shared_ddc_namespaces  # CRITICAL: Same across regions

    # Compute configuration (consistent performance)
    instance_type    = local.shared_compute_config.instance_type
    cpu_requests     = local.shared_compute_config.cpu_requests
    memory_requests  = local.shared_compute_config.memory_requests
    replica_count    = local.shared_compute_config.replica_count
  }

  # Infrastructure configuration...
  ddc_infra_config = {
    region = "us-east-1"
    scylla_config = {
      current_region = {
        datacenter_name    = "us-east-1"
        replication_factor = 3
      }
      peer_regions = {
        "us-west-1" = {
          datacenter_name    = "us-west-1"
          replication_factor = 2
        }
      }
      enable_cross_region_replication = true
      create_seed_node = true
      subnets = aws_subnet.primary_private[*].id
    }
  }
}
```

#### Secondary Region Configuration

```hcl
module "unreal_cloud_ddc_secondary" {
  source = "../../.."
  region = "us-west-1"

  # Multi-region Configuration - SECONDARY
  is_primary_region = false
  create_bearer_token = false
  create_private_dns_records = false

  # DDC Application Configuration (using shared locals)
  ddc_application_config = {
    ddc_namespaces = local.shared_ddc_namespaces  # CRITICAL: Must match primary exactly

    # Compute configuration (consistent performance across regions)
    instance_type    = local.shared_compute_config.instance_type
    cpu_requests     = local.shared_compute_config.cpu_requests
    memory_requests  = local.shared_compute_config.memory_requests
    replica_count    = local.shared_compute_config.replica_count

    # Use shared bearer token from primary
    bearer_token_secret_arn = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
  }

  # Infrastructure configuration...
  ddc_infra_config = {
    region = "us-west-1"

    # Use IAM roles from primary region
    eks_cluster_role_arn = module.unreal_cloud_ddc_primary.iam_roles.eks_cluster_role_arn
    eks_node_group_role_arns = module.unreal_cloud_ddc_primary.iam_roles.eks_node_group_role_arns
    oidc_provider_arn = module.unreal_cloud_ddc_primary.iam_roles.oidc_provider_arn

    scylla_config = {
      current_region = {
        datacenter_name    = "us-west-1"
        replication_factor = 2
      }
      peer_regions = {
        "us-east-1" = {
          datacenter_name    = "us-east-1"
          replication_factor = 3
        }
      }
      enable_cross_region_replication = true
      create_seed_node = false
      existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
      scylla_source_region = "us-east-1"
      subnets = aws_subnet.secondary_private[*].id
    }
  }

  depends_on = [module.unreal_cloud_ddc_primary]
}
```

### Step-by-Step Deployment Process

#### Step 1: Deploy Primary Region First

```bash
# Navigate to primary region directory
cd examples/hybrid/multi-region/

# Initialize and deploy primary region
terraform init
terraform plan -target=module.unreal_cloud_ddc_primary
terraform apply -target=module.unreal_cloud_ddc_primary
```

**Wait for primary region to complete fully before proceeding.**

#### Step 2: Deploy Secondary Region

```bash
# Deploy secondary region (uses outputs from primary)
terraform plan -target=module.unreal_cloud_ddc_secondary
terraform apply -target=module.unreal_cloud_ddc_secondary
```

#### Step 3: Apply Complete Configuration

```bash
# Apply any remaining resources
terraform apply
```

### Variable Coordination Matrix

| Variable                       | Primary Region  | Secondary Region    | Purpose                                  |
| ------------------------------ | --------------- | ------------------- | ---------------------------------------- |
| `is_primary_region`            | `true`          | `false`             | Controls global IAM resource creation    |
| `create_bearer_token`          | `true`          | `false`             | Primary creates, secondary uses existing |
| `create_private_dns_records`   | `true`          | `false`             | Avoids DNS record conflicts              |
| `bearer_token_replica_regions` | `["us-west-1"]` | Not set             | Replicates token to secondary regions    |
| `bearer_token_secret_arn`      | Not set         | From primary output | Secondary uses primary's token           |
| `eks_cluster_role_arn`         | Not set         | From primary output | Secondary uses primary's IAM role        |
| `eks_node_group_role_arns`     | Not set         | From primary output | Secondary uses primary's IAM roles       |
| `oidc_provider_arn`            | Not set         | From primary output | Secondary uses primary's OIDC provider   |
| `create_seed_node`             | `true`          | `false`             | Primary creates ScyllaDB seed node       |
| `existing_scylla_seed`         | Not set         | From primary output | Secondary connects to primary seed       |
| `scylla_source_region`         | Not set         | `"us-east-1"`       | Secondary knows primary region           |
| `depends_on`                   | Not set         | `[module.primary]`  | Ensures proper deployment order          |

### Resource Sharing Architecture

#### Global Resources (Created Once in Primary)

- **IAM Roles**: EKS cluster role, node group roles, service account roles
- **OIDC Provider**: For Kubernetes service account authentication
- **Bearer Token Secret**: Replicated to secondary regions via AWS Secrets Manager

#### Regional Resources (Created in Each Region)

- **EKS Cluster**: Regional Kubernetes cluster
- **ScyllaDB Cluster**: Regional database with cross-region replication
- **S3 Bucket**: Regional object storage
- **Load Balancers**: Regional traffic distribution
- **Security Groups**: Regional network access control
- **DNS Records**: Regional endpoints (e.g., `us-east-1.ddc.example.com`)

### Common Multi-Region Issues

#### Issue: "Missing required argument: role_arn"

**Cause**: Secondary region trying to access non-existent IAM roles

**Solution**: Ensure secondary region receives IAM role ARNs from primary:

```hcl
# In secondary region configuration
ddc_infra_config = {
  eks_cluster_role_arn = module.unreal_cloud_ddc_primary.iam_roles.eks_cluster_role_arn
  eks_node_group_role_arns = module.unreal_cloud_ddc_primary.iam_roles.eks_node_group_role_arns
  oidc_provider_arn = module.unreal_cloud_ddc_primary.iam_roles.oidc_provider_arn
}
```

#### Issue: "Invalid function argument: argument must not be null"

**Cause**: EKS addons in secondary region can't find OIDC provider

**Solution**: Pass OIDC provider ARN from primary to secondary region (shown above)

#### Issue: ScyllaDB Connection Failures

**Cause**: Secondary region can't connect to primary seed node

**Solution**: Verify network connectivity and security group rules between regions:

```hcl
# Ensure ScyllaDB security groups allow cross-region access
# Add VPC peering or Transit Gateway if needed
```

#### Issue: Bearer Token Access Denied

**Cause**: Token not properly replicated to secondary region

**Solution**: Verify bearer token replication:

```bash
# Check token exists in secondary region
aws secretsmanager describe-secret --region us-west-1 --secret-id <token-secret-name>
```

### Verification Steps

#### Primary Region Verification

```bash
# Check primary region outputs
terraform output module.unreal_cloud_ddc_primary.iam_roles

# Verify IAM roles exist
aws iam get-role --role-name <cluster-role-name>

# Test DDC endpoint
curl <PRIMARY_DDC_ENDPOINT>/health/live
```

#### Secondary Region Verification

```bash
# Check secondary region can access shared resources
aws iam get-role --role-name <cluster-role-name> --region us-west-1

# Test DDC endpoint
curl <SECONDARY_DDC_ENDPOINT>/health/live

# Verify ScyllaDB cross-region replication
aws eks update-kubeconfig --region us-west-1 --name <secondary-cluster-name>
kubectl exec -it <scylla-pod> -n unreal-cloud-ddc -- nodetool status
```

### Destroy Process for Multi-Region

**⚠️ CRITICAL**: Destroy in reverse order to avoid dependency issues

```bash
# Step 1: Destroy secondary region first
terraform destroy -target=module.unreal_cloud_ddc_secondary

# Step 2: Destroy primary region
terraform destroy -target=module.unreal_cloud_ddc_primary

# Step 3: Clean up any remaining resources
terraform destroy
```

### Best Practices

1. **Always deploy primary region first** - Secondary regions depend on primary outputs
2. **Use explicit dependencies** - Add `depends_on = [module.primary]` to secondary regions
3. **Test connectivity** - Verify network paths between regions for ScyllaDB replication
4. **Monitor replication** - Check ScyllaDB cross-region replication status regularly
5. **Plan for disaster recovery** - Document procedures for promoting secondary to primary
6. **Cost optimization** - Consider different instance sizes for secondary regions based on usage

### Multi-Region DNS Pattern

The module automatically creates regional DNS endpoints:

- **Primary**: `us-east-1.ddc.example.com`
- **Secondary**: `us-west-1.ddc.example.com`

**Unreal Engine Configuration for Multi-Region:**

```ini
[DDC]
; Primary region (higher priority)
Primary=(Type=HTTPDerivedDataBackend, Host="https://us-east-1.ddc.example.com")

; Secondary region (fallback)
Secondary=(Type=HTTPDerivedDataBackend, Host="https://us-west-1.ddc.example.com")

; Local cache (final fallback)
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)

; Hierarchical setup (try in order)
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

This configuration provides automatic failover and optimal routing for global development teams.

## Deployment Control

The module provides flexible deployment and testing control through configuration flags:

| Scenario | Configuration | Deploy | Single-Region Test | Multi-Region Test | Use Case |
|----------|---------------|--------|-------------------|-------------------|----------|
| **Default** | `{}` (all defaults) | ✅ | ✅ | ❌ | Most common (80% of users) |
| **No Testing** | `enable_single_region_validation = false` | ✅ | ❌ | ❌ | CI/CD environments |
| **Multi-Region Primary** | `enable_multi_region_validation = true`<br/>`peer_region_ddc_endpoint = null` | ✅ | ✅ | ✅ | Primary region |
| **Multi-Region Secondary** | `peer_region_ddc_endpoint = "us-east-1.ddc.example.com"` | ✅ | ✅ | ❌ | Secondary region |
| **Debug Mode** | `debug = true` | ✅ (forced) | ✅ (forced) | Normal | Development/troubleshooting |

### Key Points

- **Single-region testing** is enabled by default (valuable for all deployments)
- **Multi-region testing** should only be enabled in the primary region to avoid duplication
- **Debug mode** forces deployments and single-region tests to run (useful for development)
- **Multi-region killswitch** prevents duplicate cross-region testing

### Example Configurations

**Single-Region (Default)**:
```hcl
ddc_application_config = {
  # All defaults - gets single-region testing automatically
}
```

**Multi-Region Primary**:
```hcl
ddc_application_config = {
  enable_multi_region_validation = true
  peer_region_ddc_endpoint = null  # Identifies as primary
}
```

**Multi-Region Secondary**:
```hcl
ddc_application_config = {
  peer_region_ddc_endpoint = "us-east-1.ddc.example.com"
  # enable_multi_region_validation defaults to false
}
```

For detailed deployment control scenarios, see the [DEVELOPER_GUIDE](DEVELOPER_GUIDE.md#deployment-control-scenarios).

## Verification & Testing

## Testing Options

The DDC module provides both automated and manual testing approaches:

#### **Automated Testing (During deployment)**

The module includes automated application testing using [Terraform Actions](https://www.hashicorp.com/en/blog/day-2-infrastructure-management-with-terraform-actions) that runs synchronously during `terraform apply` to validate that the DDC endpoint service is reachable and data can be written to and retrieved from the cache:

- **Infrastructure validation**: CodeBuild automatically validates EKS cluster setup, AWS Load Balancer Controller installation, and custom NodePool creation
- **Application validation**: CodeBuild tests DDC deployment, health endpoints, and functional cache operations (PUT/GET/HEAD)
- **Multi-region validation**: Optional cross-region replication testing
- **Synchronous execution**: Terraform waits for validation to complete before finishing

**Configuration:**

```hcl
ddc_application_config = {
  # Default: validates DDC works after deployment
  enable_single_region_validation = true

  # For faster CI/CD, disable validation:
  # enable_single_region_validation = false

  # Multi-region: only enable on secondary regions
  # enable_multi_region_validation = true
  # peer_region_ddc_endpoint = "https://us-east-1.ddc.example.com"
}
```

#### **Manual Testing (After deployment)**

Use the functional test scripts for manual verification:

> **Platform Compatibility:**
>
> - ✅ **macOS/Linux** - Native support
> - ✅ **Windows with WSL** - Run in WSL environment
> - ❌ **Windows PowerShell/CMD** - Use manual verification steps below

**Single Region:**

Run from your deployment directory (e.g., examples/hybrid/single-region/):

```sh
chmod +x ../../../assets/scripts/ddc_functional_test.sh
../../../assets/scripts/ddc_functional_test.sh
```

**Multi-Region:**

Run from your deployment directory (e.g., examples/hybrid/multi-region/):

```sh
chmod +x ../../../assets/scripts/ddc_functional_test_multi_region.sh
../../../assets/scripts/ddc_functional_test_multi_region.sh
```

**Path Explanation:**

- You're in: `examples/hybrid/multi-region/`
- Scripts are at: `../../../assets/scripts/`
- This navigates: `../../../` (up 3 levels) then `assets/scripts/`

The test scripts will automatically verify all components and provide a comprehensive health check.

### Manual Verification Steps

If you prefer to run individual checks manually:

**Get your deployment values:**

First, get the values you'll need from Terraform outputs:

```bash
terraform output
```

**1. Update kubeconfig (REQUIRED first step):**

Use the `kubectl_command` from terraform output:

```bash
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

**2. Check TargetGroupBinding status:**

Replace `<name-prefix>` with your project prefix and `<namespace>` with your DDC namespace:

```bash
kubectl describe targetgroupbinding <name-prefix>-tgb -n <namespace>
```

Expected output should show: `Status: Ready=True`

**3. Check pod status:**

Replace `<namespace>` with your DDC namespace:

```bash
kubectl get pods -n <namespace>
```

Expected: All pods should be "Running"

**4. Test DDC health endpoint:**

Use the DDC endpoint from terraform output:

```bash
curl <DDC_ENDPOINT>/health/live
```

Expected response: "HEALTHY"

### Networking

**1. Basic Health Check**

**[Request]**

```sh
# Test DDC health endpoint
curl <DDC_ENDPOINT>/health/live
```

**[Response]**

After running this you should get a response that looks as the following:

```sh
HEALTHY%
```

**2. PUT a file in Unreal Cloud DDC**

**[Request]**

```sh
# Test PUT operation (write to cache)
curl -X PUT "<DDC_ENDPOINT>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa" \
  --data "test" \
  -H "content-type: application/octet-stream" \
  -H "X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA" \
  -H "Authorization: ServiceAccount <BEARER_TOKEN>"
```

**[Response]**

After running this you should get a response that looks as the following:

```sh
HTTP/1.1 200 OK
Server: http
Date: Wed, 29 Jan 2025 19:15:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server-Timing: blob.put.FileSystemStore;dur=0.1451;desc="PUT to store: 'FileSystemStore'",blob.put.AmazonS3Store;dur=267.0449;desc="PUT to store: 'AmazonS3Store'",blob.get-metadata.FileSystemStore;dur=0.0406;desc="Blob GET Metadata from: 'FileSystemStore'",ref.finalize;dur=7.1407;desc="Finalizing the ref",ref.put;dur=25.2064;desc="Inserting ref"

{"needs":[]}}%
```

**3. GET the file you wrote to Unreal Cloud DDC**

**[Request]**

```sh
# Test GET operation (read from cache)
curl "<DDC_ENDPOINT>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json" \
  -H "Authorization: ServiceAccount <BEARER_TOKEN>"
```

**[Response]**

After running this you should get a response that looks as the following:

```sh
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

If the above commands do not work, try to test access to the Network Load Balancer directly

**Example:**

```sh
# Test DDC health endpoint
curl <Network Load Balancer Endpoint>/health/live

# Expected response: "HEALTHY"
```

### Application

**1. Verify the Unreal Cloud DDC EKS Cluster Status**

**[Request]**

```sh
# Configure kubectl access
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Check pod status
kubectl get pods -n unreal-cloud-ddc
```

**[Response]**

<!-- Expected: All pods should be "Running" -->

```sh
NAME                                                     READY   STATUS    RESTARTS   AGE
cgd-unreal-cloud-ddc-initialize-546ff4bbfd-7dh62         1/1     Running   0          101m
cgd-unreal-cloud-ddc-initialize-546ff4bbfd-97zd2         1/1     Running   0          101m
cgd-unreal-cloud-ddc-initialize-worker-7c6dfbc66-8lw8v   1/1     Running   0          101m
```

### Database

**1. Check the status of the database nodes**

Connect to any of the Scylla Nodes and run the following command (SSM with Session Manager recommended):

**[Request]**

```sh
nodetool status
```

**[Response]**

```sh
$ nodetool status
Datacenter: us-east
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
-- Address    Load      Tokens Owns Host ID                              Rack
UN 10.0.4.73  925.51 KB 256    ?    15e58613-891d-44a4-a445-50678edb07cb 1a
UN 10.0.5.107 913.77 KB 256    ?    329cfa9f-71b3-4e5e-a5c6-c1ee91a550ba 1b
UN 10.0.6.158 948.95 KB 256    ?    1e5ac8b8-50b5-4e47-aa91-5b4fa917afd2 1c

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```

**2. Check the keyspaces are present**

On the instance, start cqlsh session:

```sh
cqlsh
```

**[Request]**

Check if all keyspaces are there

```sh
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces (names will vary depending on your region):

- **Global Keyspace (`jupiter`)**

  - Stores shared/cross-region data that all regions can access
  - Contains metadata, configuration, and shared cache entries
  - Used for multi-region coordination and global cache lookups

- **Local Keyspace (`jupiter_local_ddc_us_east_1`)**
  - Stores region-specific cache data for performance
  - Contains local cache entries that don't need cross-region replication
  - Reduces latency by keeping frequently accessed data local

```sh
system_auth                  system
system_schema                jupiter_local_ddc_us_east_1
jupiter                      system_traces
system_distributed           system_distributed_everywhere
```

**3. Check the keyspace configuration**

On the instance, start cqlsh session:

```sh
cqlsh
```

**[Request]**

Check if all keyspaces are there

```sh
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces:

- jupiter
- jupiter_ddc_localperation (read from cache)
curl "<DDC_ENDPOINT>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json" \
  -H "Authorization: ServiceAccount <BEARER_TOKEN>"
```

**[Response]**

After running this you should get a response that looks as the following:

```sh
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

```sh
# Test DDC health endpoint
curl <Network Load Balancer Endpoint>/health/live

# Expected response: "Healthy"
```

### Application

**1. Verify the Unreal Cloud DDC EKS Cluster Status**

**[Request]**

```sh
# Configure kubectl access
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Check pod status
kubectl get pods -n unreal-cloud-ddc

```

**[Response]**

 <!-- Expected: All pods should be "Running" -->

```sh
NAME                                                     READY   STATUS    RESTARTS   AGE
cgd-unreal-cloud-ddc-initialize-546ff4bbfd-7dh62         1/1     Running   0          101m
cgd-unreal-cloud-ddc-initialize-546ff4bbfd-97zd2         1/1     Running   0          101m
cgd-unreal-cloud-ddc-initialize-worker-7c6dfbc66-8lw8v   1/1     Running   0          101m
```

### Database

**1. Check the status of the database nodes**

Connect to any of the Scylla Nodes and run the following command (SSM with Session Manager recommended):

**[Request]**

```sh
nodetool status
```

**[Response]**

```sh
$ nodetool status
Datacenter: us-east
===================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
-- Address    Load      Tokens Owns Host ID                              Rack
UN 10.0.4.73  925.51 KB 256    ?    15e58613-891d-44a4-a445-50678edb07cb 1a
UN 10.0.5.107 913.77 KB 256    ?    329cfa9f-71b3-4e5e-a5c6-c1ee91a550ba 1b
UN 10.0.6.158 948.95 KB 256    ?    1e5ac8b8-50b5-4e47-aa91-5b4fa917afd2 1c

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```

**2. Check the keyspaces are present**

On the instance, start cqlsh session:

```sh
cqlsh
```

**[Request]**

Check if all keyspaces are there

```sh
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces (names will vary depending on your region):

- **Global Keyspace (`jupiter`)**

  - Stores shared/cross-region data that all regions can access
  - Contains metadata, configuration, and shared cache entries
  - Used for multi-region coordination and global cache lookups

- **Local Keyspace (`jupiter_local_ddc_us_east_1`)**
  - Stores region-specific cache data for performance
  - Contains local cache entries that don't need cross-region replication
  - Reduces latency by keeping frequently accessed data local

```sh
system_auth                  system
system_schema                jupiter_local_ddc_us_east_1
jupiter                      system_traces
system_distributed           system_distributed_everywhere
```

**2. Check the keyspace configuration**

On the instance, start cqlsh session:

```sh
cqlsh
```

**[Request]**

Check if all keyspaces are there

```sh
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

```sh
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

For distributed teams:

```ini
[DDC]
; Region 1 (Primary in this case)
Primary=(Type=HTTPDerivedDataBackend, Host="<DDS Route53 DNS Endpoint for Region 1>")

; Region 2
Secondary=(Type=HTTPDerivedDataBackend, Host="https://us-west-2.ddc.prod.yourcompany.com")

; Try primary first, then secondary, then local
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

> **Note:** The hierarchical setup sets priority order for cache usage. This helps optimize for both latency and disaster recovery. For more information see [these docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine).

## Namespace Architecture

The DDC module uses three distinct types of namespaces for different purposes. Understanding these differences is critical for proper configuration and troubleshooting.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ DDC Logical Namespaces (Application Layer)                                     │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                              │ ← URL routing
│ │  project1   │ │  project2   │ │   default   │                              │   /api/v1/refs/{namespace}/
│ └─────────────┘ └─────────────┘ └─────────────┘                              │
└─────────────┬───────────────┬───────────────┬───────────────────────────────┘
              │               │               │ (all store data in same keyspace)
┌─────────────▼───────────────▼───────────────▼─────────────────────────────────┐
│ ScyllaDB Keyspaces (Database Schema Layer)                                    │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                              │ ← Database isolation
│ │  project1   │ │  project2   │ │   default   │                              │   One keyspace per namespace
│ │ keyspace    │ │ keyspace    │ │ keyspace    │                              │
│ └─────────────┘ └─────────────┘ └─────────────┘                              │
└─────────────┬───────────────┬───────────────┬─────────────────────────────────┘
              │               │               │ (replicated across datacenters)
┌─────────────▼───────────────▼───────────────▼─────────────────────────────────┐
│ ScyllaDB Datacenters (Infrastructure Layer)                                   │
│ us-east-1 ↔ us-west-1 ↔ eu-west-1                                          │ ← Multi-region replication
└─────────────────────────────────────────────────────────────────────────────┘   (datacenter_name)

┌─────────────────────────────────────────────────────────────────────────────┐
│ Kubernetes Namespace (Infrastructure Container)                                 │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │ ← Resource isolation
│ │ unreal-cloud-ddc                                                            │ │   Single K8s namespace
│ │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                │ │   Contains ALL resources
│ │ │ DDC Pod │ │ DDC Pod │ │ Scylla  │ │ Scylla  │ │ Scylla  │                │ │
│ │ │    1    │ │    2    │ │ Node 1  │ │ Node 2  │ │ Node 3  │                │ │
│ │ └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘                │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1. Kubernetes Namespaces (Infrastructure Container)

**Purpose**: Physical infrastructure organization and resource isolation within the EKS cluster.

**Function**:

- Container for Kubernetes resources (pods, services, ConfigMaps, secrets)
- Visible in `kubectl get namespaces`
- Used for RBAC, resource quotas, network policies
- **Single namespace**: `kubernetes_namespace = "unreal-cloud-ddc"` (default)
- **Contains all DDC infrastructure**: DDC pods, ScyllaDB, load balancers, certificates
- **Shared by all game projects**: One namespace serves the entire studio

**Example**:

```bash
kubectl get namespaces
# Shows: unreal-cloud-ddc, kube-system, default, etc.

kubectl get pods -n unreal-cloud-ddc
# Shows: DDC pods, ScyllaDB pods, etc.
```

### 2. DDC Logical Namespaces (Application Logic)

**Purpose**: Application-level game project isolation within the DDC service.

**Function**:

- **URL path segments**: `/api/v1/refs/{logical-namespace}/default/hash`
- **S3 object prefixes**: `s3://bucket/{logical-namespace}/assets/`
- **Project isolation**: Separate cache data per game/team
- **NOT visible in kubectl**: These are application configuration, not Kubernetes resources
- **Configured via Terraform**: `default_ddc_namespace` + `ddc_namespaces` map

**Configuration Example**:

```hcl
ddc_application_config = {
  # default_ddc_namespace = "default" (reserved for testing)
  ddc_namespaces = {
    "project1" = { description = "Main project DDC cache" }
    "project2" = { description = "Secondary project DDC cache" }
    "dev-sandbox" = { description = "Development testing DDC cache" }
  }
}
```

**URL Structure**:

```
https://ddc.studio.com/api/v1/refs/default/default/hash    # Testing namespace (reserved)
https://ddc.studio.com/api/v1/refs/project1/default/hash   # Project namespace
https://ddc.studio.com/api/v1/refs/project2/default/hash   # Project namespace Game namespace
```

### 3. ScyllaDB Keyspaces (Database Schema)

**Purpose**: Database-level data isolation for DDC metadata storage.

**Function**:

- **Database schema isolation**: Separate tables per keyspace
- **Query isolation**: Queries scoped to specific keyspace
- **Backup/restore granularity**: Per-keyspace operations

**Relationship to DDC Logical Namespaces**:
**One-to-one automatic mapping**:

- DDC logical namespace `project1` → ScyllaDB keyspace `project1`
- DDC logical namespace `project2` → ScyllaDB keyspace `project2`
- DDC logical namespace `default` → ScyllaDB keyspace `default`

**Automatic Creation**:
The DDC application automatically:

1. **Reads logical namespace configuration** from Terraform-generated ConfigMap
2. **Creates corresponding ScyllaDB keyspaces** for each logical namespace
3. **Routes requests** based on URL path to appropriate keyspace

### Data Flow Example

**Request Flow**:

```
User Request: GET /api/v1/refs/project1/default/abc123
    ↓
DDC Service: Parses "project1" from URL path
    ↓
ScyllaDB: Queries "project1" keyspace for metadata
    ↓
S3: Retrieves object from "project1/" prefix
    ↓
Response: Returns cached asset to user
```

### 4. ScyllaDB Datacenters (Infrastructure Replication)

**Purpose**: Multi-region database replication topology.

**Function**:

- **Replication coordination**: Which regions replicate to which
- **Network topology**: Cross-region cluster formation
- **Disaster recovery**: Regional failover capabilities
- **COMPLETELY INDEPENDENT**: No relationship to DDC logical namespaces

**Configuration Example**:

```hcl
scylla_config = {
  current_region = {
    datacenter_name = "us-east-1"     # Infrastructure identifier
  }
  peer_regions = {
    "us-west-1" = {
      datacenter_name = "us-west-1"   # Infrastructure identifier
    }
  }
}
```

**Key Point**: `datacenter_name` is purely for ScyllaDB replication topology. It has **no relationship** to DDC logical namespaces.

### Data Flow Example

**Request Flow**:

```
User Request: GET /api/v1/refs/project1/default/abc123
    ↓
DDC Service: Parses "project1" from URL path
    ↓
ScyllaDB: Queries "project1" keyspace for metadata
    ↓
S3: Retrieves object from "project1/" prefix
    ↓
Response: Returns cached asset to user
```

**Storage Layout**:

```
ScyllaDB Keyspaces (Schema Level):
├── project1 (keyspace)
│   ├── blob_index (table)
│   ├── content_id (table)
│   └── references (table)
├── project2 (keyspace)
│   ├── blob_index (table)
│   ├── content_id (table)
│   └── references (table)
└── default (keyspace)
    ├── blob_index (table)
    ├── content_id (table)
    └── references (table)

ScyllaDB Datacenters (Infrastructure Level):
├── us-east-1 (datacenter) - Contains ALL keyspaces above
├── us-west-1 (datacenter) - Contains ALL keyspaces above
└── eu-west-1 (datacenter) - Contains ALL keyspaces above

S3 Bucket Structure:
├── project1/
│   ├── assets/abc123...
│   └── metadata/def456...
├── project2/
│   ├── assets/ghi789...
│   └── metadata/jkl012...
└── default/
    ├── assets/mno345...
    └── metadata/pqr678...
```

### Configuration Summary

| Type                      | Purpose                  | Visibility               | Configuration                                  | Relationship                |
| ------------------------- | ------------------------ | ------------------------ | ---------------------------------------------- | --------------------------- |
| **Kubernetes Namespace**  | Infrastructure isolation | `kubectl get namespaces` | `kubernetes_namespace = "unreal-cloud-ddc"`    | Contains all resources      |
| **DDC Logical Namespace** | Game project isolation   | DDC URLs only            | `default_ddc_namespace` + `ddc_namespaces` map | 1:1 with keyspaces          |
| **ScyllaDB Keyspace**     | Database isolation       | ScyllaDB queries         | Auto-created from logical namespaces           | 1:1 with logical namespaces |
| **ScyllaDB Datacenter**   | Replication topology     | ScyllaDB cluster         | `datacenter_name` in config                    | Independent of all above    |

### Key Takeaways

1. **One Kubernetes namespace** contains all DDC infrastructure
2. **Multiple DDC logical namespaces** provide game project isolation
3. **ScyllaDB keyspaces** automatically match DDC logical namespaces (1:1)
4. **ScyllaDB datacenters** are for replication topology only (independent)
5. **Test scripts** use `default_ddc_namespace` for validation
6. **URL structure** determines which logical namespace (and keyspace) is used
7. **No cross-contamination** between logical namespaces at the application level
8. **All logical namespaces** exist in all datacenters (full replication)

## Tagging Best Practices

### Standardized Tag Structure

The CGD Toolkit follows a standardized tagging approach for consistent resource identification and cost allocation:

```hcl
# Example locals.tf - Recommended tagging pattern
locals {
  # Standardized tags for all resources
  tags = {
    # Project identification
    ProjectPrefix = local.project_prefix  # "cgd", "studio", etc.
    Environment   = local.environment     # "dev", "staging", "prod"
    
    # Infrastructure as Code metadata
    IaC        = "Terraform"
    ModuleBy   = "CGD-Toolkit"
    ModuleName = "unreal-cloud-ddc"
    
    # Deployment context
    DeployedBy = "terraform-example"      # "terraform-example", "argocd", "github-actions"
    Region     = local.region             # "us-east-1", "us-west-2"
    
    # Optional: Cost allocation
    CostCenter = "game-development"       # For cost tracking
    Team       = "platform-engineering"   # Responsible team
  }
}
```

### EKS-Specific Tags (Automatic)

The module automatically adds EKS-required tags to subnets and resources:

```hcl
# Public subnets - automatically tagged by examples
resource "aws_subnet" "public" {
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    
    # EKS Auto Mode requirements (added automatically)
    "kubernetes.io/cluster/${local.name_prefix}" = "owned"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private subnets - automatically tagged by examples  
resource "aws_subnet" "private" {
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    
    # EKS Auto Mode requirements (added automatically)
    "kubernetes.io/cluster/${local.name_prefix}" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
  })
}
```

### Tag Inheritance

Tags flow through the module hierarchy:

```
Example locals.tf tags
    ↓
Module input (var.tags)
    ↓
Submodule inheritance
    ↓
AWS resources
```

**All AWS resources** created by the module inherit the base tags plus resource-specific tags for identification.

### Cost Allocation Strategy

**Recommended approach for multi-environment deployments:**

```hcl
# Development environment
locals {
  tags = {
    ProjectPrefix = "cgd"
    Environment   = "dev"
    CostCenter    = "game-development"
    Team          = "platform-engineering"
    # ... other tags
  }
}

# Production environment  
locals {
  tags = {
    ProjectPrefix = "cgd"
    Environment   = "prod"
    CostCenter    = "game-development"
    Team          = "platform-engineering"
    # ... other tags
  }
}
```

**AWS Cost Explorer filters:**
- `Environment = "prod"` - Production costs only
- `ModuleName = "unreal-cloud-ddc"` - DDC-specific costs
- `ProjectPrefix = "cgd"` - All CGD Toolkit costs

### Multi-Region Tagging

**For multi-region deployments, include region in tags:**

```hcl
# Primary region (us-east-1)
locals {
  tags = {
    ProjectPrefix = "cgd"
    Environment   = "prod"
    Region        = "us-east-1"
    RegionRole    = "primary"    # "primary" or "secondary"
    # ... other tags
  }
}

# Secondary region (us-west-2)
locals {
  tags = {
    ProjectPrefix = "cgd"
    Environment   = "prod"
    Region        = "us-west-2"
    RegionRole    = "secondary"  # "primary" or "secondary"
    # ... other tags
  }
}
```

**Benefits:**
- **Cost analysis** by region and role
- **Resource identification** across regions
- **Disaster recovery** planning and testing
- **Compliance** and audit trails

## Configuration Examples

### Single Region Example

```hcl
module "unreal_cloud_ddc" {
  source = "../../.."

  # Core Infrastructure
  project_prefix           = "cgd"
  vpc_id                   = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_certificate_arn = aws_acm_certificate.ddc.arn
  existing_route53_public_hosted_zone_name = var.route53_public_hosted_zone_name

  # Load Balancer Configuration
  existing_load_balancer_subnets = aws_subnet.public_subnets[*].id

  # Security
  allowed_external_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]

  # DDC Application Configuration
  ddc_application_config = {
    # default_ddc_namespace = "default" (reserved for testing)
    ddc_namespaces = {
      "our-game" = {
        description = "Our main game project DDC cache"
      }
    }
    deployment = {
      enable_single_region_validation = true
    }
  }

  # DDC Infrastructure Configuration
  ddc_infra_config = {
    region                 = "us-east-1"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id

    # ScyllaDB Configuration
    scylla_config = {
      current_region = {
        replication_factor = 3
      }
      subnets = aws_subnet.private_subnets[*].id
    }
  }

  # GHCR Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn
}
```

### Multi-Region Example

**Primary Region:**

```hcl
module "unreal_cloud_ddc_primary" {
  source = "../../.."
  region = "us-east-1"

  # Multi-region Configuration - PRIMARY
  is_primary_region = true
  create_bearer_token = true
  bearer_token_replica_regions = ["us-west-1"]
  create_private_dns_records = true

  # DDC Application Configuration
  ddc_application_config = {
    # default_ddc_namespace = "default" (reserved for testing)
    ddc_namespaces = {
      "project1" = {
        description = "Main project DDC cache"
      }
      "project2" = {
        description = "Secondary project DDC cache"
      }
    }
    deployment = {
      enable_single_region_validation = true
    }
  }

  # Infrastructure configuration...
  ddc_infra_config = {
    region = "us-east-1"
    scylla_config = {
      current_region = {
        datacenter_name    = "us-east-1"
        replication_factor = 3
      }
      peer_regions = {
        "us-west-1" = {
          datacenter_name    = "us-west-1"
          replication_factor = 2
        }
      }
      enable_cross_region_replication = true
      create_seed_node = true
      subnets = aws_subnet.primary_private[*].id
    }
  }
}
```

**Secondary Region:**

```hcl
module "unreal_cloud_ddc_secondary" {
  source = "../../.."
  region = "us-west-1"

  # Multi-region Configuration - SECONDARY
  is_primary_region = false
  create_bearer_token = false
  create_private_dns_records = false

  # Use shared resources from primary region
  ddc_application_config = {
    # Same logical namespaces as primary
    ddc_namespaces = {
      "project1" = {
        description = "Main project DDC cache"
      }
      "project2" = {
        description = "Secondary project DDC cache"
      }
    }
    bearer_token_secret_arn = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
    deployment = {
      enable_single_region_validation = true
      enable_multi_region_validation = true
      peer_region_ddc_endpoint = module.unreal_cloud_ddc_primary.ddc_endpoint
    }
  }

  # Infrastructure configuration...
  ddc_infra_config = {
    region = "us-west-1"
    scylla_config = {
      current_region = {
        datacenter_name    = "us-west-1"
        replication_factor = 2
      }
      peer_regions = {
        "us-east-1" = {
          datacenter_name    = "us-east-1"
          replication_factor = 3
        }
      }
      enable_cross_region_replication = true
      create_seed_node = false
      existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
      scylla_source_region = "us-east-1"
      subnets = aws_subnet.secondary_private[*].id
    }
  }

  depends_on = [module.unreal_cloud_ddc_primary]
}
```

## Troubleshooting

### 🚨 CRITICAL REQUIREMENTS

#### **NEVER Use Default VPC/Subnets/Route Tables**

**⚠️ CRITICAL**: You MUST use custom networking resources (not AWS account defaults). You can create new ones OR reuse existing custom ones. Using AWS default VPC, subnets, or route tables will cause destroy failures.

**Why This Matters:**

- **Default Route Tables**: Cannot be deleted by Terraform (AWS managed) → IGW hangs during destroy
- **Custom Route Tables**: Can be deleted cleanly by Terraform → clean destroy every time
- **Default VPC/Subnets**: Often have dependencies that prevent clean deletion

**You Can:**

- ✅ Create new custom networking (as shown in examples)
- ✅ Reuse existing custom VPC/subnets/route tables
- ✅ Reference existing custom resources with `data` sources

**You Cannot:**

- ❌ Use the default VPC created by AWS in new accounts
- ❌ Use default route tables (main route table)
- ❌ Use default subnets

**✅ REQUIRED Pattern - Option 1: Create New Custom Resources** (like all examples):

```hcl
# Create custom VPC and networking
resource "aws_vpc" "unreal_cloud_ddc_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Create custom route tables (NOT default)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

# Associate custom route tables with subnets
resource "aws_route_table_association" "public_rt_asso" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}
```

**✅ REQUIRED Pattern - Option 2: Reuse Existing Custom Resources**:

```hcl
# Reference existing custom VPC (not default VPC)
data "aws_vpc" "existing_custom_vpc" {
  filter {
    name   = "tag:Name"
    values = ["my-custom-vpc"]  # Your existing custom VPC
  }
}

# Reference existing custom subnets (not default subnets)
data "aws_subnets" "existing_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_custom_vpc.id]
  }
  filter {
    name   = "tag:Type"
    values = ["public"]  # Your custom subnet tags
  }
}

# Use in module
module "unreal_cloud_ddc" {
  vpc_id = data.aws_vpc.existing_custom_vpc.id
  load_balancers_config = {
    nlb = {
      subnets = data.aws_subnets.existing_public.ids
    }
  }
}
```

**❌ NEVER Do This**:

```hcl
# DON'T use AWS account default VPC
data "aws_vpc" "default" {
  default = true  # This will cause destroy failures
}

# DON'T use AWS account default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]  # This will cause destroy failures
  }
}

# DON'T use default route tables (main route table)
# These are created automatically by AWS and cannot be deleted
```

**Reference**: See any example in the `examples/` directory for the correct pattern.

### Common Issues

#### 1. Terraform Destroy Hangs on Internet Gateway

**Symptoms**:

```
aws_internet_gateway.igw: Still destroying... [id=igw-xxx, 20m00s elapsed]
Error: DependencyViolation: Network vpc-xxx has some mapped public address(es)
```

**Root Cause**: Using default route tables or improper networking setup

**✅ Solution**:

1. **Use custom route tables** (see CRITICAL REQUIREMENTS above)
2. **Follow example patterns** exactly - all examples use the correct networking pattern
3. **Verify your VPC setup** matches the examples

**Emergency Fix** (if already deployed with wrong pattern):

```bash
# Manual cleanup if destroy is stuck
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl delete targetgroupbinding --all -n <namespace> --ignore-not-found=true

# Wait for ENIs to be released, then retry destroy
terraform destroy
```

#### 2. TargetGroupBinding Issues

**Symptoms**: TargetGroupBinding shows `Ready=False`, DDC service unreachable

**Root Cause**: AWS Load Balancer Controller cannot bind pods to target group

**✅ Solution**: Check detailed status and fix underlying issues:

Check detailed status and events:

```bash
kubectl describe targetgroupbinding <name-prefix>-tgb -n <namespace>
```

Check AWS Load Balancer Controller logs:

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Common issues:**

- "Target not in subnet associated with target group" → Check subnet alignment
- "Security group rules" → Verify security group allows traffic
- "Pod not ready" → Check pod status with `kubectl get pods`

**Manual cleanup (if terraform destroy fails):**

Clean up TargetGroupBinding:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl delete targetgroupbinding <name-prefix>-tgb -n <namespace> --ignore-not-found=true
```

If IGW deletion hangs due to network interface dependencies:

```bash
aws ec2 describe-instances --region <region> --filters "Name=vpc-id,Values=<vpc-id>" "Name=instance-state-name,Values=running"
aws ec2 terminate-instances --region <region> --instance-ids <instance-id>
```

#### 3. Variable Interface Mismatch

**Symptoms**:

```
Error: Unsupported argument
An argument named "existing_vpc_id" is not expected here.
```

**Root Cause**: Using outdated variable names from older module versions

**✅ Solution**: Use the current variable names from the module interface:

```hcl
# Current (correct) interface
module "unreal_cloud_ddc" {
  # Core Infrastructure
  project_prefix               = "cgd"
  vpc_id                      = aws_vpc.unreal_cloud_ddc_vpc.id
  certificate_arn             = aws_acm_certificate.ddc.arn
  route53_hosted_zone_name    = var.route53_public_hosted_zone_name

  # Load Balancer Configuration
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets         = aws_subnet.public_subnets[*].id
    }
  }

  # Security
  allowed_external_cidrs = ["203.0.113.0/24"]

  # DDC Infrastructure Configuration
  ddc_infra_config = {
    region                 = "us-east-1"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs    = ["203.0.113.0/24"]

    scylla_config = {
      current_region = {
        replication_factor = 3
      }
      subnets = aws_subnet.private_subnets[*].id
    }
  }

  # DDC Application Configuration
  ddc_application_config = {
    namespaces = {
      "default" = {
        description = "Default DDC namespace"
      }
    }
  }

  # GHCR Credentials
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn
}
```

#### 3. Pod Crashes with Unix Socket Error

**Symptoms**: `CrashLoopBackOff`, logs show `Invalid url: 'unix:///nginx/jupiter-http.sock'`

**Cause**: NGINX configuration conflict with ClusterIP mode

**Solution**: Verify NGINX is disabled in Helm values:

```sh
# Check Helm release configuration
helm list -n unreal-cloud-ddc
helm get values cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc | grep -A5 nginx
# Should show: enabled: false
```

#### 4. DDC API Connection Timeout

**Symptoms**: `curl` commands timeout or return connection refused

**Solutions**:

1. **Check security group allows your IP**:

   ```bash
   curl https://checkip.amazonaws.com/
   # Verify this IP is in your allowed_external_cidrs
   ```

2. **Verify DNS resolution**:

   ```bash
   nslookup us-east-1.ddc.dev.yourcompany.com
   ```

3. **Check EKS cluster status**:
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   kubectl get nodes
   ```

#### 5. GitHub Container Registry Access Denied

**Symptoms**: Pod image pull failures, `ImagePullBackOff` status

**Solutions**:

1. **Verify Epic Games organization membership**
2. **Check GitHub PAT has `packages:read` permission**
3. **Confirm secret format**:
   ```bash
   aws secretsmanager describe-secret --secret-id "github-ddc-credentials"
   ```

### Troubleshooting Terraform Actions

**If Terraform Actions fail during `terraform apply`:**

1. **Check CodeBuild logs**:
   ```bash
   # Get CodeBuild project name from Terraform output
   terraform output
   
   # View logs in AWS Console:
   # CodeBuild > Build projects > <project-name> > Build history > View logs
   ```

2. **Common Terraform Actions issues**:
   - **EKS access denied**: Check `public_access_cidrs` includes CodeBuild IP ranges
   - **Helm timeout**: LoadBalancer provisioning can take 3-5 minutes
   - **kubectl connection**: EKS cluster may still be initializing
   - **Race conditions**: Terraform Actions prevent these, but check dependencies

3. **Manual verification** (if Terraform Actions succeed but you want to double-check):
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   
   # Check cluster status
   kubectl get nodes
   kubectl get pods -n unreal-cloud-ddc
   ```

### Destroy Troubleshooting

#### Safe Destroy Process

**✅ Recommended Approach**:

```bash
# 1. Verify you're in the correct directory (where you ran terraform apply)
pwd
ls terraform.tfstate  # Should exist

# 2. Generate destroy plan first (optional but recommended)
terraform plan -destroy > destroy_plan.txt

# 3. Review the plan
head -50 destroy_plan.txt

# 4. Execute destroy
terraform destroy -auto-approve
```

#### If Destroy Fails

**Common failure points and solutions**:

1. **IGW hanging** → Check route table pattern (see CRITICAL REQUIREMENTS)
2. **TargetGroupBinding stuck** → Manual cleanup:
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   kubectl delete targetgroupbinding --all -n <namespace> --ignore-not-found=true
   ```
3. **ENIs not released** → Wait 2-3 minutes, then retry destroy
4. **State file issues** → Ensure you're in the correct directory

### Debug Commands

```bash
# Network diagnostics
curl https://checkip.amazonaws.com/
nslookup us-east-1.ddc.dev.yourcompany.com

# Kubernetes diagnostics (REQUIRES kubeconfig setup first)
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
kubectl get pods -n unreal-cloud-ddc
kubectl logs -f <pod-name> -n unreal-cloud-ddc
kubectl get svc -n unreal-cloud-ddc

# Terraform diagnostics
terraform state list | head -10
terraform show | grep -A5 -B5 "internet_gateway"

# AWS resource diagnostics
aws ec2 describe-vpcs --vpc-ids <vpc-id>
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<vpc-id>"
```

### Configuration Changes Requiring Manual Pod Restart

**When changing keyspace names or other critical DDC configuration:**

1. **Apply Terraform changes** (updates ConfigMaps)
2. **Manually restart DDC pods** to pick up new configuration:

```bash
# Update kubeconfig first
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Restart DDC pods
kubectl rollout restart deployment/cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc
kubectl rollout restart deployment/cgd-unreal-cloud-ddc-initialize-worker -n unreal-cloud-ddc
```

3. **Verify ScyllaDB keyspaces** were created with new names:

```bash
# Connect to any ScyllaDB node (via SSM Session Manager recommended)
aws ssm start-session --target <scylla-instance-id>

# Check keyspaces in ScyllaDB
cqlsh
DESCRIBE KEYSPACES;

# Should show new keyspace names like:
# - cgd_dev_local_ddc_us_east_1 (instead of jupiter_local_ddc_us_east_1)
# - cgd_dev_local_ddc_us_east_1_local_ddc
```

4. **Verify DDC pods are using correct keyspaces**:

```bash
# Check DDC pod logs for keyspace connections
kubectl logs -f <ddc-pod-name> -n unreal-cloud-ddc | grep -i "keyspace\|switching to"

# Should show connections to new keyspace names
```

5. **Clean up old keyspaces** (optional, after confirming new ones work):

```bash
# In cqlsh session, drop old unused keyspaces to free storage
cqlsh> DROP KEYSPACE jupiter_local_ddc_us_east_1;
cqlsh> DROP KEYSPACE jupiter_local_ddc_us_east_1_local_ddc;

# Verify only new keyspaces remain
cqlsh> DESCRIBE KEYSPACES;
```

**Why this is required:**

- Kubernetes pods don't automatically restart when ConfigMaps change
- ScyllaDB keyspaces are created by DDC application during startup
- This manual step is part of the migration process for keyspace changes
- Keyspace changes typically involve data migration and replication strategy updates
- These broader migration concerns are beyond the scope of this Terraform module

### Prevention Checklist

**Before deploying, verify:**

- ✅ Using custom VPC (not default VPC)
- ✅ Using custom route tables (not default route tables)
- ✅ Following example patterns exactly
- ✅ **Subnets properly tagged for EKS Auto Mode**
- ✅ GitHub PAT has correct permissions
- ✅ Secret contains username and accessToken fields
- ✅ Route53 hosted zone exists
- ✅ Certificate ARN is valid

**After deploying, verify:**

- ✅ Functional test passes
- ✅ All pods are running
- ✅ DNS resolves correctly
- ✅ API endpoints respond

**Before destroying, verify:**

- ✅ In correct directory with terraform.tfstate
- ✅ No critical data needs backup
- ✅ Destroy plan looks reasonable

## Configuration Management

**Terraform Scope:**

- **Infrastructure**: EKS, NLB, IAM, S3, ScyllaDB (full state tracking)
- **Application Bootstrap**: Initial Helm deployment (trigger-based)

**Runtime Changes:**

- **Terraform**: Cannot track Helm/kubectl changes after initial deployment
- **Detection**: `terraform plan` may show "No changes" despite actual drift
- **Resolution**: Use `terraform apply -replace` to resync state

**Change Management Options:**

**Option 1: Terraform-Only**

```bash
# Make changes in Terraform configuration
# Force redeployment to sync state
terraform apply -replace='module.unreal_cloud_ddc.module.ddc_services[0].null_resource.helm_ddc_app'
```

**Option 2: GitOps (ArgoCD/Flux)**

- **Terraform**: Manages infrastructure only
- **GitOps**: Manages application lifecycle with Git-based state tracking
- **Benefit**: ArgoCD detects manual changes and can revert them automatically

**Option 3: Manual + Resync**

```bash
# Make manual changes for testing
helm upgrade cgd-unreal-cloud-ddc-initialize ./charts/ddc-wrapper --set replicaCount=5

# Resync when needed
terraform apply -replace='module.unreal_cloud_ddc.module.ddc_services[0].null_resource.helm_ddc_app'
```

**ArgoCD Advantage:**

- **Git State**: All changes tracked in Git repository
- **Drift Detection**: Automatic detection of manual changes
- **Self-Healing**: Can automatically revert unauthorized changes (if configured)
- **Rollback**: Easy rollback to previous Git commits
- **Manual Changes**: Still require Git commits to persist, otherwise ArgoCD reverts them

## Advanced Topics

### Terraform + Kubernetes Coordination Challenges

This module manages both AWS infrastructure and Kubernetes applications in a single Terraform state. This creates coordination challenges that require careful architectural decisions to handle reliably.

#### The Apply Challenge: Provider Configuration Timing

**The Problem**: When using ONLY the `kubernetes` provider, it requires **two-step apply** when creating EKS clusters and Kubernetes resources in the same Terraform state.

```bash
# Standard approach requires two steps:
terraform apply -target=module.eks_cluster  # Step 1: Create EKS
terraform apply                              # Step 2: Create Kubernetes resources
```

**Why This Happens**: Terraform evaluates ALL provider configurations during the plan phase, but EKS clusters don't exist yet, causing provider initialization to fail.

**Our Solution**: We use BOTH the `kubernetes` and `kubectl` providers strategically:

- **`kubernetes` provider**: For standard Kubernetes resources (services, deployments, etc.)
- **`kubectl` provider**: For CRDs and resources that need lazy authentication (TargetGroupBinding)

The `kubectl` provider uses **lazy authentication** - connecting only when needed during apply, not during plan. This allows single-step deployment without explicit provider configuration.

#### The Destroy Challenge: Asynchronous Resource Cleanup

**The Problem**: When `terraform destroy` runs, Kubernetes controllers work asynchronously. Terraform thinks resources are deleted, but AWS cleanup is still happening in the background.

```
terraform destroy
├── Kubernetes: "TargetGroupBinding deleted" ✅ (returns immediately)
├── AWS Load Balancer Controller: Starts cleanup... ⏳ (asynchronous)
├── Terraform: Destroys EKS cluster ❌ (too early!)
└── Result: Orphaned ENIs block VPC deletion ❌
```

**What Gets Orphaned**:

- **ENIs (Elastic Network Interfaces)** - Primary cause of VPC deletion failures
- **Security Group Rules** - Ingress rules for target group access
- **Target Group Attachments** - Links between target groups and pod IPs

**Our Solution**: Enhanced cleanup with AWS API polling to ensure actual resource cleanup completion:

```bash
# Our cleanup script polls AWS directly
ENI_COUNT=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=${VPC_ID}")
if [ "$ENI_COUNT" = "0" ]; then
  echo "✅ Cleanup complete"
fi
```

#### Architectural Decision: Control Our Own Networking

**Standard Approach** (problematic):

```hcl
# Kubernetes creates AWS resources via controllers
kubernetes_service {
  type = "LoadBalancer"  # Creates NLB via controller
}
```

**Our Approach** (deterministic):

```hcl
# Terraform creates and manages AWS resources directly
resource "aws_lb" "nlb" {
  name = "${var.name}-nlb"
  # Terraform controls lifecycle
}

# Kubernetes service uses ClusterIP (no AWS resources)
kubernetes_service {
  type = "ClusterIP"  # No load balancer created
}

# TargetGroupBinding connects them
kubectl_manifest "target_group_binding" {
  # Only creates the binding, not the target group
}
```

**Why This Works Better**:

- **Clear ownership**: Terraform owns AWS resources, Kubernetes owns bindings
- **Predictable destroy**: Terraform destroys resources in reverse dependency order
- **Minimal async cleanup**: Only TargetGroupBinding managed by controller

#### Provider Strategy: Hybrid Approach

**We use BOTH providers strategically:**

| Provider     | Use Case                 | Why                          |
| ------------ | ------------------------ | ---------------------------- |
| `kubernetes` | Standard K8s resources   | Official, type-safe, stable  |
| `kubectl`    | CRDs, TargetGroupBinding | Lazy auth, single-step apply |

**Benefits of Hybrid Approach**:

- ✅ **Single terraform apply** - No complex workflows
- ✅ **Official provider** for most resources
- ✅ **Lazy authentication** for problematic resources
- ✅ **Type safety** where possible - Community vs HashiCorp official
- ❌ **YAML strings** - Less type-safe than HCL blocks
- ✅ **Single `terraform apply`** - No complex workflows
- ✅ **Production proven** - Widely used in enterprise

#### The Fundamental Challenge

**Terraform Philosophy**:

- Declarative: "Create these exact resources"
- Synchronous: "Wait for each resource to be ready"
- Deterministic: "Predictable lifecycle management"

**Kubernetes Philosophy**:

- Eventually consistent: "Reach desired state eventually"
- Asynchronous: "Controllers work in background"
- Non-deterministic: "Ready when ready"

**Our Bridge**: Use kubectl provider + enhanced cleanup to coordinate between these paradigms while maintaining the best user experience.

### DNS Propagation Considerations

**Risk by Access Pattern**:

- **Public Access**: **HIGH** - Uses public DNS requiring propagation time
- **Private Access**: **LOW** - Uses private DNS within VPC
- **Hybrid Access**: **MEDIUM** - Depends on which endpoint kubectl uses

**Mitigation**: The kubectl provider has built-in retry logic that usually handles DNS propagation delays automatically.

### Provider Configuration: kubectl vs kubernetes

#### Why Both Providers?

The DDC module uses both `kubectl` and `kubernetes` providers for different purposes:

- **kubernetes provider**: Standard Kubernetes resources (namespaces, services, etc.)
- **kubectl provider**: TargetGroupBinding CRD only

#### Technical Reason

The `kubectl` provider enables **single-apply deployment** by deferring cluster API validation until apply phase:

| Provider              | Plan Phase Behavior                           | Single-Apply Compatible   |
| --------------------- | --------------------------------------------- | ------------------------- |
| `kubernetes_manifest` | Validates CRD schemas (requires live cluster) | ❌ Fails during bootstrap |
| `kubectl_manifest`    | Treats YAML as string (no cluster connection) | ✅ Works during bootstrap |

#### Multi-Region Requirements

Both providers require aliases for multi-region deployments:

```hcl
providers = {
  kubernetes = kubernetes.primary  # Standard K8s resources
  helm       = helm.primary       # Helm charts
  kubectl    = kubectl.primary    # TargetGroupBinding CRD
}
```

This ensures each region's TargetGroupBinding is applied to the correct EKS cluster.

### Enhanced Cleanup

This module includes enhanced cleanup logic to address common Terraform + Kubernetes coordination issues:

- **AWS state polling**: Checks actual AWS resource state during cleanup
- **Faster completion**: Returns when cleanup is actually done (vs waiting for timeout)
- **Progress feedback**: Shows cleanup progress via script output
- **Reduced orphaned resources**: Helps prevent ENIs and target attachments from blocking VPC deletion

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.16.0, < 3.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |
| <a name="provider_http"></a> [http](#provider\_http) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ddc_app"></a> [ddc\_app](#module\_ddc\_app) | ./modules/ddc-app | n/a |
| <a name="module_ddc_infra"></a> [ddc\_infra](#module\_ddc\_infra) | ./modules/ddc-infra | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
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
| [aws_vpc_endpoint.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.internal_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.nlb_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.nlb_to_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.cluster_from_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
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
| <a name="input_additional_vpc_associations"></a> [additional\_vpc\_associations](#input\_additional\_vpc\_associations) | Additional VPCs to associate with private zone (for cross-region access) | <pre>map(object({<br>    vpc_id = string<br>    region = string<br>  }))</pre> | `null` | no |
| <a name="input_allowed_external_cidrs"></a> [allowed\_external\_cidrs](#input\_allowed\_external\_cidrs) | CIDR blocks for external access. Use prefix lists for multiple IPs. | `list(string)` | `null` | no |
| <a name="input_bearer_token_replica_regions"></a> [bearer\_token\_replica\_regions](#input\_bearer\_token\_replica\_regions) | List of AWS regions to replicate the bearer token secret to for multi-region access | `list(string)` | `null` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ACM certificate ARN for HTTPS listeners (required for internet-facing services unless debug\_mode enabled) | `string` | `null` | no |
| <a name="input_create_bearer_token"></a> [create\_bearer\_token](#input\_create\_bearer\_token) | Create new DDC bearer token secret. Set to false in secondary regions to use existing token from primary region. | `bool` | `true` | no |
| <a name="input_create_private_dns_records"></a> [create\_private\_dns\_records](#input\_create\_private\_dns\_records) | Create private DNS records (set to false for secondary regions to avoid conflicts) | `bool` | `true` | no |
| <a name="input_ddc_application_config"></a> [ddc\_application\_config](#input\_ddc\_application\_config) | DDC application configuration with flattened structure:<br><br>## DDC Logical Namespaces (→ Helm template)<br>- `default_ddc_namespace`: Fallback namespace for testing<br>- `ddc_namespaces`: Map of game project namespaces<br><br>## Main Pod Resources (→ Helm template)<br>- `instance_type`: EC2 instance type (m6i.xlarge, i4i.xlarge, c6a.xlarge, etc.)<br>- `cpu_requests`: CPU per pod ("2000m" = 2 cores)<br>- `memory_requests`: Memory per pod ("8Gi" = 8GB)<br>- `replica_count`: Number of DDC pods (independent of ScyllaDB nodes)<br><br>## DDC Application Config (→ Helm template)<br>- `ddc_access_group`: JWT group for basic access<br>- `ddc_admin_group`: JWT group for admin access<br>- `container_image`: Docker image URL<br>- `custom_helm_chart`: Custom chart path (local or remote)<br>- `worker_cpu_requests`: CPU for worker pods<br>- `worker_memory_requests`: Memory for worker pods<br><br>## Authentication (→ Terraform only)<br>- `bearer_token_secret_arn`: AWS Secrets Manager ARN<br><br>## Multi-Region Replication (→ Terraform + Helm template)<br>- `enable_multi_region_replication`: Enable cross-region data replication<br>- `replication_mode`: Replication strategy selection:<br>  * "speculative" (default): Proactively pushes new data to peer regions for lowest latency. Best for active multi-region development teams.<br>  * "on-demand": Pulls missing data from peer regions only when requested. Best for cost optimization with occasional cross-region access.<br>  * "hybrid": Combines both strategies for maximum performance and reliability. Best for production environments with mixed usage patterns.<br><br>## Deployment Orchestration (→ Terraform only)<br>- `cluster_ready_timeout_minutes`: Wait time for EKS nodes<br>- `enable_single_region_validation`: Run DDC tests after deploy<br>- `single_region_validation_timeout_minutes`: Test timeout<br>- `enable_multi_region_validation`: Run cross-region tests<br>- `peer_region_ddc_endpoint`: Other region endpoint for tests<br>- `multi_region_validation_timeout_minutes`: Cross-region test timeout | <pre>object({<br>    # DDC Logical Namespaces (→ Helm template)<br>    default_ddc_namespace = optional(string, "default")<br>    ddc_namespaces = optional(map(object({<br>      description = optional(string, "")<br>      regions = optional(list(string), [])  # List of regions for speculative (bidirectional) replication<br>    })), {})<br>    <br>    # Main Pod Resources (→ Helm template)<br>    instance_type    = optional(string, "i4i.xlarge")<br>    cpu_requests     = optional(string, "2000m")<br>    memory_requests  = optional(string, "8Gi")<br>    replica_count    = optional(number, 2)<br>    <br>    # DDC Application Config (→ Helm template)<br>    ddc_access_group     = optional(string, "app-cloud-ddc-project")<br>    ddc_admin_group      = optional(string, "cloud-ddc-admin")<br>    container_image = optional(string, "ghcr.io/epicgames/unreal-cloud-ddc:1.2.0")<br>    custom_helm_chart = optional(string, null)  # Custom chart path (local: "./my-chart" or remote: "oci://ghcr.io/myorg/chart:1.0.0")<br><br>    worker_cpu_requests  = optional(string, "1000m")<br>    worker_memory_requests = optional(string, "4Gi")<br>    <br>    # Authentication (→ Terraform only)<br>    bearer_token_secret_arn = optional(string, null)<br>    <br>    # Multi-Region Replication (→ Terraform + Helm template)<br>    enable_multi_region_replication = optional(bool, false)<br>    replication_mode = optional(string, "speculative")  # "speculative" (push), "on-demand" (pull), "hybrid" (both)<br>    <br>    # Deployment Orchestration (→ Terraform only)<br>    cluster_ready_timeout_minutes = optional(number, 10)<br>    enable_single_region_validation = optional(bool, true)<br>    single_region_validation_timeout_minutes = optional(number, 5)<br>    enable_multi_region_validation = optional(bool, false)<br>    peer_region_ddc_endpoint = optional(string, null)<br>    multi_region_validation_timeout_minutes = optional(number, 3)<br>  })</pre> | `{}` | no |
| <a name="input_ddc_infra_config"></a> [ddc\_infra\_config](#input\_ddc\_infra\_config) | Configuration object for DDC infrastructure (EKS, ScyllaDB, NLB, Kubernetes resources). <br>    Set to null to skip creating infrastructure.<br><br>    All infrastructure settings are grouped here for clear submodule alignment:<br>    - EKS cluster configuration and access patterns<br>    - ScyllaDB database configuration and multi-region setup<br>    - Node group configurations<br>    - Kubernetes namespace and service account settings<br><br>    This entire object gets passed to the ddc\_infra submodule. | <pre>object({<br>    # General Configuration<br>    name           = optional(string, "unreal-cloud-ddc")<br>    project_prefix = optional(string, "cgd")<br>    environment    = optional(string, "dev")<br>    region         = optional(string, null)<br><br>    # EKS Cluster Configuration<br>    kubernetes_version     = optional(string, "1.33")<br>    eks_node_group_subnets = optional(list(string), [])<br><br>    # EKS API Access Configuration (matches AWS provider exactly)<br>    endpoint_public_access  = optional(bool, true)<br>    endpoint_private_access = optional(bool, true)<br>    public_access_cidrs     = optional(list(string), null)<br><br>    # NVME Node Group<br>    nvme_managed_node_instance_type = optional(string, "i3en.large")<br>    nvme_managed_node_desired_size  = optional(number, 2)<br>    nvme_managed_node_max_size      = optional(number, 2)<br>    nvme_managed_node_min_size      = optional(number, 1)<br><br>    # Worker Node Group<br>    worker_managed_node_instance_type = optional(string, "c5.large")<br>    worker_managed_node_desired_size  = optional(number, 1)<br>    worker_managed_node_max_size      = optional(number, 1)<br>    worker_managed_node_min_size      = optional(number, 0)<br><br>    # System Node Group<br>    system_managed_node_instance_type = optional(string, "m5.large")<br>    system_managed_node_desired_size  = optional(number, 1)<br>    system_managed_node_max_size      = optional(number, 2)<br>    system_managed_node_min_size      = optional(number, 1)<br><br>    # ScyllaDB Configuration<br>    scylla_config = optional(object({<br>      current_region = object({<br>        datacenter_name    = optional(string, null)<br>        keyspace_suffix    = optional(string, null)<br>        replication_factor = optional(number, 3)  # Creates N ScyllaDB instances AND stores N data copies per key. Uses manual EC2 instances with persistent NVMe storage for optimal performance.<br><br>      })<br>      peer_regions = optional(map(object({<br>        datacenter_name    = optional(string, null)<br>        replication_factor = optional(number, 2)<br>      })), {})<br>      enable_cross_region_replication = optional(bool, true)<br>      keyspace_naming_strategy        = optional(string, "region_suffix")<br>      create_seed_node     = optional(bool, true)<br>      existing_scylla_seed = optional(string, null)<br>      scylla_source_region = optional(string, null)<br>      subnets              = optional(list(string), [])<br>      scylla_ami_name      = optional(string, "ScyllaDB 6.0.1")<br>      scylla_instance_type = optional(string, "i4i.2xlarge")<br>      scylla_architecture  = optional(string, "x86_64")<br>      scylla_db_storage    = optional(number, 100)<br>      scylla_db_throughput = optional(number, 200)<br>      scylla_ips_by_region = optional(map(list(string)), {})<br>    }), null)<br><br>    # Kubernetes Configuration<br>    kubernetes_namespace     = optional(string, "unreal-cloud-ddc")<br>    kubernetes_service_account_name = optional(string, "unreal-cloud-ddc-sa")<br><br>    # Certificate Management<br>    certificate_manager_hosted_zone_arn = optional(list(string), [])<br>    enable_certificate_manager          = optional(bool, false)<br><br>    # Multi-region IAM role sharing<br>    eks_cluster_role_arn = optional(string, null)<br>    eks_node_group_role_arns = optional(object({<br>      system_role = optional(string)<br>      worker_role = optional(string)<br>      nvme_role   = optional(string)<br>    }), {})<br>    oidc_provider_arn = optional(string, null)<br>  })</pre> | `null` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | Enable debug mode for detailed troubleshooting output. Currently enables Helm debug mode showing real-time installation progress, Kubernetes API calls, resource creation status, and template rendering. | `bool` | `false` | no |
| <a name="input_debug_mode"></a> [debug\_mode](#input\_debug\_mode) | Debug mode for development and troubleshooting. 'enabled' allows additional debug features including HTTP access. 'disabled' enforces production security settings. | `string` | `"disabled"` | no |
| <a name="input_eks_access_entries"></a> [eks\_access\_entries](#input\_eks\_access\_entries) | EKS access entries for granting cluster access to additional IAM principals (ArgoCD, CI/CD, team members).<br><br>    The cluster creator automatically gets admin access - this is for additional users/services.<br><br>    Example:<br>    eks\_access\_entries = {<br>      "argocd" = {<br>        principal\_arn = "arn:aws:iam::123456789012:role/ArgoCD-Role"<br>        policy\_associations = [{<br>          policy\_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"<br>          access\_scope = { type = "cluster" }<br>        }]<br>      }<br>    } | <pre>map(object({<br>    principal_arn = string<br>    type         = optional(string, "STANDARD")<br>    policy_associations = optional(list(object({<br>      policy_arn = string<br>      access_scope = object({<br>        type       = string<br>        namespaces = optional(list(string))<br>      })<br>    })), [])<br>  }))</pre> | `{}` | no |
| <a name="input_enable_centralized_logging"></a> [enable\_centralized\_logging](#input\_enable\_centralized\_logging) | Enable centralized logging with CloudWatch log groups following CGD Toolkit patterns | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name for deployment (dev, staging, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_external_prefix_list_id"></a> [external\_prefix\_list\_id](#input\_external\_prefix\_list\_id) | Managed prefix list ID for external access (recommended for multiple IPs) | `string` | `null` | no |
| <a name="input_ghcr_credentials_secret_arn"></a> [ghcr\_credentials\_secret\_arn](#input\_ghcr\_credentials\_secret\_arn) | ARN of AWS Secrets Manager secret containing GitHub credentials for Epic Games container registry access. Secret must contain 'username' and 'accessToken' fields for GHCR authentication. | `string` | `null` | no |
| <a name="input_is_primary_region"></a> [is\_primary\_region](#input\_is\_primary\_region) | Whether this is the primary region (for future use) | `bool` | `true` | no |
| <a name="input_load_balancers_config"></a> [load\_balancers\_config](#input\_load\_balancers\_config) | Load balancers configuration. Supports conditional creation based on presence. Currently implemented: NLB (Network Load Balancer). Future: ALB, GLB can be added to this structure. | <pre>object({<br>    nlb = optional(object({<br>      internet_facing = optional(bool, true)<br>      subnets         = list(string)<br>      security_groups = optional(list(string), [])<br>    }), null)<br>  })</pre> | `null` | no |
| <a name="input_log_group_prefix"></a> [log\_group\_prefix](#input\_log\_group\_prefix) | Prefix for CloudWatch log group names (useful for multi-module deployments) | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention period in days | `number` | `30` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for this workload | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources to. If not set, uses the default region from AWS credentials/profile. For multi-region deployments, this MUST be set to a different region than the default to avoid resource conflicts and duplicates. | `string` | `null` | no |
| <a name="input_route53_hosted_zone_name"></a> [route53\_hosted\_zone\_name](#input\_route53\_hosted\_zone\_name) | The name of the public Route53 Hosted Zone for DDC resources (e.g., 'yourcompany.com'). Creates region-specific DNS like us-east-1.ddc.yourcompany.com | `string` | `null` | no |
| <a name="input_ssm_retry_config"></a> [ssm\_retry\_config](#input\_ssm\_retry\_config) | SSM automation retry configuration for DDC keyspace initialization.<br><br>    max\_attempts: Maximum retry attempts to check for DDC readiness (default: 20 = 10 minutes)<br>    retry\_interval\_seconds: Seconds between retry attempts (default: 30)<br>    initial\_delay\_seconds: Initial delay before first check (default: 60)<br><br>    Total timeout: initial\_delay + (max\_attempts * retry\_interval)<br>    Default: 60s + (20 * 30s) = 660s (11 minutes) | <pre>object({<br>    max_attempts           = optional(number, 20)<br>    retry_interval_seconds = optional(number, 30)<br>    initial_delay_seconds  = optional(number, 60)<br>  })</pre> | <pre>{<br>  "initial_delay_seconds": 60,<br>  "max_attempts": 20,<br>  "retry_interval_seconds": 30<br>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IaC": "Terraform",<br>  "ModuleBy": "CGD-Toolkit",<br>  "ModuleName": "terraform-aws-unreal-cloud-ddc",<br>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc",<br>  "RootModuleName": "-"<br>}</pre> | no |
| <a name="input_vpc_endpoints"></a> [vpc\_endpoints](#input\_vpc\_endpoints) | VPC endpoints configuration for private AWS API access.<br><br>When enabled, eliminates need for internet egress and proxy infrastructure.<br>Each service can be enabled individually or reference existing endpoints.<br><br>## EKS Endpoint Benefits:<br>- Eliminates complex proxy NLB infrastructure (~$16/month → ~$7/month)<br>- True private access - no internet egress required<br>- Simplified security model<br>- Better performance - direct API access<br><br>## Example:<br>vpc\_endpoints = {<br>  eks = {<br>    enabled = true  # Replaces proxy NLB automatically<br>  }<br>}<br><br>## Supported Endpoints:<br>- eks: EKS API access (primary focus)<br>- ecr\_api: ECR API calls<br>- ecr\_dkr: ECR Docker registry<br>- s3: S3 API calls (Gateway endpoint) | <pre>object({<br>    eks = optional(object({<br>      enabled = bool<br>    }), null)<br>    s3 = optional(object({<br>      enabled         = bool<br>      route_table_ids = list(string)<br>    }), null)<br>    logs = optional(object({<br>      enabled = bool<br>    }), null)<br>    secretsmanager = optional(object({<br>      enabled = bool<br>    }), null)<br>    ssm = optional(object({<br>      enabled = bool<br>    }), null)<br>  })</pre> | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where resources will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_logs"></a> [access\_logs](#output\_access\_logs) | Access logs configuration |
| <a name="output_bearer_token_secret_arn"></a> [bearer\_token\_secret\_arn](#output\_bearer\_token\_secret\_arn) | ARN of the DDC bearer token secret |
| <a name="output_ddc_connection"></a> [ddc\_connection](#output\_ddc\_connection) | DDC connection information for this region |
| <a name="output_ddc_infra"></a> [ddc\_infra](#output\_ddc\_infra) | DDC infrastructure outputs |
| <a name="output_ddc_namespaces"></a> [ddc\_namespaces](#output\_ddc\_namespaces) | DDC namespace configuration |
| <a name="output_ddc_services"></a> [ddc\_services](#output\_ddc\_services) | DDC services outputs |
| <a name="output_default_ddc_namespace"></a> [default\_ddc\_namespace](#output\_default\_ddc\_namespace) | Default DDC logical namespace for API URLs and test scripts |
| <a name="output_dns_endpoints"></a> [dns\_endpoints](#output\_dns\_endpoints) | DNS endpoints for DDC services |
| <a name="output_iam_roles"></a> [iam\_roles](#output\_iam\_roles) | IAM role ARNs for sharing across regions |
| <a name="output_internet_facing"></a> [internet\_facing](#output\_internet\_facing) | Whether load balancers are internet-facing or internal |
| <a name="output_kubectl_command"></a> [kubectl\_command](#output\_kubectl\_command) | kubectl command to connect to EKS cluster |
| <a name="output_load_balancers"></a> [load\_balancers](#output\_load\_balancers) | Load balancer information |
| <a name="output_module_info"></a> [module\_info](#output\_module\_info) | Module metadata and configuration summary |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Standardized name prefix for consistent resource naming |
| <a name="output_nlb_arns"></a> [nlb\_arns](#output\_nlb\_arns) | List of NLB ARNs created by the module |
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
| <a name="output_vpc_endpoints"></a> [vpc\_endpoints](#output\_vpc\_endpoints) | VPC endpoint information including IDs and DNS names |
<!-- END_TF_DOCS -->

## Contributing

See the [Contributing Guidelines](../../../CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../../../LICENSE) file for details.

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                        | Version            |
| --------------------------------------------------------------------------- | ------------------ |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform)    | >= 1.11            |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                      | >= 6.0.0           |
| <a name="requirement_helm"></a> [helm](#requirement_helm)                   | >= 2.16.0, < 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement_kubectl)          | >= 1.14.0          |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement_kubernetes) | >=2.33.0           |
| <a name="requirement_null"></a> [null](#requirement_null)                   | >= 3.1             |
| <a name="requirement_random"></a> [random](#requirement_random)             | >= 3.1             |
| <a name="requirement_time"></a> [time](#requirement_time)                   | >= 0.9             |

## Providers

| Name                                                      | Version |
| --------------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)          | 6.11.0  |
| <a name="provider_http"></a> [http](#provider_http)       | 3.5.0   |
| <a name="provider_random"></a> [random](#provider_random) | 3.7.2   |

## Modules

| Name                                                                    | Source                 | Version |
| ----------------------------------------------------------------------- | ---------------------- | ------- |
| <a name="module_ddc_infra"></a> [ddc_infra](#module_ddc_infra)          | ./modules/ddc-infra    | n/a     |
| <a name="module_ddc_services"></a> [ddc_services](#module_ddc_services) | ./modules/ddc-services | n/a     |

## Resources

| Name                                                                                                                                                                    | Type        |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_cloudwatch_log_group.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                | resource    |
| [aws_cloudwatch_log_group.infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                             | resource    |
| [aws_cloudwatch_log_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                    | resource    |
| [aws_lb.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)                                                                            | resource    |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)                                                         | resource    |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)                                                        | resource    |
| [aws_lb_target_group.nlb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                                     | resource    |
| [aws_route53_record.scylla_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                                         | resource    |
| [aws_route53_record.scylla_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                                           | resource    |
| [aws_route53_record.service_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                                        | resource    |
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)                                                    | resource    |
| [aws_route53_zone_association.additional_vpcs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone_association)                    | resource    |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)                                                             | resource    |
| [aws_s3_bucket_policy.logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)                                        | resource    |
| [aws_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                   | resource    |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)   | resource    |
| [aws_security_group.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                               | resource    |
| [aws_security_group.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                                    | resource    |
| [aws_ssm_association.scylla_keyspace_replication_fix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association)                      | resource    |
| [aws_ssm_document.scylla_keyspace_replication_fix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document)                            | resource    |
| [aws_vpc_security_group_egress_rule.internal_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule)        | resource    |
| [aws_vpc_security_group_egress_rule.nlb_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule)             | resource    |
| [aws_vpc_security_group_egress_rule.nlb_to_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule)         | resource    |
| [aws_vpc_security_group_ingress_rule.eks_cluster_from_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource    |
| [aws_vpc_security_group_ingress_rule.internal_scylla_cql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)  | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_from_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)       | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_http_cidrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)       | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_http_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)      | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_http_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)         | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_https_cidrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)      | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_https_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)     | resource    |
| [aws_vpc_security_group_ingress_rule.nlb_https_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)        | resource    |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)                                                                   | resource    |
| [random_password.ddc_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                                    | resource    |
| [random_string.bearer_token_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)                                              | resource    |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                           | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account)                                      | data source |
| [aws_iam_policy_document.logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                               | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                             | data source |
| [aws_secretsmanager_secret_version.existing_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version)        | data source |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc)                                                                      | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http)                                                                 | data source |

## Inputs

| Name                                                                                                               | Description                                                                             | Type                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Default                                                                                                       | Required |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | :------: |
| <a name="input_additional_vpc_associations"></a> [additional_vpc_associations](#input_additional_vpc_associations) | Additional VPCs to associate with private zone (for cross-region access)                | <pre>map(object({<br> vpc_id = string<br> region = string<br> }))</pre>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `{}`                                                                                                          |    no    |
| <a name="input_allowed_external_cidrs"></a> [allowed_external_cidrs](#input_allowed_external_cidrs)                | CIDR blocks for external access. Use prefix lists for multiple IPs.                     | `list(string)`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `[]`                                                                                                          |    no    |
| <a name="input_ddc_application_config"></a> [ddc_application_config](#input_ddc_application_config)                | DDC application configuration including namespaces and authentication.                  | <pre>object({<br> namespaces = map(object({<br> description = optional(string, "")<br> prevent_deletion = optional(bool, false)<br> deletion_policy = optional(string, "retain")<br> }))<br> bearer_token_secret_arn = optional(string, null)<br> })</pre>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | <pre>{<br> "namespaces": {<br> "default": {<br> "description": "Default DDC namespace"<br> }<br> }<br>}</pre> |    no    |
| <a name="input_ddc_infra_config"></a> [ddc_infra_config](#input_ddc_infra_config)                                  | Configuration object for DDC infrastructure (EKS, ScyllaDB, NLB, Kubernetes resources). | <pre>object({<br> name = optional(string, "unreal-cloud-ddc")<br> project_prefix = optional(string, "cgd")<br> environment = optional(string, "dev")<br> region = optional(string, null)<br> create_seed_node = optional(bool, true)<br> existing_scylla_seed = optional(string, null)<br> scylla_source_region = optional(string, null)<br> kubernetes_version = optional(string, "1.33")<br> eks_node_group_subnets = optional(list(string), [])<br> scylla_replication_factor = optional(number, 3)<br> scylla_subnets = optional(list(string), [])<br> scylla_ami_name = optional(string, "ScyllaDB 6.0.1")<br> scylla_instance_type = optional(string, "i4i.2xlarge")<br> scylla_architecture = optional(string, "x86_64")<br> scylla_db_storage = optional(number, 100)<br> scylla_db_throughput = optional(number, 200)<br> eks_api_access_cidrs = optional(list(string), [])<br> eks_cluster_public_access = optional(bool, true)<br> eks_cluster_private_access = optional(bool, true)<br> unreal_cloud_ddc_namespace = optional(string, "unreal-cloud-ddc")<br> unreal_cloud_ddc_service_account_name = optional(string, "unreal-cloud-ddc-sa")<br> certificate_manager_hosted_zone_arn = optional(list(string), [])<br> enable_certificate_manager = optional(bool, false)<br> additional_nlb_security_groups = optional(list(string), [])<br> additional_eks_security_groups = optional(list(string), [])<br> scylla_ips_by_region = optional(map(list(string)), {})<br> })</pre> | `null`                                                                                                        |    no    |

## Outputs

| Name                                                                                                     | Description                                                 |
| -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| <a name="output_bearer_token_secret_arn"></a> [bearer_token_secret_arn](#output_bearer_token_secret_arn) | ARN of the DDC bearer token secret for multi-region sharing |
| <a name="output_ddc_endpoint"></a> [ddc_endpoint](#output_ddc_endpoint)                                  | DDC service endpoint URL                                    |
| <a name="output_ddc_infra"></a> [ddc_infra](#output_ddc_infra)                                           | DDC infrastructure outputs (EKS, ScyllaDB, etc.)            |
| <a name="output_ddc_services"></a> [ddc_services](#output_ddc_services)                                  | DDC services outputs (Helm releases, etc.)                  |
| <a name="output_iam_roles"></a> [iam_roles](#output_iam_roles)                                           | IAM roles for multi-region sharing                          |
| <a name="output_kubectl_command"></a> [kubectl_command](#output_kubectl_command)                         | Command to configure kubectl access to the EKS cluster      |
| <a name="output_private_zone_id"></a> [private_zone_id](#output_private_zone_id)                         | Private hosted zone ID for additional VPC associations      |

<!-- END_TF_DOCS -->
