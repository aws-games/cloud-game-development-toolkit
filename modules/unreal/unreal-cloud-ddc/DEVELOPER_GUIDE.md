# Developer Reference Guide

> **Technical deep dive for developers working with the Unreal Cloud DDC Terraform module**
>
> This document provides comprehensive technical guidance for understanding, extending, and troubleshooting the DDC module's EKS-based architecture.

## Prerequisites

> **See [Main README Prerequisites](../README.md#prerequisites)** for tools and access requirements.
> **See [General Developer Guide](../../DEVELOPER_GUIDE.md)** for CGD Toolkit development setup.

**DDC-Specific Requirements**:
- Epic Games GitHub organization access
- Understanding of Kubernetes concepts
- Familiarity with Helm charts and EKS Auto Mode

## Document Purpose

This developer reference serves multiple audiences:

**For Module Contributors**: Deep technical understanding of architecture decisions, implementation patterns, and extension points

**For Troubleshooting**: Comprehensive diagnosis procedures, known issues, and proven solutions with historical context

**For Advanced Users**: Configuration patterns, performance optimization, and integration with other systems

**What This Document Covers**:
- Architecture decisions and rationale
- EKS Auto Mode implementation details
- Terraform + Kubernetes coordination challenges
- Troubleshooting procedures with exact commands
- Configuration patterns for different use cases
- Performance optimization and scaling guidance

**What This Document Does NOT Cover**:
- Basic deployment instructions (see main README)
- User-facing configuration examples (see main README)
- General CGD Toolkit concepts (see root documentation)

## VPC Configuration Pattern

**IMPORTANT**: CodeBuild projects automatically use the same subnets as EKS node groups for simplicity and security.

**Pattern**: `ddc_infra_config.eks_node_group_subnets` → CodeBuild VPC configuration

**Why This Design**:
- **Simplicity**: No separate subnet configuration needed for CodeBuild
- **Security**: CodeBuild runs in private subnets with NAT Gateway access
- **Consistency**: Same network context as EKS workloads
- **No Complexity**: Avoids additional VPC configuration variables

**User Configuration**:
```hcl
ddc_infra_config = {
  eks_node_group_subnets = aws_subnet.private[*].id  # CodeBuild uses these same subnets
}
```

**Result**: All CodeBuild projects (cluster setup, app deployment, testing) run in the same private subnets as EKS nodes, ensuring consistent network access patterns and security posture.

**Key Technology Note**: This module uses **Helm extensively** for both infrastructure and application deployment. Helm charts configure NodePools, install infrastructure components (AWS Load Balancer Controller, Cert Manager), and optionally deploy DDC applications (depending on your module configuration). Understanding Helm's role is critical for working with this module.

**Helm TLDR**: Think of Helm like `package.json` (Node.js) or `pyproject.toml` (Python) but for Kubernetes - it bundles multiple Kubernetes resources into reusable "charts" with templating and dependency management. [Learn more about Helm](https://helm.sh/docs/intro/using_helm/).

## Naming Conventions

**Core Pattern**: All resources use `name_prefix` for consistent naming across AWS and Kubernetes.

**Name Prefix Construction**:
```hcl
# Parent Module
project_prefix = "cgd"           # User configurable (default: "cgd")
environment = "dev"              # User configurable (default: "dev")
name = "unreal-cloud-ddc"        # Module name (default: "unreal-cloud-ddc")

# Submodules
local.name_prefix = "${var.project_prefix}-${var.name}-${var.environment}"  # Result: "cgd-unreal-cloud-ddc-dev"
```

**Resource Naming**:
- **Namespace**: `${name_prefix}` (e.g., `cgd-unreal-cloud-ddc-dev`)
- **Service**: `${name_prefix}` (e.g., `cgd-unreal-cloud-ddc-dev`)
- **TargetGroupBinding**: `${name_prefix}` (e.g., `cgd-unreal-cloud-ddc-dev`)
- **EKS Cluster**: `${name_prefix}` (e.g., `cgd-unreal-cloud-ddc-dev`)

**Why This Works**: kubectl commands specify resource types explicitly, so no suffixes needed:
```bash
kubectl get svc ${name_prefix}           # Obviously a service
kubectl get targetgroupbinding ${name_prefix}  # Obviously a TargetGroupBinding
```

**Variable Flow**: `parent module vars` → `submodule vars` → `local.name_prefix` → `resources`

## Navigation
- [Architecture Deep Dive](#architecture-deep-dive) - Infrastructure patterns, EKS Auto Mode, networking
- [Configuration Patterns](#configuration-patterns) - DDC namespaces, node pools, multi-region coordination
- [Development Workflows](#development-workflows) - Terraform coordination, state management, CI/CD
- [Troubleshooting](#troubleshooting) - Diagnosis procedures, known issues, emergency procedures
- [Extension Patterns](#extension-patterns) - Advanced configurations, performance tuning, customization
- [Quick Reference](#quick-reference) - Critical commands and emergency procedures

## INFRASTRUCTURE CONFIG

**TLDR**: The module separates infrastructure (EKS, databases, load balancers) from applications (DDC pods) through distinct submodules. This enables both full-stack Terraform deployments and infrastructure-only deployments that support GitOps workflows. Terraform coordinates with Kubernetes using local-exec provisioners for reliable single-apply deployments.

### Infrastructure vs Application Separation

The DDC module follows CGD Toolkit's standard pattern of separating infrastructure from application concerns through distinct submodules:

```
Unreal Cloud DDC Module
├── ddc-infra (Infrastructure Submodule)
│   ├── EKS Cluster + OIDC Provider
│   ├── AWS Load Balancer Controller + CRDs
│   ├── TargetGroupBinding (infrastructure connectivity)
│   ├── Fluent Bit (cluster-wide logging)
│   ├── Cert Manager (SSL infrastructure)
│   ├── ScyllaDB Database
│   ├── S3 Bucket + IAM Roles
│   └── Network Load Balancer + Security Groups
└── ddc-app (Application Submodule)
    ├── DDC Helm Charts
    └── Application readiness checks
```

### Terraform + Kubernetes Coordination

**Current Implementation: CodeBuild + Terraform Actions** ✅ **MIGRATED FROM LOCAL-EXEC**

The module uses CodeBuild projects triggered by Terraform Actions to coordinate between AWS infrastructure and Kubernetes resources. This approach handles timing dependencies where Kubernetes resources must be created after EKS cluster is ready:

```hcl
# Example: CodeBuild project for cluster setup
resource "terraform_data" "cluster_setup_trigger" {
  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.cluster_setup]
    }
  }
  depends_on = [aws_eks_cluster.unreal_cloud_ddc_eks_cluster]
}
```

**Why CodeBuild + Terraform Actions?**
- **Reliable Execution**: CodeBuild provides consistent runtime environment
- **VPC Integration**: Runs in same private subnets as EKS nodes
- **Synchronous Control**: Terraform Actions wait for CodeBuild completion
- **Audit Trail**: All operations logged in CloudWatch
- **No Local Dependencies**: No kubectl/helm required on Terraform runner
- **Scalable**: Can handle complex multi-step operations

**What Terraform Actually Tracks**:
- **Execution Status**: Did the command run successfully? (exit code 0)
- **Trigger Values**: When to re-run commands based on `triggers` block
- **NOT the actual Kubernetes state**: Terraform doesn't know if you manually change pods/services

**Trigger-Based Re-execution**:
```hcl
triggers = {
  cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  region = var.region
  role_arn = aws_iam_role.aws_load_balancer_controller_role[0].arn
}
```
- Commands only re-run when trigger values change
- Manual cluster changes don't trigger re-execution
- Changing any trigger value forces command re-execution

**When Manual Re-execution is Needed**:

Triggers automatically handle most common changes (cluster name, region, IAM role ARNs), but some scenarios require manual intervention:

- **External Changes**: Manual kubectl/helm changes not tracked by Terraform
- **Failed Deployments**: Component installation failed but Terraform state shows "success"
- **Version Updates**: Upgrading Helm chart versions or Kubernetes addons
- **Configuration Drift**: Cluster configuration changed outside Terraform
- **Troubleshooting**: Testing fixes or investigating component issues
- **Emergency Recovery**: Restoring components after cluster issues

**Manual Re-execution Options**:
For troubleshooting or when you need to force component updates, you have three options:

**Option 1: Terraform Replace (Recommended)**:
```bash
# Force specific component to re-run
terraform apply -replace="null_resource.aws_load_balancer_controller"
terraform apply -replace="null_resource.target_group_binding"
terraform apply -replace="null_resource.cert_manager"

# Multiple components
terraform apply -replace="null_resource.aws_load_balancer_controller" -replace="null_resource.target_group_binding"
```

## Pre-PR Checklist

**Required Before Submission**:
- [ ] **Upgrade Kubernetes version to 1.35** in EKS cluster configuration
- [ ] Validate all examples work with K8s 1.35
- [ ] Update any version-specific documentation
- [ ] Run integration tests with new K8s version

**Documentation Updates**:
- [x] DDC_TF_ACTIONS_REFACTOR.md updated to reflect completion
- [x] DEVELOPER_GUIDE.md updated with CodeBuild patterns
- [x] VPC configuration pattern documented
- [ ] Main README review for accuracyy)**:
```bash
# Mark resource for recreation
terraform taint null_resource.aws_load_balancer_controller
terraform apply
```

**Option 3: Manual Command Execution**:
Run the exact same commands from the `local-exec` blocks manually. These are examples of common operations, but the actual commands can be lengthy with many parameters, so using `-replace` is usually simpler:
```bash
# Configure kubectl access first
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Example: Install AWS Load Balancer Controller (actual command has many more parameters)
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=<role-arn>

# Example: Create TargetGroupBinding directly
kubectl apply -f - <<EOF
apiVersion: eks.amazonaws.com/v1
kind: TargetGroupBinding
metadata:
  name: <name-prefix>-tgb
  namespace: <namespace>
spec:
  serviceRef:
    name: <service-name>  # Replace with your service name (default: name_prefix, e.g., cgd-unreal-cloud-ddc)
    port: 80
  targetGroupARN: <target-group-arn>
  targetType: ip
EOF
```

**Logging and Error Handling**:
- **Visible Output**: All command output appears in `terraform apply` logs
- **Error Detection**: Non-zero exit codes fail the Terraform apply
- **Debugging**: Can copy/paste exact commands for manual troubleshooting
- **Structured Logging**: Each command prefixed with `[COMPONENT]` for easy filtering
- **Command Tracing**: Each step logged with timestamps for performance analysis

**Future Direction: Terraform Actions**

Future versions will migrate to **Terraform Actions** for post-deployment configuration:
- **Cleaner Separation**: Infrastructure deployment separate from application configuration
- **Better Error Handling**: More sophisticated retry and rollback mechanisms  
- **GitOps Integration**: Easier integration with ArgoCD/Flux workflows
- **Improved Testing**: Infrastructure and application concerns can be tested independently

**Alternative Deployment Patterns**:

Users can deploy only infrastructure via this module and handle application deployment separately:
- **Manual Helm deployment**: Deploy Helm charts directly to the Kubernetes cluster
- **CI/CD pipelines**: Use GitHub Actions, GitLab CI, or Jenkins for application deployment
- **GitOps tools**: Use ArgoCD, Flux, or similar tools for declarative application management
- **Custom automation**: Build your own deployment automation using the infrastructure foundation

This approach supports both full-stack Terraform deployments and GitOps-managed application deployment.

## COMPUTE

**TLDR**: This module uses EKS Auto Mode for automatic node provisioning based on pod requirements, eliminating manual node group management. However, EKS Auto Mode creates significant complexity when integrated with Terraform, requiring custom security group management and complex troubleshooting procedures. Traditional managed node groups may be simpler for infrastructure-as-code deployments.

### WHY EKS Auto Mode?

**EKS Auto Mode** is AWS's newest compute management approach that automatically handles node provisioning, scaling, and lifecycle management. Here's why this module uses it:

📖 **[Official AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode.html)**

**Key Benefits**:
- **Zero Node Management**: No manual node group configuration, scaling policies, or instance lifecycle management
- **Automatic Right-Sizing**: AWS automatically selects optimal instance types based on pod requirements
- **Cost Optimization**: Nodes are created/destroyed based on actual workload demand
- **Simplified Operations**: No need to manage node group updates, AMI versions, or Kubernetes version compatibility
- **Reduced Infrastructure Complexity**: Focus on workload requirements rather than node provisioning details

**EKS Compute Options Comparison**:

| Aspect | Managed Node Groups | Fargate | EKS Auto Mode (Node Pools) |
|--------|--------------------|---------|-----------------------------|
| **Node Management** | Manual node group creation/scaling | No nodes (serverless) | Automatic based on pod requests |
| **Instance Selection** | Pre-defined instance types | AWS-managed (no choice) | Dynamic selection based on workload |
| **Scaling** | Manual ASG configuration | Automatic per-pod | Automatic scale-up/down |
| **Updates** | Manual AMI/Kubernetes updates | Automatic (AWS-managed) | Automatic updates |
| **Cost** | Nodes run even when idle | Pay per pod/vCPU/memory | Nodes created only when needed |
| **Complexity** | High (ASGs, launch templates, etc.) | Low (no infrastructure) | Low (declare requirements only) |
| **Storage** | EBS, instance store (NVMe) | EBS only (no NVMe) | EBS, instance store (NVMe) |
| **Use Case** | Full control, persistent workloads | Stateless, event-driven | Balanced automation + flexibility |

**Managed Node Groups vs Node Pools**:

**Managed Node Groups (Traditional)**:
- **Static Configuration**: Pre-define instance types, min/max nodes, subnets
- **Manual Scaling**: Configure Auto Scaling Groups with scaling policies
- **Fixed Capacity**: Nodes exist whether workloads need them or not
- **Update Management**: Manual AMI updates, rolling updates, version compatibility
- **Resource Waste**: Pay for idle nodes during low usage periods

**Node Pools (EKS Auto Mode)**:
- **Dynamic Provisioning**: Nodes created automatically when pods are scheduled
- **Workload-Driven**: Instance types selected based on pod resource requests
- **Automatic Scaling**: Scale to zero when no workloads, scale up on demand
- **Hands-Off Updates**: AWS manages AMI updates and Kubernetes compatibility
- **Cost Efficient**: Only pay for nodes when workloads are actually running

**Why Custom Node Pools for DDC?**

This module creates a custom "comprehensive" node pool because DDC has specific requirements:

**Built-in Node Pools Limitations**:
- **"general-purpose"**: Includes m5, c5 instances but **no NVMe storage by default**
- **"system"**: Optimized for Kubernetes system pods, not application workloads
- **No Storage Control**: Can't guarantee NVMe availability for DDC cache performance

**Custom "comprehensive" Node Pool Benefits**:
- **NVMe Storage**: Defaults to "i" instance family (i4i, i3, i3en, etc.) with high-performance NVMe SSDs
- **User Configurable**: Instance families can be customized via `custom_nodepool_config.instance_categories`
- **DDC Performance Recommendations**: Follows Epic Games' recommended NVMe storage for optimal DDC cache performance ([Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine))
- **Validation**: Module enforces NVMe-compatible families ("i" or "d") to prevent performance issues

**Default vs Reality**: 
- **Module Default**: `instance_categories = ["i"]` (all NVMe families: i4i, i3, i3en, etc.)
- **EKS Auto Mode Selection**: Typically chooses i4i instances as they're newest and most available
- **User Override**: Can configure different instance families, but NVMe storage is required for DDC performance

### EKS Auto Mode Architecture Diagram

**What Gets Created**: Here's what nodes and pods are deployed by this module.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                EKS CLUSTER                                                 │
│  Name: cgd-unreal-cloud-ddc-cluster-{region}                                              │
│  Purpose: Kubernetes control plane + compute management                                    │
│  Config: node_pools = ["general-purpose", "system"] + custom "comprehensive"              │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
┌───────────────────▼─────────────────┐   │   ┌───────────────▼─────────────────┐
│        BUILT-IN NODE POOLS       │   │   │       CUSTOM NODE POOL        │
│  (AWS-Managed, Always Created)   │   │   │   ⭐ ONLY IF ENABLED ⭐       │
│                                  │   │   │                               │
│  ├─ "general-purpose"            │   │   │  Name: comprehensive          │
│  │   Purpose: All non-system pods│   │   │  Purpose: DDC + NVMe storage  │
│  │   Instances: m5, c5, etc.     │   │   │  Instances: i4i, m5, c5, etc.│
│  │   ⚠️ No NVMe by default        │   │   │  ✅ NVMe + EBS available      │
│  │                               │   │   │                               │
│  └─ "system"                     │   │   │  ❗ REALITY: Only i4i nodes   │
│      Purpose: K8s system pods    │   │   │     get created in practice   │
│      Instances: t3, m5, etc.     │   │   │     (user configurable)       │
└──────────────────────────────────┘   │   └───────────────────────────────┘
                    │                   │                   │
                    │                   │                   │
                    │                   │   ┌───────────────▼─────────────────┐
                    │                   │   │          NODECLASS            │
                    │                   │   │  (Infrastructure Config)      │
                    │                   │   │                               │
                    │                   │   │  Name: comprehensive-nodeclass│
                    │                   │   │  Subnets: {subnet_ids}        │
                    │                   │   │  Security Groups: {sg_ids}    │
                    │                   │   │  Storage: NVMe + EBS          │
                    │                   │   │  IAM Role: {node_role}        │
                    │                   │   └───────────────────────────────┘
                    │                   │                   │
                    ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              ACTUAL EC2 NODES                                            │
│  In practice, you'll likely see only i4i nodes from custom pool because DDC pods        │
│  have specific requirements that built-in pools can't meet                               │
│                                                                                             │
│  What you'll see in AWS Console:                                                         │
│  └─ Node: i4i.xlarge (comprehensive pool)                                               │
│      Purpose: ALL pods (system + infrastructure + DDC)                                   │
│      Features: NVMe SSD + EBS, user-configurable instance types                          │
│      Lifecycle: Created/destroyed based on pod requests                                  │
│                                                                                             │
│  Built-in pools exist but may not create nodes if custom pool handles all workloads     │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              ALL PODS ON SAME NODES                                      │
│  All pods typically schedule on the same i4i nodes                                       │
│                                                                                             │
│  ├─ System Pods (kube-system namespace)                                                 │
│  │   CoreDNS, kube-proxy, VPC CNI, EBS CSI Driver, Karpenter                           │
│  │   AWS Load Balancer Controller                                                        │
│  │   Fluent Bit                                                                          │
│  │                                                                                         │
│  ├─ Infrastructure Pods (cert-manager namespace)                                        │
│  │   Cert Manager                                                                        │
│  │                                                                                         │
│  ├─ TargetGroupBinding (unreal-cloud-ddc namespace)                                     │
│  │   Connects NLB to DDC service                                                         │
│  │                                                                                         │
│  └─ DDC Application Pods (unreal-cloud-ddc namespace)                                  │
│      DDC Pod 1, DDC Pod 2, etc. - CPU: 2 cores, RAM: 8GB, Storage: NVMe SSD            │
│                                                                                             │
│  All pods benefit from NVMe storage when on i4i nodes                                   │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### What Actually Gets Created

**Configuration vs. Reality:**

1. **Configuration**: 3 NodePools ("general-purpose", "system", "comprehensive")
2. **Typical Result**: Only i4i nodes from "comprehensive" pool get created
3. **Why**: The custom NodePool is more flexible and can handle all workload types
4. **Outcome**: All pods (system, infrastructure, DDC) run on the same i4i nodes

**This is optimal because:**
- All pods benefit from NVMe storage performance
- Simplified node management (fewer node types)
- Cost efficiency (no underutilized nodes)
- DDC gets the performance it needs without complex scheduling

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                 KUBERNETES SERVICES                                        │
│  Network abstraction layer that provides stable endpoints for pods                         │
│                                                                                             │
│  ├─ kube-dns (ClusterIP)                                                                   │
│  │   Purpose: Internal DNS resolution                                                       │
│  │   Endpoints: CoreDNS pods                                                               │
│  │                                                                                         │
│  └─ cgd-unreal-cloud-ddc-initialize (ClusterIP)                                           │
│      Purpose: DDC application endpoint                                                     │
│      Port: 80 → DDC pods                                                                   │
│      Endpoints: DDC Pod 1, DDC Pod 2                                                       │
│      External Access: Via TargetGroupBinding → NLB                                        │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Why We Use Custom Node Pool

**DDC Cache Performance**: DDC is a cache service that benefits significantly from high-speed local storage. While DDC can run on general-purpose instances (like c6i.4xlarge), we use NVMe storage-optimized instances for optimal cache performance.

**EKS Auto Mode Limitation**: Built-in node pools only support general-purpose instances (c, m, r families) without NVMe drives.

**Our Solution**: We create a custom NodePool that allows NVMe instance families (i4i, i3, i3en) and automatically provisions nodes when DDC pods request them.

**Module Flexibility**:
- ✅ **Custom NodePool**: Enabled by default in module, defaults to NVMe instances (i4i.xlarge)
- ✅ **User configurable**: Change instance type via `ddc_application_config.compute.instance_type`
- ✅ **Built-in fallback**: Module supports both custom and AWS-managed node pools
- ✅ **Performance options**: c6i.4xlarge works fine, i4i.xlarge provides optimal performance

**Key Benefits**:
- ✅ **Automatic provisioning**: EKS Auto Mode creates nodes when DDC pods need them
- ✅ **Storage optimization**: NVMe provides high-speed cache storage (recommended)
- ✅ **Cost optimization**: Nodes only created when DDC pods are scheduled
- ✅ **Zero configuration**: No manual node group management required

### DDC Logical Namespaces vs Kubernetes Namespaces

**⚠️ CRITICAL DISTINCTION**: DDC has TWO different types of namespaces that serve completely different purposes:

**1. DDC Logical Namespaces** (Application-Level Segmentation):
- **Purpose**: Game project isolation within DDC service
- **URL Structure**: `https://ddc.example.com/api/v1/refs/<ddc_namespace>/default/hash`
- **S3 Segmentation**: Objects stored with `<ddc_namespace>/` prefix in S3 bucket
- **Configuration**: Defined in `ddc_application_config.ddc_namespaces`
- **Examples**: "project1", "project2", "dev-sandbox"

**2. Kubernetes Namespace** (Infrastructure Container):
- **Purpose**: Infrastructure resource isolation within EKS cluster
- **Single namespace**: `unreal-cloud-ddc` (contains ALL DDC infrastructure)
- **Contains**: DDC pods, ScyllaDB, services, ConfigMaps, secrets
- **Shared**: One Kubernetes namespace serves all DDC logical namespaces

**Data Isolation & S3 Bucket Sharing**:
```
S3 Bucket Structure:
├── project1/          # DDC logical namespace 1
│   ├── assets/
│   └── metadata/
├── project2/          # DDC logical namespace 2
│   ├── assets/
│   └── metadata/
└── dev-sandbox/       # DDC logical namespace 3
    ├── assets/
    └── metadata/
```

**⚠️ CRITICAL S3 BUCKET RISK**: All DDC logical namespaces share the same S3 bucket. A bucket deletion impacts ALL game projects simultaneously.

**RECOMMENDED**: Consider S3 bucket replication for disaster recovery (requires manual setup outside this module):
```hcl
# Enable cross-region replication for disaster recovery
aws_s3_bucket_replication_configuration "ddc_replication" {
  # Replicate to secondary region
  destination {
    bucket = "arn:aws:s3:::backup-ddc-bucket"
  }
}
```

### Key Architectural Concepts

**1. Application-Driven Infrastructure**: With EKS Auto Mode, your DDC application configuration (CPU/memory requests, nodeSelector) determines what EC2 instances get created. Terraform doesn't specify instance types - the application does.

**2. Pod Scheduling Flow**:
```
DDC Pod Created → nodeSelector: instance-type=i4i.xlarge → Custom NodePool → Karpenter → i4i.xlarge Node
```

**User Configuration Options**:
```hcl
ddc_application_config = {
  compute = {
    instance_type = "i4i.xlarge"    # NVMe for optimal performance
    # OR
    instance_type = "c6i.4xlarge"   # General-purpose, still works fine
  }
}
```

**3. Application-Driven Infrastructure**:
- **Traditional**: "Create 3 m5.large nodes, then deploy applications"
- **EKS Auto Mode**: "Deploy applications with resource requirements, get appropriate nodes automatically"

**2. Pod → Node Mapping**:
```yaml
# In your Helm chart (what you configure):
nodeSelector:
  node.kubernetes.io/instance-type: "i4i.xlarge"
resources:
  requests:
    cpu: "2000m"     # 2 CPU cores
    memory: "8Gi"    # 8GB RAM

# What Karpenter does automatically:
# 1. Reads pod requirements
# 2. Finds NodePool that allows i4i instances
# 3. Creates i4i.xlarge EC2 instance
# 4. Kubernetes schedules pod on new node
```

**3. Resource Hierarchy**:
- **EKS Cluster**: Kubernetes control plane (managed by AWS)
- **NodePools**: Templates for what types of nodes to create
- **NodeClass**: Infrastructure configuration (subnets, security groups)
- **EC2 Nodes**: Actual compute instances (created automatically)
- **Pods**: Your application containers (scheduled by Kubernetes)
- **Services**: Network endpoints for accessing pods

**4. Who Manages What**:
- **AWS Manages**: EKS control plane, built-in NodePools, Karpenter
- **Terraform Manages**: NodeClass, custom NodePools, security groups, NLB
- **Kubernetes Manages**: Pod scheduling, service endpoints, container lifecycle
- **You Configure**: Pod requirements, application settings, resource requests

### Cert Manager Placement: Infrastructure vs Application

**DECISION: Cert Manager belongs in `ddc-infra` (Infrastructure Submodule)**

**Why Infrastructure**:
- **Cluster-wide service**: Provides SSL certificate management for any application
- **IRSA dependency**: Requires EKS OIDC provider (infrastructure-level component)
- **Reusable**: Other applications can request certificates without additional setup
- **Lifecycle independence**: Should persist even if DDC application is removed
- **GitOps compatibility**: Infrastructure should be ready for any deployment method

**Current Implementation Issue**:
```hcl
# ❌ CURRENT: Cert Manager in ddc-app module
module "ddc_app" {
  # cert-manager installed here - WRONG LOCATION
}

# ✅ SHOULD BE: Cert Manager in ddc-infra module
module "ddc_infra" {
  # cert-manager should be installed here - CORRECT LOCATION
}
```

**Migration Required**:
1. **Move cert-manager installation** from `ddc-app/main.tf` to `ddc-infra/eks.tf`
2. **Update IRSA role creation** to be in infrastructure module
3. **Update documentation** to reflect correct placement
4. **Test both deployment patterns** (full-stack and infrastructure-only)

**Benefits of Correct Placement**:
- ✅ **Infrastructure-only deployments**: Cert Manager available for GitOps applications
- ✅ **Consistent with other infrastructure**: Same pattern as Fluent Bit, AWS Load Balancer Controller
- ✅ **Proper lifecycle management**: Cert Manager persists across application deployments
- ✅ **IRSA role organization**: All infrastructure IRSA roles in same module

**Impact on Deployment Patterns**:

**Pattern 1: Full Stack** (no change in user experience):
```hcl
module "unreal_cloud_ddc" {
  ddc_infra_config = { /* ... */ }
  ddc_application_config = { /* ... */ }
}
# Result: Both infrastructure (including cert-manager) and application deployed
```

**Pattern 2: Infrastructure Only** (improved - cert-manager now available):
```hcl
module "unreal_cloud_ddc" {
  ddc_infra_config = { /* ... */ }
  # No ddc_application_config
}
# Result: Infrastructure including cert-manager ready for GitOps applications
```

**ArgoCD Application Example** (now works with SSL):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: unreal-cloud-ddc
spec:
  source:
    repoURL: https://github.com/your-org/ddc-charts
    path: charts/ddc-wrapper
    helm:
      values: |
        ingress:
          enabled: true
          annotations:
            cert-manager.io/cluster-issuer: "letsencrypt-prod"
          tls:
          - secretName: ddc-tls
            hosts:
            - us-east-1.ddc.example.com
```

**This change aligns with CGD Toolkit design standards and improves the module's flexibility for different deployment patterns.**

### Key Architectural Decisions

#### TargetGroupBinding in Infrastructure

**Why**: TargetGroupBinding connects Terraform-managed AWS resources (NLB target group) to Kubernetes services. This is infrastructure-level connectivity, not application-specific.

**Benefits**:
- **Always available**: Infrastructure ready for any deployment method
- **GitOps compatible**: ArgoCD can deploy applications using existing connectivity
- **Clear separation**: AWS resources managed by Terraform, K8s bindings managed by infrastructure

#### OIDC Provider in Infrastructure

**Why**: EKS OIDC Provider enables IRSA (IAM Roles for Service Accounts) for any Kubernetes workload, not just DDC applications.

**Benefits**:
- **Foundational service**: Required for AWS Load Balancer Controller, Fluent Bit, Cert Manager
- **Reusable**: Other applications can use IRSA without additional setup
- **Security**: Enables secure AWS API access without storing credentials

### Deployment Patterns

#### Pattern 1: Full Stack (Terraform)

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # Both infrastructure and application
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private[*].id
    scylla_config = { /* ... */ }
  }
  
  ddc_application_config = {
    namespaces = { /* ... */ }
    compute = { /* ... */ }
  }
}
```

**What Gets Deployed**:
- **ddc-infra**: EKS cluster, ScyllaDB, S3, NLB, OIDC, AWS Load Balancer Controller, TargetGroupBinding, Fluent Bit
- **ddc-app**: DDC Helm charts, Cert Manager, application configs
- **Single apply**: Everything deployed in one `terraform apply`

**Good For**: Small teams, development environments, simple deployments

#### Pattern 2: Infrastructure Only (Terraform + GitOps)

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # Infrastructure only
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private[*].id
    scylla_config = { /* ... */ }
  }
  
  # No ddc_application_config - applications managed by ArgoCD
}
```

**What Gets Deployed**:
- **ddc-infra**: EKS cluster, ScyllaDB, S3, NLB, OIDC, AWS Load Balancer Controller, TargetGroupBinding, Fluent Bit
- **ddc-app**: NOT deployed - managed separately by ArgoCD/Flux
- **GitOps ready**: Infrastructure provides foundation for application deployment

**ArgoCD Application Example**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: unreal-cloud-ddc
spec:
  source:
    repoURL: https://github.com/your-org/ddc-charts
    path: charts/ddc-wrapper
  destination:
    server: https://kubernetes.default.svc
    namespace: unreal-cloud-ddc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Good For**: Large teams, GitOps workflows, frequent application changes, compliance requirements

### Infrastructure Readiness

**What's Always Available After ddc-infra Deployment**:
- ✅ EKS cluster with OIDC provider
- ✅ AWS Load Balancer Controller installed
- ✅ TargetGroupBinding connecting NLB to DDC service
- ✅ Fluent Bit for cluster-wide logging
- ✅ ScyllaDB database ready for connections
- ✅ S3 bucket with proper IAM permissions
- ✅ All IRSA roles for AWS service access

**What Applications Need to Provide**:
- DDC service named `{name-prefix}-service` on port 80
- Service must be in the configured namespace
- Pods must be ready to receive traffic

### Migration Between Patterns

#### From Full Stack to Infrastructure-Only

**Process**:
1. **Remove application config** from Terraform
2. **Apply changes** (removes ddc-app resources)
3. **Deploy via ArgoCD** using existing infrastructure

```hcl
# Before: Full stack
module "unreal_cloud_ddc" {
  ddc_infra_config = { /* ... */ }
  ddc_application_config = { /* ... */ }  # Remove this
}

# After: Infrastructure only
module "unreal_cloud_ddc" {
  ddc_infra_config = { /* ... */ }
  # ArgoCD manages applications
}
```

#### From Infrastructure-Only to Full Stack

**Process**:
1. **Remove ArgoCD application** (to avoid conflicts)
2. **Add application config** to Terraform
3. **Apply changes** (deploys ddc-app resources)

### Benefits of This Architecture

#### For DevOps Teams
- **Clear ownership**: Infrastructure vs application responsibilities
- **Deployment flexibility**: Choose Terraform or GitOps for applications
- **Reduced blast radius**: Infrastructure changes don't affect applications
- **Faster iteration**: Application updates don't require infrastructure changes

#### For Development Teams
- **Self-service**: Deploy applications without infrastructure access
- **GitOps workflows**: Use familiar Git-based deployment processes
- **Faster feedback**: Application changes deploy in seconds, not minutes
- **Environment parity**: Same infrastructure, different application configs

#### For Platform Teams
- **Standardization**: Consistent infrastructure across all environments
- **Cost optimization**: Shared infrastructure for multiple applications
- **Security**: Infrastructure-level controls and compliance
- **Observability**: Centralized logging and monitoring at infrastructure level

This architecture enables teams to choose the deployment pattern that best fits their operational model while maintaining consistency and reliability.

## APPLICATION CONFIG

### Helm Architecture

#### Package Management for Kubernetes

**What is Helm**: Bundles multiple Kubernetes resources into reusable "charts"

**Comparisons**:
- **vs npm/package.json**: Helm charts are like npm packages, `values.yaml` is like package.json config
- **vs Docker Compose**: Compose defines containers, Helm defines K8s resources with templating
- **vs brew**: `helm install nginx` is like `brew install nginx` but for K8s clusters

#### Chart Architecture

**Epic's Official Chart**:
- **Location**: `oci://ghcr.io/epicgames/unreal-cloud-ddc`
- **Contains**: DDC application pods, services, config
- **Assumptions**: Standard K8s LoadBalancer service (creates AWS ELB)
- **Problem**: We use NLB created by Terraform, not K8s-managed ELB

**Our Wrapper Chart**:
- **Location**: `./charts/ddc-wrapper`
- **Purpose**: Customize Epic's chart for our architecture
- **Contains**: Epic's chart as dependency + our overrides
- **Customizations**: 
  - ClusterIP service (instead of LoadBalancer)
  - Custom configuration for Terraform-managed NLB
  - EKS Auto Mode compatibility (hostPath fixes)

**Our Infrastructure Chart**:
- **Location**: `./charts/ddc-infrastructure`
- **Purpose**: Just the TargetGroupBinding resource
- **Why Separate**: Different lifecycle than application

#### Chart Dependency Management

**How Epic's Chart Gets Downloaded**:

**Our Wrapper Chart Structure**:
```
ddc-wrapper/
├── Chart.yaml                    # Declares Epic's chart as dependency
├── templates/
│   └── deployment-override.yaml   # Our EKS Auto Mode fixes
└── charts/                        # Helm dependency storage (gitignored)
    └── unreal-cloud-ddc-1.2.0+helm.tgz  # Epic's chart (downloaded at runtime)
```

**Chart.yaml Dependency Declaration**:
```yaml
apiVersion: v2
name: ddc-wrapper
version: 1.0.0
description: A wrapper chart for Unreal Cloud DDC with EKS Auto Mode compatibility

dependencies:
  - name: unreal-cloud-ddc
    version: "1.2.0+helm"
    repository: "oci://ghcr.io/epicgames"
```

**Dependency Download Flow**:

**During Terraform Apply**:
1. **Terraform local-exec runs**: `helm dependency update charts/ddc-wrapper`
2. **Helm reads Chart.yaml**: Sees Epic's chart as dependency
3. **Helm checks local cache**: Looks in `charts/ddc-wrapper/charts/` directory
4. **If missing, downloads**: Pulls `unreal-cloud-ddc-1.2.0+helm.tgz` from `oci://ghcr.io/epicgames`
5. **Stores locally**: Saves to `charts/ddc-wrapper/charts/unreal-cloud-ddc-1.2.0+helm.tgz`
6. **Helm combines charts**: Merges Epic's chart + our wrapper overrides
7. **Deploys to cluster**: Single combined deployment

**Benefits of Wrapper Pattern**:
- ✅ **Use Epic's official chart**: Get updates and support from Epic
- ✅ **Add our customizations**: EKS Auto Mode, Terraform integration
- ✅ **Version control**: Pin to stable Epic chart versions
- ✅ **Maintainable**: Clear separation between Epic's code and our overrides

### Helm Values Architecture

#### Configuration Flow: Terraform → Template → Helm

**The Complete Flow**:
```
Terraform Variables → locals.tf → templatefile() → /tmp/ddc-values.yaml → helm install
```

**Step-by-Step Process**:

**1. Terraform Variables** (User Input):
```hcl
# User configures in their Terraform
ddc_application_config = {
  compute = {
    instance_type = "i4i.xlarge"
    cpu_requests = "2000m"
    memory_requests = "8Gi"
    replica_count = 2
  }
  namespaces = {
    "project1" = { description = "Main game project" }
    "project2" = { description = "DLC project" }
  }
}
```

**2. Local Processing** (locals.tf):
```hcl
locals {
  helm_config = {
    name_prefix = local.name_prefix
    instance_type = var.ddc_application_config.instance_type
    cpu_requests = var.ddc_application_config.cpu_requests
    # ... all other variables processed here
  }
  
  # Template processing with all variables
  helm_values_yaml = templatefile(
    "${path.module}/templates/unreal_cloud_ddc_consolidated.yaml",
    local.helm_config
  )
}
```

**3. Template Processing** (templatefile function):
```yaml
# templates/unreal_cloud_ddc_consolidated.yaml
fullnameOverride: "${name_prefix}"  # Becomes: cgd-unreal-cloud-ddc

replicaCount: ${replica_count}       # Becomes: 2

nodeSelector:
  node.kubernetes.io/instance-type: "${instance_type}"  # Becomes: i4i.xlarge

resources:
  requests:
    cpu: "${cpu_requests}"           # Becomes: 2000m
    memory: "${memory_requests}"     # Becomes: 8Gi
```

**4. Temporary File Creation** (main.tf):
```bash
# Step 5 in local-exec provisioner
cat > /tmp/ddc-values.yaml <<'VALUES'
${local.helm_values_yaml}  # Fully processed YAML content
VALUES
```

**5. Helm Deployment**:
```bash
# Step 7 in local-exec provisioner
helm upgrade --install cgd-unreal-cloud-ddc-app ./charts/ddc-wrapper \
  --values /tmp/ddc-values.yaml  # Uses our processed values
```

#### Why Temporary Files?

**Benefits of Temporary Files**:
- ✅ **Complex YAML structures**: Full YAML syntax support (lists, maps, multiline)
- ✅ **Special characters**: No escaping issues with quotes, newlines, etc.
- ✅ **Debugging**: Can inspect `/tmp/ddc-values.yaml` during troubleshooting
- ✅ **Helm compatibility**: Standard `--values` flag works with any complexity
- ✅ **Template validation**: YAML syntax errors caught early

**Security Considerations**:
- **Temporary location**: `/tmp/ddc-values.yaml` (cleaned up after deployment)
- **No secrets**: Bearer tokens and credentials come from Kubernetes secrets
- **Local only**: File exists only during Terraform apply execution

#### What We Hardcode vs What's Configurable

**Hardcoded Values** (Fixed for Architecture Compatibility):

```yaml
# Networking (required for NLB integration)
service:
  type: ClusterIP          # Must be ClusterIP for TargetGroupBinding
  port: 80                 # Standard HTTP port for NLB health checks

# NGINX disabled (architectural decision)
nginx:
  enabled: false           # Required for direct Kestrel access

# Resource naming (for clear identification)
fullnameOverride: "${name_prefix}"  # Ensures predictable resource names
```

**User-Configurable Values** (via Terraform Variables):

```yaml
# Compute resources (performance tuning)
replicaCount: ${replica_count}                    # User: ddc_application_config.replica_count
nodeSelector:
  node.kubernetes.io/instance-type: "${instance_type}"  # User: ddc_application_config.instance_type
resources:
  requests:
    cpu: "${cpu_requests}"                       # User: ddc_application_config.cpu_requests
    memory: "${memory_requests}"                 # User: ddc_application_config.memory_requests

# Application configuration (business logic)
config:
  S3:
    BucketName: ${bucket_name}                   # From: module.ddc_infra.s3_bucket_id
  Scylla:
    ConnectionString: "Contact Points=${database_host};Port=${database_port}"  # From: database_connection
```

### Deployment Patterns

#### Pattern 1: Full Stack (Terraform)

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # Both infrastructure and application
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private[*].id
    scylla_config = { /* ... */ }
  }
  
  ddc_application_config = {
    namespaces = { /* ... */ }
    compute = { /* ... */ }
  }
}
```

**What Gets Deployed**:
- **ddc-infra**: EKS cluster, ScyllaDB, S3, NLB, OIDC, AWS Load Balancer Controller, TargetGroupBinding, Fluent Bit
- **ddc-app**: DDC Helm charts, Cert Manager, application configs
- **Single apply**: Everything deployed in one `terraform apply`

**Good For**: Small teams, development environments, simple deployments

#### Pattern 2: Infrastructure Only (Terraform + GitOps)

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # Infrastructure only
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private[*].id
    scylla_config = { /* ... */ }
  }
  
  # No ddc_application_config - applications managed by ArgoCD
}
```

**What Gets Deployed**:
- **ddc-infra**: EKS cluster, ScyllaDB, S3, NLB, OIDC, AWS Load Balancer Controller, TargetGroupBinding, Fluent Bit
- **ddc-app**: NOT deployed - managed separately by ArgoCD/Flux
- **GitOps ready**: Infrastructure provides foundation for application deployment

**ArgoCD Application Example**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: unreal-cloud-ddc
spec:
  source:
    repoURL: https://github.com/your-org/ddc-charts
    path: charts/ddc-wrapper
  destination:
    server: https://kubernetes.default.svc
    namespace: unreal-cloud-ddc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Good For**: Large teams, GitOps workflows, frequent application changes, compliance requirements

#### Pattern 3: CI/CD Pipeline Deployment

**GitHub Actions Example**:
```yaml
name: Deploy DDC Application
on:
  push:
    branches: [main]
    paths: ['charts/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --region ${{ vars.AWS_REGION }} --name ${{ vars.CLUSTER_NAME }}
      - name: Deploy DDC
        run: |
          helm upgrade --install ddc-app ./charts/ddc-wrapper \
            --namespace unreal-cloud-ddc \
            --create-namespace \
            --values values-production.yaml
```

**Good For**: Teams with existing CI/CD, custom deployment logic, integration testing

### Instance Type Selection

#### NVMe Requirements

**Why NVMe**: DDC requires high-performance storage for cache operations

**Supported Instance Families**:
- `i4i.*` - Latest generation NVMe (recommended)
- `i3en.*` - Previous generation NVMe
- `i3.*` - Older generation NVMe

**Performance Characteristics**:
- **i4i.xlarge**: 4 vCPU, 32 GB RAM, 1x 937 GB NVMe SSD
- **i4i.2xlarge**: 8 vCPU, 64 GB RAM, 1x 1,875 GB NVMe SSD
- **i4i.4xlarge**: 16 vCPU, 128 GB RAM, 2x 1,875 GB NVMe SSD

## NETWORKING

**TLDR**: This module supports three distinct access patterns configured through user variables - public (everything internet-accessible), hybrid (public load balancer with private services), and private (VPC-internal only). The module uses Terraform-created NLB + TargetGroupBinding (Kubernetes CRD) to connect AWS load balancers to Kubernetes services. AWS Load Balancer Controller watches TargetGroupBinding resources and automatically registers/deregisters pod IPs in AWS target groups as pods start/stop. Pod IPs come directly from VPC subnet CIDR ranges via AWS VPC CNI, not from separate overlay networks. EKS networking behavior varies dramatically between compute types (Managed Nodes vs Fargate vs Auto Mode), affecting target registration, security groups, and subnet requirements. **Note**: This module currently only supports EKS Auto Mode.

### Access Patterns Overview

The Unreal Cloud DDC module supports three networking access patterns configured through your Terraform variables. **There are no defaults** - your configuration determines which pattern is deployed:

#### Pattern 1: Public Access
**Use Case**: Internet-accessible DDC for distributed teams, remote developers, cloud build systems
**Configuration**: Everything deployed in public subnets with internet access

```
Game Developers (Internet)
├── DNS Resolution: us-east-1.ddc.example.com (public Route53)
├── NLB (Public Subnets, Internet Gateway)
├── TargetGroupBinding (Kubernetes CRD)
├── DDC Service (ClusterIP)
├── DDC Pods (Public Subnets)
├── EKS Nodes (Public Subnets)
└── EKS Cluster API (Public Endpoint)
```

**Key Characteristics**:
- **Load Balancer**: Internet-facing NLB in public subnets
- **DNS**: Public Route53 hosted zone
- **EKS Cluster**: Public endpoint, nodes in public subnets
- **DDC Pods**: Running on nodes in public subnets
- **Security**: IP allowlist via `allowed_external_cidrs`
- **SSL**: Public ACM certificate with domain validation
- **Access**: Anyone with valid bearer token + allowed IP

#### Pattern 2: Hybrid Access
**Use Case**: Public load balancer for external access, but internal services remain private
**Configuration**: Public NLB, private internal infrastructure

```
Game Developers (Internet)
├── DNS Resolution: us-east-1.ddc.example.com (public Route53)
├── NLB (Public Subnets, Internet Gateway)
├── TargetGroupBinding (Kubernetes CRD)
├── DDC Service (ClusterIP)
├── DDC Pods (Private Subnets)
├── EKS Nodes (Private Subnets)
├── EKS Cluster API (Private Endpoint)
└── ScyllaDB (Private Subnets, VPC-only)
```

**Key Characteristics**:
- **Load Balancer**: Internet-facing NLB (public access point)
- **DNS**: Public Route53 hosted zone
- **EKS Cluster**: Private endpoint, nodes in private subnets
- **DDC Pods**: Running on nodes in private subnets
- **Internal Services**: ScyllaDB, S3 access via VPC endpoints
- **Security**: Public NLB + private service mesh
- **Access**: External clients → Public NLB → Private services

#### Pattern 3: Private Access (VPC-Internal)
**Use Case**: Enterprise environments with VPN/Direct Connect, high-security requirements
**Configuration**: Everything private, requires VPC connectivity

```
Game Developers (Corporate Network)
├── VPN/Direct Connect → VPC
├── DNS Resolution: us-east-1.ddc.cgd.local (private Route53)
├── NLB (Private Subnets, Internal-only)
├── TargetGroupBinding (Kubernetes CRD)
├── DDC Service (ClusterIP)
├── DDC Pods (Private Subnets)
├── EKS Nodes (Private Subnets)
└── EKS Cluster API (Private Endpoint)
```

**Key Characteristics**:
- **Load Balancer**: Internal NLB in private subnets
- **DNS**: Private Route53 hosted zone
- **EKS Cluster**: Private endpoint, nodes in private subnets
- **DDC Pods**: Running on nodes in private subnets
- **Access Requirements**: AWS Client VPN, Site-to-Site VPN, or Direct Connect
- **SSL**: Private ACM certificate or internal CA
- **Security**: VPC-internal only, no internet access

#### How to Configure Each Pattern

**Your configuration variables determine the access pattern:**

```hcl
# Replace with your actual Route53 zone IDs and subnet IDs

# Public Access - Configure for internet accessibility
ddc_infra_config = {
  nlb_internal = false                    # Internet-facing NLB
  route53_zone_id = "Z1234567890ABC"      # Public hosted zone
  allowed_external_cidrs = ["0.0.0.0/0"]  # Or restrict to office IPs
  eks_node_group_subnets = ["subnet-public1", "subnet-public2"]
}

# Hybrid Access - Public NLB, private services
ddc_infra_config = {
  nlb_internal = false                    # Internet-facing NLB
  route53_zone_id = "Z1234567890ABC"      # Public hosted zone
  allowed_external_cidrs = ["0.0.0.0/0"]
  eks_node_group_subnets = ["subnet-private1", "subnet-private2"]  # Private subnets
}

# Private Access - Everything internal
ddc_infra_config = {
  nlb_internal = true                     # Internal NLB
  route53_zone_id = "Z0987654321DEF"      # Private hosted zone
  eks_node_group_subnets = ["subnet-private1", "subnet-private2"]
  # No allowed_external_cidrs needed
}
```

**Examples Directory**: See `examples/public/`, `examples/hybrid/`, and `examples/private/` for complete configuration examples of each pattern.

**Important**: Private access requires existing VPC connectivity (VPN, Direct Connect, etc.) for developers to reach the DDC service.

### Kubernetes Networking Fundamentals

#### Network Load Balancer (NLB) Strategy

We use Network Load Balancer to provide consistent endpoints for DNS configuration. The NLB is created in Terraform (not by Kubernetes) to maintain full infrastructure control and enable reliable DNS routing to the DDC service.



### Target Registration Architecture

#### CRITICAL: We Use Terraform-Created NLB, Not Kubernetes-Created

**Our Architecture**:
```
Terraform Creates:
├── Network Load Balancer (NLB)
├── Target Group (empty initially)
├── Listeners (80 → target group, 443 → target group)
└── Security Groups

TargetGroupBinding Connects:
├── Existing Target Group ARN (from Terraform)
├── Kubernetes Service (ClusterIP)
└── Result: Pod IPs registered in target group
```

**Why This Matters**: Since we create the NLB in Terraform (not Kubernetes), we do NOT need subnet discovery tags that AWS Load Balancer Controller uses for creating new load balancers.

#### Target Registration Process

**Step 1: TargetGroupBinding Creation** (defined in `modules/ddc-infra/eks.tf`)
```yaml
apiVersion: eks.amazonaws.com/v1
kind: TargetGroupBinding
metadata:
  name: ${name_prefix}  # (e.g., cgd-unreal-cloud-ddc)
  namespace: ${name_prefix}  # (e.g., cgd-unreal-cloud-ddc)
spec:
  serviceRef:
    name: ${name_prefix}  # (e.g., cgd-unreal-cloud-ddc)
    port: 80                    # Service port
  targetGroupARN: arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/cgd-unreal-cloud-ddc-tg/abc123  # Created by Terraform in ddc-infra submodule
  targetType: ip              # Use pod IPs directly
```

**Step 2: AWS Load Balancer Controller Processing** (installed in `modules/ddc-infra/eks.tf`)
1. **Watches TargetGroupBinding**: Controller detects new TGB resource
2. **Resolves Service**: Finds service `${name_prefix}` (e.g., `cgd-unreal-cloud-ddc`)
3. **Gets Endpoints**: Retrieves pod IPs from service endpoints
4. **Registers Targets**: Calls AWS ELB API to register pod IPs in target group

**Step 3: Target Registration Flow**
```bash
# Controller resolves service to pod IPs
kubectl get endpoints ${name_prefix} -n ${name_prefix}
# name_prefix (e.g., cgd-unreal-cloud-ddc)
# Shows pod IPs from your VPC/subnet CIDR ranges (e.g., `10.0.1.100:80`, `10.0.2.200:80`)

# Controller registers pod IPs with AWS target group
aws elbv2 describe-target-health --target-group-arn <arn>
# Shows pod IPs as healthy targets from your subnet CIDR ranges
```

#### Target Type: IP vs Instance

**Target Type "ip" (What We Use)**:
- **Registers**: Pod IP addresses directly (e.g., `10.0.1.100:80`)
- **Traffic Flow**: NLB → Pod IP (direct routing)
- **Benefits**: Lower latency, no extra network hops
- **Required For**: EKS Auto Mode, Fargate
- **Health Checks**: Directly to pod IP

**Target Type "instance" (Traditional)**:
- **Registers**: EC2 instance IDs (e.g., `i-1234567890abcdef0`)
- **Traffic Flow**: NLB → Node IP → Pod IP (extra hop)
- **Benefits**: Works with older EKS versions
- **Limitations**: Higher latency, requires NodePort services
- **Health Checks**: To node IP, forwarded to pod

### Networking Troubleshooting

#### TargetGroupBinding Issues

**Issue 1: Service Not Found**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check if DDC service exists
kubectl get svc ${name_prefix} -n ${name_prefix}
# name_prefix (e.g., cgd-unreal-cloud-ddc)
# If missing: DDC application not deployed or wrong service name
```

**Issue 2: No Service Endpoints**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check if service has endpoints (pod IPs)
kubectl get endpoints ${name_prefix} -n ${name_prefix}
# name_prefix (e.g., cgd-unreal-cloud-ddc)
# If empty: No pods are ready or pods don't match service selector
```

**Issue 3: Pods Not Ready**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check pod status
kubectl get pods -n ${name_prefix} -l app.kubernetes.io/name=unreal-cloud-ddc
# name_prefix (e.g., cgd-unreal-cloud-ddc)
# If not Running/Ready: Pods are crashing or failing health checks
```

**Issue 4: AWS Load Balancer Controller Problems** (installed in `modules/ddc-infra/eks.tf`)
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
# Common errors: IAM permissions, subnet issues, API rate limits
```

**Issue 5: Target Group Subnet Mismatch**
```bash
# Check target group subnets
aws elbv2 describe-target-groups --target-group-arns <arn> --query 'TargetGroups[0].VpcId'

# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check pod subnets
kubectl get pods -n unreal-cloud-ddc -o wide
# Pod IPs must be in subnets associated with target group
```

#### Troubleshooting Target Registration

**Step 1: Verify TargetGroupBinding Status**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

kubectl describe targetgroupbinding cgd-unreal-cloud-ddc-tgb -n unreal-cloud-ddc

# Look for:
# Status: Ready=True (working) or Ready=False (broken)
# Events: Error messages about service, endpoints, or AWS API calls
```

**Step 2: Check Service and Endpoints**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify service exists and has correct selector
kubectl get svc cgd-unreal-cloud-ddc -n unreal-cloud-ddc -o yaml

# Verify service has endpoints (pod IPs)
kubectl get endpoints cgd-unreal-cloud-ddc -n unreal-cloud-ddc
# Should show pod IPs like: 10.0.1.100:80, 10.0.2.200:80
```

**Step 3: Verify Pod Readiness**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check pod status
kubectl get pods -n unreal-cloud-ddc -l app.kubernetes.io/name=unreal-cloud-ddc
# All pods should be Running and Ready

# Check pod health endpoint
kubectl exec -it <pod-name> -n unreal-cloud-ddc -- curl localhost:80/health/live
# Should return: HEALTHY
```

**Step 4: Check AWS Target Group**
```bash
# Check target registration in AWS
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Expected: Pod IPs registered as healthy
# If unhealthy: Check health check configuration and pod response
# If missing: TargetGroupBinding not working
```

**Step 5: AWS Load Balancer Controller Logs**
```bash
# Connect to EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check controller logs for errors
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50

# Common errors:
# "failed to register targets": IAM permissions or subnet issues
# "service not found": Service name mismatch in TargetGroupBinding
# "no endpoints found": Pods not ready or service selector wrong
```

#### Common Target Registration Issues

**Issue: Zero Registered Targets**

**Symptoms**: NLB target group shows 0/0 healthy targets

**Diagnosis Process**:
1. **Check TargetGroupBinding**: `kubectl describe targetgroupbinding -n unreal-cloud-ddc`
2. **Check Service**: `kubectl get svc cgd-unreal-cloud-ddc -n unreal-cloud-ddc`
3. **Check Endpoints**: `kubectl get endpoints cgd-unreal-cloud-ddc -n unreal-cloud-ddc`
4. **Check Pods**: `kubectl get pods -n unreal-cloud-ddc`
5. **Check Controller**: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`

**Common Root Causes**:
- **DDC application not deployed**: No pods exist
- **Pods not ready**: Crashing or failing health checks
- **Service name mismatch**: TargetGroupBinding references wrong service
- **AWS Load Balancer Controller not running**: Controller pod crashed
- **IAM permissions**: Controller can't call AWS ELB APIs

**Issue: Targets Registered but Unhealthy**

**Symptoms**: NLB target group shows targets but all unhealthy

**Diagnosis**:
```bash
# Check target health details
aws elbv2 describe-target-health --target-group-arn <arn>
# Look for HealthCheckFailureReason

# Common reasons:
# "Connection refused": Pod not listening on expected port
# "Timeout": Pod responding too slowly
# "HTTP 404": Health check path not found
```

**Solutions**:
- **Connection refused**: Verify pod listens on port 80
- **Timeout**: Increase health check timeout or fix pod performance
- **HTTP 404**: Verify health check path `/health/live` exists

#### Security Group Requirements

**NLB Security Group** (Terraform-managed):
```hcl
# Allow inbound traffic from game developers
resource "aws_vpc_security_group_ingress_rule" "nlb_https" {
  security_group_id = aws_security_group.nlb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"  # Or restricted CIDRs
}

# Allow outbound to EKS cluster
resource "aws_vpc_security_group_egress_rule" "nlb_to_cluster" {
  security_group_id            = aws_security_group.nlb.id
  referenced_security_group_id = aws_security_group.cluster.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}
```

**EKS Cluster Security Group** (Terraform-managed):
```hcl
# Allow inbound from NLB
resource "aws_vpc_security_group_ingress_rule" "cluster_from_nlb" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.nlb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}
```

**Why This Works**:
- NLB sends traffic directly to pod IPs (not node IPs)
- Security group rules allow NLB → Pod communication
- TargetGroupBinding handles IP registration automatically
- No subnet discovery tags needed (we don't create load balancers)

#### Subnet Requirements

**CONFIRMED: No Subnet Tags Required for Target Registration**

Subnet tags (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`) are ONLY required when AWS Load Balancer Controller creates new load balancers.

Since we use Terraform-created NLB with existing target groups, TargetGroupBinding does NOT require subnet discovery tags.

**What TargetGroupBinding Actually Needs**:
1. **Existing target group ARN** (from Terraform)
2. **Service selector** to find pods
3. **Proper IAM permissions** for AWS Load Balancer Controller
4. **Pod IPs in correct subnets** (same VPC as target group)

**No subnet tagging complexity needed.**

#### Security Group Strategy

**NLB Security Group**:
- Ingress: HTTPS (443) from allowed CIDRs
- Ingress: HTTP (80) from allowed CIDRs (debug mode only)
- Egress: To EKS cluster security group

**EKS Cluster Security Group**:
- Ingress: From NLB security group
- Egress: All traffic (managed by EKS)

**Internal Security Group**:
- ScyllaDB communication (port 9042)
- Inter-service communication within VPC

### DNS Architecture

#### Regional DNS Pattern

**Public DNS** (internet-accessible):
- Pattern: `<region>.ddc.<domain>`
- Example: `us-east-1.ddc.example.com`
- Points to: Regional NLB

**Private DNS** (VPC-internal):
- Pattern: `<region>.<service>.<private-zone>`
- Example: `us-east-1.unreal-cloud-ddc.cgd.local`
- Points to: Internal services, ScyllaDB cluster

#### Multi-Region DNS Strategy

```
Primary Region (us-east-1):
├── us-east-1.ddc.example.com → NLB us-east-1
└── Creates private zone: cgd.local

Secondary Region (us-west-2):
├── us-west-2.ddc.example.com → NLB us-west-2
└── Associates with private zone: cgd.local
```

### VPC Endpoints

#### EKS API Endpoint Benefits

**Without VPC Endpoint**:
- EKS API calls go through internet
- Requires NAT Gateway for private subnets
- Higher latency and costs

**With VPC Endpoint**:
- Direct private connection to EKS API
- No internet egress required
- Lower latency and costs
- Enhanced security

#### Supported VPC Endpoints

| Service | Type | Purpose | Cost Impact |
|---------|------|---------|-------------|
| EKS | Interface | Private EKS API access | Reduces NAT Gateway usage |
| S3 | Gateway | DDC S3 bucket access | No additional cost |
| CloudWatch Logs | Interface | Log shipping | Reduces data transfer costs |
| Secrets Manager | Interface | Bearer token access | Reduces NAT Gateway usage |
| SSM | Interface | ScyllaDB automation | Reduces NAT Gateway usage |

## DATABASE

**TLDR**: ScyllaDB is a distributed NoSQL database that runs on manual EC2 instances (not EKS) due to persistent data requirements. It uses a seed node + other nodes architecture where the seed node helps with cluster discovery but all nodes store data equally. ScyllaDB datacenters map to AWS regions, keyspaces are like databases, and `replication_factor` controls both the number of instances created AND the number of data copies stored.

### ScyllaDB Architecture Overview

**What is ScyllaDB**: High-performance NoSQL database compatible with Apache Cassandra, written in C++ for better performance.

**Why ScyllaDB for DDC**: 
- **High throughput**: Handles millions of asset requests per second
- **Low latency**: Sub-millisecond response times for cached data
- **Horizontal scaling**: Add nodes to increase capacity
- **Multi-region replication**: Automatic data sync between regions
- **Cassandra compatibility**: Uses existing Cassandra drivers and tools

### Seed Node vs Other Nodes

**CRITICAL UNDERSTANDING**: All ScyllaDB nodes are equal for data storage and serving. The "seed" vs "other" distinction is ONLY for cluster bootstrap.

#### Seed Node (Bootstrap Node)

**Purpose**: 
- **Cluster discovery**: Helps new nodes find and join the cluster
- **Gossip protocol**: Maintains cluster membership information
- **Bootstrap coordination**: Coordinates initial cluster formation

**Key Point**: Seed node is just a regular data node that happens to help with cluster bootstrap. All nodes are equal for data storage and serving.

#### Other Nodes (Regular Nodes)

**Purpose**:
- **Data storage**: Store and serve data based on consistent hashing
- **Query processing**: Handle read/write requests from applications
- **Replication**: Maintain copies of data for fault tolerance
- **Cluster participation**: Full members of the distributed system

**Bootstrap Process**:
1. **New node starts**: Configured with seed node IP addresses
2. **Contacts seed**: "I want to join the cluster"
3. **Gets cluster info**: Seed provides list of all nodes and data distribution
4. **Joins cluster**: Becomes full participant in data storage and serving
5. **Data rebalancing**: Existing data redistributed to include new node

#### Instance Creation Logic

**Current Implementation** (in `modules/ddc-infra/scylla.tf`):
```hcl
# Creates 1 seed node (if create_seed_node = true)
resource "aws_instance" "scylla_ec2_instance_seed" {
  count = var.scylla_config != null && var.create_seed_node ? 1 : 0
  # Configuration...
}

# Creates N-1 other nodes
resource "aws_instance" "scylla_ec2_instance_other_nodes" {
  count = var.scylla_config != null ? (var.create_seed_node ? var.scylla_replication_factor - 1 : var.scylla_replication_factor) : 0
  # Configuration...
}
```

**Total Instances Created**: 
- **With seed node**: 1 seed + (replication_factor - 1) other = replication_factor total
- **Without seed node**: replication_factor other nodes (for multi-region, existing seed)

**CLEAN DESIGN**: `replication_factor` controls both instance count and data replication.

### Simple Configuration

**What Users Configure**:
```hcl
scylla_config = {
  current_region = {
    replication_factor = 3  # Creates 3 instances AND stores 3 data copies
  }
}
```

**What Happens**:
- **Instance count**: `replication_factor = 3` → Creates 3 instances ✅
- **Data replication**: Each piece of data stored on 3 different nodes ✅
- **Clean design**: One variable controls both concepts ✅

**Why This Makes Sense**:
- **Optimal performance**: Number of instances typically equals replication factor
- **Simple interface**: No confusion between multiple variables
- **Matches original design**: Consistent with cwwalb branch implementation

### ScyllaDB Datacenters and Keyspaces

#### Datacenters (AWS Regions)

**ScyllaDB Datacenter**: Logical grouping of nodes, typically maps to AWS regions

**Datacenter Naming**:
- **us-east-1** → **us-east** (removes `-1` suffix due to ScyllaDB parsing issues)
- **us-west-2** → **us-west-2** (other suffixes remain)
- **eu-west-1** → **eu-west** (removes `-1` suffix)

#### ScyllaDB AWS Region Naming Issue

**The Issue**: ScyllaDB's CQL parser can have conflicts when manually overriding datacenter names to use full AWS region names ending in numbers (like `us-east-1`) in NetworkTopologyStrategy keyspace definitions.

**Important**: This is NOT a core ScyllaDB bug - it only affects manual datacenter name overrides, not default behavior.

**Default ScyllaDB Behavior (Ec2MultiRegionSnitch)**:
ScyllaDB automatically handles this by using safe datacenter names:
- **us-east-1** → **us-east** (automatically drops -1)
- **us-east-2** → **us-east-2** (keeps full name - no conflict)
- **us-west-2** → **us-west-2** (keeps full name - no conflict)
- **eu-west-1** → **eu-west** (automatically drops -1)

**When Issues Occur**: Only when manually forcing datacenter names to full region names:
```sql
-- This could cause parsing issues:
CREATE KEYSPACE ks WITH replication = {
  'class': 'NetworkTopologyStrategy', 
  'us-east-1': 3  -- Manual override with -1 suffix
};
```

**CGD Toolkit's Implementation**:
```hcl
# Consistent datacenter naming - strips numeric suffixes
regex("^(.+)-[0-9]+$", local.region)[0]

# Results in predictable datacenter names:
# us-east-1 → us-east 
# us-east-2 → us-east
# us-west-2 → us-west
# eu-west-1 → eu-west
```

**Design Decision**: CGD Toolkit uses consistent datacenter naming to ensure reliable CQL operations across all AWS regions.

#### Multi-Region Deployment Considerations

**Design Constraint**: CGD Toolkit's consistent naming approach means regions that map to the same datacenter name cannot be used together in multi-region deployments.

**✅ These Region Combinations WORK**:
```
us-east-1 + us-west-2
├── us-east-1 → "us-east" (after -1 removal)
├── us-west-2 → "us-west-2" (no change)
└── Result: "us-east" + "us-west-2" = unique datacenters ✅

us-east-1 + eu-west-1
├── us-east-1 → "us-east" (after -1 removal)
├── eu-west-1 → "eu-west" (after -1 removal)
└── Result: "us-east" + "eu-west" = unique datacenters ✅

us-west-2 + ap-southeast-2
├── us-west-2 → "us-west-2" (no change)
├── ap-southeast-2 → "ap-southeast-2" (no change)
└── Result: "us-west-2" + "ap-southeast-2" = unique datacenters ✅
```

**❌ These Region Combinations Don't Work**:
```
us-east-1 + us-east-2
├── us-east-1 → "us-east" (consistent naming)
├── us-east-2 → "us-east" (consistent naming)
└── Result: "us-east" + "us-east" = duplicate datacenter names ❌
```

**Why This Isn't a Problem for DDC**:

**Performance-Driven Cache Placement**: DDC is a cache service designed to improve build and development performance. The performance benefits of having caches in nearby regions (like us-east-1 and us-east-2) are minimal compared to geographically distributed regions.

**Optimal Multi-Region Patterns**:
```
# ✅ RECOMMENDED: Geographically distributed for global teams
us-east-1 (North America East Coast)
+ eu-west-1 (Europe)
+ ap-southeast-2 (Asia Pacific)
= Maximum geographic coverage for distributed teams

# ✅ ACCEPTABLE: Cross-country coverage
us-east-1 (East Coast) + us-west-2 (West Coast)
= Good coverage for US-based teams

# ❌ NOT RECOMMENDED: Adjacent regions
us-east-1 + us-east-2
= Minimal performance benefit, unnecessary complexity
```

**Real-World Use Cases**:
- **Global Game Studio**: us-east-1 (HQ) + eu-west-1 (London office) + ap-southeast-2 (Singapore office)
- **US-Based Studio**: us-east-1 (East Coast) + us-west-2 (West Coast contractors)
- **European Studio**: eu-west-1 (primary) + us-east-1 (US contractors)

**Performance Considerations**:
- **Cache Hit Rate**: Local cache provides ~100x performance improvement
- **Geographic Distance**: 50ms vs 150ms latency difference is negligible compared to cache benefits
- **Network Costs**: Cross-region replication costs are the same regardless of distance
- **Operational Complexity**: Fewer regions = simpler operations and troubleshooting

**Recommendation**: Choose regions based on where your development teams are located, not AWS region naming patterns. The ScyllaDB naming limitation doesn't affect practical DDC deployment scenarios.



**Datacenter Configuration**:
```sql
-- View datacenters in your cluster
SELECT data_center FROM system.local UNION SELECT data_center FROM system.peers;

-- Expected output for multi-region:
-- us-east
-- us-west-2
```

#### Keyspaces (Like Schemas)

**ScyllaDB Keyspace**: Container for tables, similar to a schema/database in SQL systems. ScyllaDB is the database, keyspaces organize tables within it.

**DDC Keyspace Naming**:
- **Pattern**: `jupiter_local_ddc_{region_suffix}`
- **us-east-1**: `jupiter_local_ddc_us_east_1`
- **us-west-2**: `jupiter_local_ddc_us_west_2`

**Keyspace Replication Strategy**:
```sql
-- Single region keyspace
CREATE KEYSPACE jupiter_local_ddc_us_east_1 
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'us-east': 3  -- 3 copies in us-east datacenter
};

-- Multi-region keyspace (for cross-region replication)
CREATE KEYSPACE jupiter_local_ddc_us_east_1 
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'us-east': 3,     -- 3 copies in us-east datacenter
  'us-west-2': 2    -- 2 copies in us-west-2 datacenter
};
```

**Replication Factor Meaning**:
- **replication_factor = 3**: Each piece of data stored on 3 different nodes
- **Multi-region**: Data replicated across datacenters for disaster recovery
- **Consistency**: More replicas = higher availability but slower writes

### Database Troubleshooting

**Common Issues**:

**Issue: Nodes Not Joining Cluster**
```bash
# SSH to ScyllaDB instance via Session Manager
aws ssm start-session --target i-1234567890abcdef0

# Check cluster status
nodetool status
# Expected: All nodes show "UN" (Up Normal)

# Check logs
sudo journalctl -u scylla-server -f
# Look for connection errors, authentication failures
```

**Issue: Cross-Region Replication Not Working**
```bash
# Check keyspace replication settings
cqlsh -e "DESCRIBE KEYSPACE jupiter_local_ddc_us_east_1;"
# Verify both datacenters listed with correct replica counts

# Check network connectivity
telnet <other-region-node-ip> 7000
# Should connect successfully
```

**Issue: High Latency or Timeouts**
```bash
# Check node resource usage
nodetool tpstats  # Thread pool statistics
nodetool cfstats  # Column family statistics

# Check system resources
top
iostat -x 1
```

### Future Considerations

**ScyllaDB on EKS Support**: We are tracking a feature request to add ScyllaDB Operator support as an alternative deployment option. See [Issue #490](https://github.com/aws-games/cloud-game-development-toolkit/issues/490) for progress updates.

**Amazon Keyspaces Evaluation**: We are evaluating Amazon Keyspaces (managed Cassandra service) as the database layer to significantly reduce operational complexity through a fully managed service with automatic scaling, built-in security, and seamless AWS integration.ity, and seamless AWS integration.

#### Alternative Database Options

**Amazon Keyspaces (Managed Cassandra)**:

**Pros**:
- **Fully managed**: No EC2 instances to manage
- **Auto-scaling**: Capacity scales automatically based on demand
- **Multi-region**: Built-in cross-region replication
- **Serverless**: Pay per request pricing model
- **AWS Integration**: Native integration with IAM, VPC, CloudWatch

**Cons**:
- **Performance**: Lower throughput than ScyllaDB (~40,000 RPS vs 400,000+ RPS)
- **Cost**: More expensive for high-volume workloads
- **Compatibility**: Some Cassandra features not supported
- **Control**: Less tuning options and configuration flexibility
- **Latency**: Higher latency than local NVMe storage

**When to Consider**: Lower-volume DDC deployments, managed service preference, cost optimization for small workloads

**Amazon DynamoDB**:

**Pros**:
- **Fully managed**: AWS handles all operations
- **Performance**: Single-digit millisecond latency
- **Global tables**: Multi-region replication built-in
- **Serverless**: On-demand scaling and pricing
- **AWS Native**: Deep integration with AWS services

**Cons**:
- **Data model**: Different from Cassandra (would require DDC application changes)
- **Query patterns**: Limited compared to CQL
- **Cost**: Can be expensive for large datasets
- **Migration**: Significant application changes required
- **Vendor lock-in**: AWS-specific, not portable

**When to Consider**: New DDC implementations, AWS-native preference, different data access patterns

#### Database Performance Optimization

**Query Optimization**:
- **Partition Key Design**: Distribute data evenly across nodes
- **Clustering Key Optimization**: Efficient range queries
- **Consistency Levels**: Balance consistency vs performance
- **Batch Operations**: Group related operations

**Hardware Optimization**:
- **NVMe Storage**: Use local NVMe for optimal I/O performance
- **Memory Sizing**: Adequate RAM for caching and operations
- **CPU Cores**: Sufficient cores for concurrent operations
- **Network Bandwidth**: High-bandwidth instances for replication

**Cluster Optimization**:
- **Replication Factor**: Balance availability vs write performance
- **Node Count**: Distribute load across multiple nodes
- **Rack Awareness**: Distribute replicas across availability zones
- **Compaction Strategy**: Optimize for read vs write workloads

#### Summary: Database Architecture Decision

**Why CGD Toolkit Chose Manual EC2**:
- **Operational simplicity**: Focus on DDC application rather than database operations
- **Team familiarity**: Well-understood operational model for game development teams
- **Resource isolation**: Dedicated instances with no resource contention
- **Epic Games alignment**: Matches Epic's reference architectures
- **Direct control**: Full access to instance configuration and tuning
- **Performance**: Optimal I/O performance with local NVMe storage

**When to Consider Each Approach**:

**Choose Manual EC2 ScyllaDB if**:
- Team prefers traditional database operations
- Want maximum operational simplicity
- Need dedicated resources with guaranteed performance
- Following Epic Games reference architectures
- Require high-performance local storage
- Have existing ScyllaDB expertise

**Choose ScyllaDB Operator if**:
- Team has strong Kubernetes operational expertise
- Want cloud-native database management
- Need dynamic scaling and automated operations
- Prefer GitOps workflows for infrastructure management
- Comfortable with StatefulSet complexity

**Choose Amazon Keyspaces if**:
- Prefer fully managed services
- Lower-volume DDC deployments
- Want automatic scaling without operational overhead
- Cost optimization for smaller workloads
- Strong AWS integration requirements

**All approaches provide excellent reliability for DDC workloads, with different trade-offs in operational complexity, performance, and cost.** 



### Multi-Region Architecture Options

#### Current CGD Toolkit (Manual EC2)

**Network Requirements**:
- **Private connectivity**: VPC Peering, Transit Gateway, or Direct Connect
- **Security groups**: Allow ScyllaDB ports (7000, 9042) between regions
- **DNS resolution**: Nodes must resolve each other's private IPs

**Replication Flow**:
```
Write Request in us-east-1:
├── Client → DDC Pod → ScyllaDB EC2 us-east-1
├── ScyllaDB us-east-1 → Local storage (3 replicas)
├── ScyllaDB us-east-1 → ScyllaDB us-west-2 (async replication)
└── ScyllaDB us-west-2 → Local storage (2 replicas)
```

#### Alternative: ScyllaDB Operator Multi-Region

**Architecture**: Separate EKS clusters with ScyllaDB Operator in each region

```
Region 1 (us-east-1):
├── EKS Cluster 1
├── ScyllaDB Operator
├── ScyllaDB StatefulSet (datacenter: us-east-1)
└── DDC Application Pods

Region 2 (us-west-2):
├── EKS Cluster 2
├── ScyllaDB Operator
├── ScyllaDB StatefulSet (datacenter: us-west-2)
└── DDC Application Pods
```

#### SSM Document Automation

**Purpose**: Configure cross-region replication after both regions are deployed

**What It Does**:
```sql
-- Updates keyspace replication to include both regions
ALTER KEYSPACE jupiter_local_ddc_us_east_1 
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'us-east': 3,     -- Primary region
  'us-west-2': 2    -- Secondary region
};
```

**Why SSM Document**: 
- **Timing**: Runs after both regions are fully deployed
- **Automation**: No manual CQL commands required
- **Idempotent**: Safe to run multiple times

### ScyllaDB vs DDC Scaling

#### Independent Scaling

**DDC Application Scaling** (Automatic):
```hcl
ddc_application_config = {
  replica_count = 5  # Scale from 2 to 5 pods
}
```
- **Result**: EKS Auto Mode creates more nodes, schedules more DDC pods
- **Impact**: Higher request throughput, more concurrent users
- **Speed**: Scales in minutes
- **Data**: No data migration required

**ScyllaDB Database Scaling** (Manual):
```hcl
scylla_config = {
  current_region = {
    replication_factor = 5  # Scale from 3 to 5 nodes
  }
}
```
- **Result**: Terraform creates 2 additional EC2 instances
- **Impact**: More storage capacity, higher database throughput
- **Speed**: Scales in 10-20 minutes (includes data rebalancing)
- **Data**: Existing data redistributed across all nodes

#### When to Scale Each Layer

**Scale DDC Pods When**:
- **High CPU usage**: DDC pods hitting CPU limits
- **Request latency**: Slow response times to game clients
- **Connection limits**: Too many concurrent connections per pod
- **Geographic distribution**: Need pods closer to users

**Scale ScyllaDB Nodes When**:
- **Storage capacity**: Running out of disk space
- **Database throughput**: High latency on database queries
- **Memory pressure**: Nodes running out of RAM for caching
- **Fault tolerance**: Need more replicas for availability

### Alternative Database Options

#### Amazon Keyspaces (Managed Cassandra)

**Pros**:
- **Fully managed**: No EC2 instances to manage
- **Auto-scaling**: Capacity scales automatically
- **Multi-region**: Built-in cross-region replication
- **Serverless**: Pay per request pricing model

**Cons**:
- **Performance**: Lower throughput than ScyllaDB
- **Cost**: More expensive for high-volume workloads
- **Compatibility**: Some Cassandra features not supported
- **Control**: Less tuning options

**When to Consider**: Lower-volume DDC deployments, managed service preference

#### Amazon DynamoDB

**Pros**:
- **Fully managed**: AWS handles all operations
- **Performance**: Single-digit millisecond latency
- **Global tables**: Multi-region replication built-in
- **Serverless**: On-demand scaling

**Cons**:
- **Data model**: Different from Cassandra (would require DDC changes)
- **Query patterns**: Limited compared to CQL
- **Cost**: Can be expensive for large datasets
- **Migration**: Significant application changes required

**When to Consider**: New DDC implementations, AWS-native preference

### Troubleshooting ScyllaDB

#### Common Issues

**Issue: Nodes Not Joining Cluster**
```bash
# SSH to ScyllaDB instance via Session Manager
aws ssm start-session --target i-1234567890abcdef0

# Check cluster status
nodetool status
# Expected: All nodes show "UN" (Up Normal)

# Check logs
sudo journalctl -u scylla-server -f
# Look for connection errors, authentication failures
```

**Issue: Cross-Region Replication Not Working**
```bash
# Check keyspace replication settings
cqlsh -e "DESCRIBE KEYSPACE jupiter_local_ddc_us_east_1;"
# Verify both datacenters listed with correct replica counts

# Check network connectivity
telnet <other-region-node-ip> 7000
# Should connect successfully
```

**Issue: High Latency or Timeouts**
```bash
# Check node resource usage
nodetool tpstats  # Thread pool statistics
nodetool cfstats  # Column family statistics

# Check system resources
top
iostat -x 1
```

#### Performance Monitoring

**Key Metrics to Monitor**:
- **Read/Write latency**: P95, P99 response times
- **Throughput**: Operations per second
- **CPU usage**: Should be <80% under normal load
- **Memory usage**: JVM heap and off-heap cache
- **Disk usage**: Both space and IOPS utilization
- **Network**: Inter-node communication bandwidth

**Monitoring Tools**:
- **ScyllaDB Monitoring Stack**: Prometheus + Grafana (deployed by module)
- **CloudWatch**: EC2 instance metrics
- **ScyllaDB Manager**: Enterprise monitoring (optional)

### Summary: Database Architecture Decision

**Why CGD Toolkit Chose Manual EC2**:
- **Operational simplicity**: Focus on DDC application rather than database operations
- **Team familiarity**: Well-understood operational model for game development teams
- **Resource isolation**: Dedicated instances with no resource contention
- **Epic Games alignment**: Matches Epic's reference architectures
- **Direct control**: Full access to instance configuration and tuning

**ScyllaDB Operator is Production-Ready**:
- **Fully supported**: ScyllaDB officially supports the Kubernetes operator
- **Production deployments**: Used by many organizations for production workloads
- **Feature complete**: Handles all operational requirements (scaling, backups, monitoring)
- **Multi-region capable**: Supports complex multi-datacenter deployments

**When to Consider Each Approach**:

**Choose Manual EC2 if**:
- Team prefers traditional database operations
- Want maximum operational simplicity
- Need dedicated resources with guaranteed performance
- Following Epic Games reference architectures

**Choose ScyllaDB Operator if**:
- Team has strong Kubernetes operational expertise
- Want cloud-native database management
- Need dynamic scaling and automated operations
- Prefer GitOps workflows for infrastructure management

**Both approaches provide excellent performance and reliability for DDC workloads.**

This architecture provides the optimal balance of performance, reliability, and operational simplicity for high-volume game asset caching workloads.

## STORAGE

**TLDR**: DDC uses two different types of namespaces - logical namespaces for game project isolation (URL paths) and Kubernetes namespaces for infrastructure containers. All DDC projects share a single S3 bucket with prefix-based separation, creating a critical single point of failure. NVMe storage is recommended for optimal DDC cache performance.

### DDC Logical Namespaces vs Kubernetes Namespaces

**⚠️ CRITICAL DISTINCTION**: DDC has TWO different types of namespaces that serve completely different purposes:

**1. DDC Logical Namespaces** (Application-Level Segmentation):
- **Purpose**: Game project isolation within DDC service
- **URL Structure**: `https://ddc.example.com/api/v1/refs/<ddc_namespace>/default/hash`
- **S3 Segmentation**: Objects stored with `<ddc_namespace>/` prefix in S3 bucket
- **Configuration**: Defined in `ddc_application_config.ddc_namespaces`
- **Examples**: "project1", "project2", "dev-sandbox"

**2. Kubernetes Namespace** (Infrastructure Container):
- **Purpose**: Infrastructure resource isolation within EKS cluster
- **Single namespace**: `unreal-cloud-ddc` (contains ALL DDC infrastructure)
- **Contains**: DDC pods, ScyllaDB, services, ConfigMaps, secrets
- **Shared**: One Kubernetes namespace serves all DDC logical namespaces

**Data Isolation & S3 Bucket Sharing**:
```
S3 Bucket Structure:
├── project1/          # DDC logical namespace 1
│   ├── assets/
│   └── metadata/
├── project2/          # DDC logical namespace 2
│   ├── assets/
│   └── metadata/
└── dev-sandbox/       # DDC logical namespace 3
    ├── assets/
    └── metadata/
```

**⚠️ CRITICAL S3 BUCKET RISK**: All DDC logical namespaces share the same S3 bucket. A bucket deletion impacts ALL game projects simultaneously.

**RECOMMENDED**: Consider S3 bucket replication for disaster recovery (requires manual setup outside this module):
```hcl
# Enable cross-region replication for disaster recovery
aws_s3_bucket_replication_configuration "ddc_replication" {
  # Replicate to secondary region
  destination {
    bucket = "arn:aws:s3:::backup-ddc-bucket"
  }
}
```

### NVMe vs EBS Performance

**DDC Cache Performance**: DDC is a cache service that benefits significantly from high-speed local storage. While DDC can run on general-purpose instances (like c6i.4xlarge), we use NVMe storage-optimized instances for optimal cache performance.

**Performance Comparison**:

| Storage Type | IOPS | Throughput | Latency | Use Case |
|--------------|------|------------|---------|----------|
| **NVMe SSD** | 400,000+ | 6,000+ MB/s | <100μs | DDC cache (optimal) |
| **EBS gp3** | 16,000 | 1,000 MB/s | ~1ms | General workloads |
| **EBS io2** | 64,000 | 4,000 MB/s | ~1ms | High-performance databases |

**Why NVMe for DDC**:
- **Cache Hit Performance**: Sub-millisecond access to cached assets
- **Cache Miss Performance**: Faster S3 downloads and local caching
- **Build Performance**: Faster asset compilation and processing
- **Cost Efficiency**: Better performance per dollar for cache workloads

## SECURITY

**TLDR**: EKS uses multiple authentication layers - IRSA for pod-to-AWS API access, EKS access entries for kubectl access, and DDC bearer tokens for application access. The module implements zero-trust networking with no long-term secrets, using temporary tokens and least-privilege IAM roles. Security group management varies significantly between EKS compute types.

### Authentication & Security

#### EKS Authentication Layers

Amazon EKS uses multiple authentication layers for different purposes. Understanding these layers is critical for proper infrastructure setup and troubleshooting.

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS AUTHENTICATION LAYERS                   │
└─────────────────────────────────────────────────────────────────┘

LAYER 1: INFRASTRUCTURE AUTHENTICATION (IRSA)
┌─────────────────────────────────────────────────────────────────┐
│  AWS Load Balancer Controller Pod                              │
│  ├─ Service Account: aws-load-balancer-controller              │
│  ├─ IRSA Role: arn:aws:iam::xxx:role/lbc-role                 │
│  └─ Needs: EKS OIDC Provider                                  │
│                                                                 │
│  Purpose: Let Kubernetes pods call AWS APIs                    │
│  Users: Infrastructure components (controllers, CSI drivers)   │
│  Auth Flow: K8s Token → AWS STS → Temporary AWS Credentials    │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                        AWS APIs                                 │
│  ├─ ELB: DescribeTargetHealth, RegisterTargets                │
│  ├─ S3: GetObject, PutObject                                  │
│  └─ Secrets Manager: GetSecretValue                           │
└─────────────────────────────────────────────────────────────────┘

LAYER 2: USER AUTHENTICATION (Application Level)
┌─────────────────────────────────────────────────────────────────┐
│  Game Developers                                               │
│  ├─ Current: Bearer Token → DDC Application                   │
│  └─ Future: OIDC/SAML → Identity Center → DDC Application     │
│                                                                 │
│  Purpose: Let users access DDC application                     │
│  Users: Game developers, build systems                         │
│  Auth Flow: User Login → Identity Provider → DDC App          │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                    DDC Application                              │
│  ├─ Current: Validates bearer tokens                          │
│  └─ Future: Validates OIDC tokens                             │
└─────────────────────────────────────────────────────────────────┘
```

#### Layer 1: Infrastructure Authentication (IRSA)

**IAM Roles for Service Accounts (IRSA)** allows Kubernetes pods to assume AWS IAM roles without storing AWS credentials.

**Components**:
1. **EKS OIDC Provider** - Created automatically by EKS, enables trust relationship between EKS and AWS IAM
2. **IAM Role** - Standard AWS IAM role with specific permissions and trust policy for OIDC provider
3. **Kubernetes Service Account** - Annotated with IAM role ARN (`eks.amazonaws.com/role-arn`)

**Authentication Flow**:
```
K8s Pod → K8s Token → AWS STS → Temporary AWS Credentials → AWS Service
```

**Module Implementation**:
The CGD Toolkit automatically creates OIDC provider and IRSA roles for infrastructure components like AWS Load Balancer Controller, Fluent Bit, and Cert Manager.

#### Layer 2: User Authentication (Application Level)

**Current**: DDC application uses bearer token authentication
**Future (v1.1)**: Planned OIDC integration with AWS IAM Identity Center or external providers

**Key Differences**:
| Aspect | Infrastructure OIDC (IRSA) | User OIDC |
|--------|---------------------------|-----------|
| **Purpose** | Pod → AWS API access | User → Application access |
| **Scope** | Infrastructure components | End users |
| **Tokens** | Kubernetes service account tokens | User identity tokens |
| **Provider** | EKS OIDC Provider | External identity provider |
| **Setup** | Required for module function | Optional feature enhancement |

### kubeconfig Management

#### What is kubeconfig?

**What**: Configuration file that tells kubectl how to connect to clusters
**Where**: `~/.kube/config` (default) or `KUBECONFIG` env var
**Contains**: Cluster endpoints, certificates, authentication methods

```yaml
# Example kubeconfig structure
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://ABC123.gr7.us-east-1.eks.amazonaws.com
    certificate-authority-data: LS0tLS1CRUdJTi...
  name: my-cluster
contexts:
- context:
    cluster: my-cluster
    user: my-cluster
  name: my-cluster
current-context: my-cluster
users:
- name: my-cluster
  user:
    exec:
      command: aws
      args: ["eks", "get-token", "--cluster-name", "my-cluster", "--region", "us-east-1"]
```

#### aws eks update-kubeconfig Explained

**What it does**:
1. Calls EKS API to get cluster endpoint + certificate
2. Creates/updates `~/.kube/config` with cluster info
3. Sets up AWS IAM authentication method

**Why the name is confusing**: It's not "logging in" - it's configuring your local kubectl to know how to connect and authenticate.

**Real-world analogy**: Like programming your garage door opener with the frequency and security code for your specific garage.

#### Authentication Flow
```
kubectl command
├── Reads ~/.kube/config
├── Sees exec: aws eks get-token
├── Runs aws eks get-token (uses your AWS credentials)
├── Gets temporary Kubernetes token
├── Sends request to EKS with token
└── EKS validates token with AWS IAM
```

**Security Benefits**: 
- kubeconfig is safe to store locally (no long-term secrets)
- Uses your existing AWS credentials (IAM roles/users)
- Tokens are temporary (15 minutes)

### EKS Access Control

#### Three-Layer Security Model

1. **Network Layer**: IP allowlist (`public_access_cidrs`) - controls who can reach the EKS API server
2. **Authentication**: AWS IAM - verifies who you are
3. **Authorization**: EKS access entries - defines what you can do in the cluster

#### Cluster Creator Automatic Access

**Important**: The IAM principal that creates the EKS cluster automatically receives cluster admin permissions via `bootstrapClusterCreatorAdminPermissions=true` (default behavior).

**Implications**:
- The cluster creator can run kubectl commands without additional configuration
- CI/CD pipelines work automatically if they use the same IAM role that created the cluster
- No additional EKS access entries are required for the cluster creator

#### EKS Access Entries (Additional Users)

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

#### Three Separate Authentication Systems

1. **EKS Cluster Management** (kubectl, CI/CD, troubleshooting)
   - Uses EKS access entries for additional users beyond cluster creator
   - Managed via AWS APIs and Terraform

2. **Infrastructure Component Authentication** (AWS Load Balancer Controller, Fluent Bit, etc.)
   - Uses IRSA (IAM Roles for Service Accounts) with EKS OIDC Provider
   - Allows Kubernetes pods to call AWS APIs securely
   - Managed via Terraform (OIDC provider + IAM roles)

3. **DDC Application Authentication** (Unreal Engine clients, build systems)
   - Uses ConfigMap containing DDC bearer tokens
   - Completely separate from EKS cluster access
   - Managed via Kubernetes resources

### Security Best Practices

#### No Long-Term Secrets

**Traditional Kubernetes**:
- Service account tokens (never expire)
- Client certificates (long-lived)
- Static kubeconfig files with embedded secrets

**EKS with IAM**:
- **15-minute tokens**: `aws eks get-token` generates temporary tokens
- **No embedded secrets**: kubeconfig contains commands, not credentials
- **Automatic rotation**: New token generated for each kubectl command
- **Revocation**: Disable IAM user/role = immediate access revocation

#### Multi-User Access Patterns

**Single Developer**:
```hcl
public_access_cidrs = ["149.120.37.45/32"]  # Your current IP
```

**Team Development**:
```hcl
public_access_cidrs = [
  "149.120.37.45/32",  # Developer 1
  "203.0.113.10/32",   # Developer 2
  "198.51.100.5/32"    # CI/CD system
]
```

**Office Network**:
```hcl
public_access_cidrs = ["10.0.0.0/8"]  # Corporate network
```

## Terraform + Kubernetes Integration Challenges

### The Core Issue: Asynchronous Infrastructure Provisioning

Terraform creates EKS clusters quickly (2-3 minutes for control plane provisioning), but the cluster requires additional time (8-15 minutes) before accepting kubectl commands (control plane initialization). This creates an async/sync coordination challenge that requires careful architectural solutions.

**EKS Cluster Creation Timeline** (actual times vary by region and configuration):
```
T+0:   EKS cluster creation starts
T+2:   Control plane provisioned (AWS reports "ACTIVE")
T+8:   Control plane ready (kubectl commands work)
T+15:  Full initialization complete (all pods schedulable)
```

**Terraform Apply Timeline** (with our local-exec approach):
```
T+0:   terraform apply starts
T+2:   EKS cluster resource "created" (control plane provisioned)
T+8:   local-exec provisioners start (cluster ready for kubectl)
T+12:  Helm deployments complete
T+15:  terraform apply completes ✅ (everything deployed)
```

**Key Point**: Terraform apply does NOT complete until all resources are ready. Our local-exec provisioners wait for EKS cluster readiness before deploying applications.

### Terraform Deployment Flow

#### Complete CRUDL Operations

**Create (terraform apply)**:
1. **Infrastructure Phase**: VPC, EKS cluster, ScyllaDB, S3, Load Balancers
2. **Wait Phase**: EKS cluster becomes ready for API calls
3. **Kubernetes Phase**: CRDs, Helm charts, TargetGroupBinding
4. **Validation Phase**: Health checks and readiness verification

**Read (terraform plan/show)**:
- Infrastructure state via AWS APIs
- Kubernetes resources via kubectl (requires cluster access)
- Helm release status via Helm CLI

**Update (terraform apply with changes)**:
- Infrastructure changes via AWS APIs
- Kubernetes changes via local-exec Helm commands
- Rolling updates for application configuration

**Delete (terraform destroy)**:
1. **Kubernetes Cleanup**: Remove finalizers, uninstall Helm releases
2. **AWS Resource Cleanup**: Load balancers, target groups, ENIs
3. **Infrastructure Cleanup**: EKS cluster, ScyllaDB, S3, VPC resources

### Module Configuration Patterns

#### Pattern 1: Full Stack (Infrastructure + Application)

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # Both infrastructure and application
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private[*].id
    scylla_config = { /* ... */ }
  }
  
  ddc_application_config = {
    namespaces = { /* ... */ }
    compute = { /* ... */ }
  }
}
```

**What Gets Deployed**:
- EKS cluster, ScyllaDB, S3, Load Balancers (infrastructure)
- DDC Helm charts, TargetGroupBinding (application)
- Single `terraform apply` deploys everything

**Good For**: Small teams, development environments, simple deployments

#### Pattern 2: Infrastructure Only

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # Infrastructure only
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private[*].id
    scylla_config = { /* ... */ }
  }
  
  # No ddc_application_config - applications managed separately
}
```

**What Gets Deployed**:
- EKS cluster, ScyllaDB, S3, Load Balancers (infrastructure)
- Outputs cluster info for external application deployment
- NO Helm charts or Kubernetes applications

**Good For**: Large teams, GitOps workflows, separate application CI/CD

#### Pattern 3: Application Only (External Infrastructure)

**Configuration**:
```hcl
module "unreal_cloud_ddc" {
  # No ddc_infra_config - infrastructure managed separately
  
  ddc_application_config = {
    namespaces = { /* ... */ }
    compute = { /* ... */ }
  }
  
  # Reference external infrastructure
  existing_cluster_name = "my-existing-cluster"
  existing_s3_bucket = "my-existing-bucket"
  # ... other external references
}
```

**What Gets Deployed**:
- DDC Helm charts, TargetGroupBinding (application)
- Uses existing EKS cluster and infrastructure
- NO infrastructure creation

**Good For**: Shared infrastructure, multiple applications per cluster

### CI/CD Integration Patterns

#### Single Pipeline (Full Stack)

**Terraform Pipeline**:
```yaml
# GitHub Actions example
steps:
  - name: Deploy Infrastructure + Application
    run: |
      terraform init
      terraform apply -auto-approve
      # Everything deployed in single step
```

**Benefits**: Simple, single source of truth
**Drawbacks**: Slower deployments, mixed concerns

#### Separated Pipelines (Infrastructure + Application)

**Infrastructure Pipeline (Terraform)**:
```yaml
steps:
  - name: Deploy Infrastructure
    run: |
      terraform init
      terraform apply -auto-approve
  - name: Output Cluster Info
    run: |
      terraform output -json > cluster-info.json
      # Store outputs for application pipeline
```

**Application Pipeline (ArgoCD/GitHub Actions)**:
```yaml
steps:
  - name: Get Cluster Info
    run: |
      # Retrieve cluster info from infrastructure pipeline
      aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
  - name: Deploy Applications
    run: |
      helm upgrade --install ddc-app ./charts/ddc-wrapper
      helm upgrade --install ddc-tgb ./charts/ddc-infrastructure
```

**Manual Steps for Separate Application CI/CD**:

1. **Configure kubectl access**:
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region <region>
   ```

2. **Install CRDs** (if not using EKS Auto Mode):
   ```bash
   kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds"
   ```

3. **Deploy infrastructure charts**:
   ```bash
   helm repo add aws-eks https://aws.github.io/eks-charts
   helm install fluent-bit aws-eks/aws-for-fluent-bit --namespace kube-system
   helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace
   ```

4. **Deploy DDC application**:
   ```bash
   helm upgrade --install ddc-app ./charts/ddc-wrapper --namespace unreal-cloud-ddc --create-namespace
   ```

5. **Create TargetGroupBinding**:
   ```bash
   helm upgrade --install ddc-tgb ./charts/ddc-infrastructure --set targetGroupARN=<arn>
   ```

**ArgoCD Integration Example**:
```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: unreal-cloud-ddc
spec:
  source:
    repoURL: https://github.com/your-org/ddc-charts
    path: charts/ddc-wrapper
    helm:
      valueFiles:
      - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: unreal-cloud-ddc
```

**Benefits of Separation**: 
- Faster application deployments
- Clear separation of concerns
- Infrastructure stability
- GitOps compatibility

**Drawbacks of Separation**:
- More complex setup
- Coordination between pipelines
- Manual configuration steps

## State Management & Manual Changes

### Terraform State Limitations

**Critical Understanding**: When using Terraform for application deployment (Pattern 1), manual changes to the Kubernetes cluster are NOT tracked in Terraform state.

#### What Terraform Tracks

**Terraform State Contains**:
- `null_resource` execution status (did the command run?)
- Trigger values (what inputs caused re-execution?)
- Resource dependencies

**Terraform State Does NOT Contain**:
- Actual Kubernetes resource configurations
- Helm release values or status
- Pod states or replica counts
- Manual kubectl changes

#### Impact of Manual Changes

**Example Scenario**:
```bash
# Terraform deploys DDC with 2 replicas
terraform apply  # Creates deployment with replica_count = 2

# Developer manually scales up for testing
kubectl scale deployment ddc-app --replicas=5

# Terraform doesn't know about the change
terraform plan   # Shows "No changes" (incorrect!)
terraform apply  # May or may not reset to 2 replicas
```

**The Problem**: Terraform's `null_resource` only tracks whether the command executed, not the actual cluster state.

### Common Manual Change Scenarios

#### 1. Emergency Hotfixes

**Scenario**: Production issue requires immediate pod restart
```bash
# Emergency action
kubectl rollout restart deployment/ddc-app -n unreal-cloud-ddc

# Or emergency scaling
kubectl scale deployment ddc-app --replicas=10
```

**Impact**: 
- ✅ Immediate problem resolution
- ❌ Configuration drift from Terraform
- ❌ Next `terraform apply` may revert changes

#### 2. Configuration Debugging

**Scenario**: Testing configuration changes
```bash
# Direct ConfigMap edit for testing
kubectl edit configmap ddc-config -n unreal-cloud-ddc

# Or direct Helm value changes
helm upgrade ddc-app ./chart --set newValue=test
```

**Impact**:
- ✅ Fast iteration for debugging
- ❌ Changes not in version control
- ❌ Lost on next Terraform deployment

#### 3. Resource Adjustments

**Scenario**: Performance tuning
```bash
# Adjust resource limits
kubectl patch deployment ddc-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"ddc","resources":{"limits":{"memory":"16Gi"}}}]}}}}'
```

**Impact**:
- ✅ Immediate performance improvement
- ❌ Not reflected in Terraform configuration
- ❌ Reverted on next deployment

### Remediation Workflows

#### Workflow 1: Terraform-First (Recommended)

**Process**:
1. **Make changes in Terraform configuration**
2. **Apply via Terraform**
3. **Validate in cluster**

```bash
# 1. Update Terraform configuration
# Edit ddc_application_config.compute.replica_count = 5

# 2. Apply changes
terraform plan
terraform apply

# 3. Validate
kubectl get deployment ddc-app -n unreal-cloud-ddc
```

**Benefits**: 
- ✅ Changes tracked in version control
- ✅ Repeatable deployments
- ✅ No configuration drift

**Drawbacks**:
- ❌ Slower for emergency changes
- ❌ Requires Terraform access

#### Workflow 2: Manual-Then-Sync

**Process**:
1. **Make emergency manual changes**
2. **Document changes immediately**
3. **Update Terraform to match**
4. **Re-apply to confirm sync**

```bash
# 1. Emergency change
kubectl scale deployment ddc-app --replicas=10

# 2. Document (immediately!)
echo "Scaled ddc-app to 10 replicas due to high load - $(date)" >> changes.log

# 3. Update Terraform
# Edit ddc_application_config.compute.replica_count = 10

# 4. Sync and validate
terraform plan  # Should show "No changes"
terraform apply
```

**Benefits**:
- ✅ Fast emergency response
- ✅ Eventually consistent

**Drawbacks**:
- ❌ Temporary configuration drift
- ❌ Risk of forgetting to sync

#### Workflow 3: Drift Detection

**Process**:
1. **Regular drift detection**
2. **Identify discrepancies**
3. **Decide: revert or adopt**

```bash
# 1. Check current cluster state
kubectl get deployment ddc-app -o yaml > current-state.yaml

# 2. Compare with Terraform configuration
# Manual comparison or automated tools

# 3a. Revert to Terraform (discard manual changes)
terraform apply -replace="null_resource.helm_ddc_app"

# 3b. Adopt manual changes (update Terraform)
# Edit Terraform to match current state
terraform plan  # Verify no changes
```

### ArgoCD vs Terraform State Management

#### ArgoCD Approach (GitOps)

**How it works**:
- Git repository contains desired state
- ArgoCD continuously syncs cluster to Git
- Manual changes detected and can be auto-reverted

```yaml
# ArgoCD Application with auto-sync
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  syncPolicy:
    automated:
      prune: true      # Remove manual additions
      selfHeal: true   # Revert manual changes
```

**Benefits**:
- ✅ Continuous drift detection
- ✅ Automatic remediation
- ✅ Git-based audit trail

**Drawbacks**:
- ❌ Can revert emergency fixes
- ❌ Requires GitOps workflow

#### Terraform Approach (Our Implementation)

**How it works**:
- Terraform tracks execution, not state
- Manual changes persist until next apply
- Drift detection requires manual comparison

**Benefits**:
- ✅ Allows emergency manual changes
- ✅ Simpler mental model
- ✅ No continuous monitoring overhead

**Drawbacks**:
- ❌ No automatic drift detection
- ❌ Manual sync required
- ❌ Risk of configuration drift

### Best Practices for State Management

#### 1. Documentation Strategy

**Always document manual changes**:
```bash
# Create change log
echo "$(date): Scaled DDC to 10 replicas for load test - @username" >> cluster-changes.log

# Or use kubectl annotations
kubectl annotate deployment ddc-app manual-change="scaled-to-10-$(date +%s)"
```

#### 2. Regular Sync Checks

**Weekly drift detection**:
```bash
#!/bin/bash
# drift-check.sh
echo "Checking for configuration drift..."

# Get current replica count
CURRENT=$(kubectl get deployment ddc-app -o jsonpath='{.spec.replicas}')

# Get Terraform configured count
TERRAFORM=$(terraform output -json | jq -r '.ddc_services.value.replica_count')

if [ "$CURRENT" != "$TERRAFORM" ]; then
  echo "DRIFT DETECTED: Current=$CURRENT, Terraform=$TERRAFORM"
  exit 1
fi
```

#### 3. Emergency Change Protocol

**Standard Operating Procedure**:
1. **Make manual change** (document in commit message format)
2. **Create immediate ticket** to sync Terraform
3. **Set reminder** (max 24 hours) to update Terraform
4. **Validate sync** with `terraform plan`

#### 4. Testing Strategy

**Before production deployment**:
```bash
# Test Terraform idempotency
terraform apply
terraform plan  # Should show "No changes"

# Test manual change detection
kubectl scale deployment ddc-app --replicas=99
terraform apply  # Should reset to configured value
```

### When to Choose Each Approach

| Scenario | Terraform Pattern | ArgoCD Pattern | Recommendation |
|----------|------------------|----------------|----------------|
| Small team, simple deployments | ✅ Good fit | ❌ Overkill | Use Terraform |
| Large team, frequent changes | ⚠️ Drift risk | ✅ Good fit | Use ArgoCD |
| Emergency hotfixes needed | ✅ Allows manual changes | ❌ May auto-revert | Use Terraform |
| Strict compliance requirements | ❌ Manual drift possible | ✅ Enforced compliance | Use ArgoCD |
| Development environments | ✅ Flexible | ❌ Too rigid | Use Terraform |
| Production environments | ⚠️ Requires discipline | ✅ Automated governance | Use ArgoCD |

**Hybrid Approach**: Use Terraform for infrastructure, ArgoCD for applications - gets benefits of both.

### Command Types & Execution Flow

#### Command Categories

| Command | Type | Purpose | Execution Context |
|---------|------|---------|--------------|
| `aws eks update-kubeconfig` | AWS CLI | Configure kubectl access | Before any kubectl/helm operations |
| `aws eks wait cluster-active` | AWS CLI | Wait for cluster ready | After cluster creation |
| `kubectl get nodes` | Kubernetes | Verify cluster access | After kubeconfig setup |
| `kubectl apply -k` | Kubernetes | Install CRDs | After cluster ready |
| `helm repo add` | Helm | Add chart repository | Before helm install |
| `helm install` | Helm | Deploy application | After prerequisites |
| `helm upgrade --install` | Helm | Deploy or update | Idempotent operation |

#### Execution Dependencies

```
Terraform Infrastructure
├── EKS Cluster Creation
├── Wait for Cluster Active
└── Configure kubectl Access
    ├── Install CRDs
    ├── Deploy Infrastructure Charts (Fluent Bit, Cert Manager)
    ├── Deploy Application Charts (DDC)
    └── Create TargetGroupBinding
```

## Authentication & Security

### Overview

EKS authentication involves multiple layers working together to provide secure cluster access while maintaining operational flexibility.

### EKS Authentication Layers

Amazon EKS uses multiple authentication layers for different purposes. Understanding these layers is critical for proper infrastructure setup and troubleshooting.

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS AUTHENTICATION LAYERS                   │
└─────────────────────────────────────────────────────────────────┘

LAYER 1: INFRASTRUCTURE AUTHENTICATION (IRSA)
┌─────────────────────────────────────────────────────────────────┐
│  AWS Load Balancer Controller Pod                              │
│  ├─ Service Account: aws-load-balancer-controller              │
│  ├─ IRSA Role: arn:aws:iam::xxx:role/lbc-role                 │
│  └─ Needs: EKS OIDC Provider                                  │
│                                                                 │
│  Purpose: Let Kubernetes pods call AWS APIs                    │
│  Users: Infrastructure components (controllers, CSI drivers)   │
│  Auth Flow: K8s Token → AWS STS → Temporary AWS Credentials    │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                        AWS APIs                                 │
│  ├─ ELB: DescribeTargetHealth, RegisterTargets                │
│  ├─ S3: GetObject, PutObject                                  │
│  └─ Secrets Manager: GetSecretValue                           │
└─────────────────────────────────────────────────────────────────┘

LAYER 2: USER AUTHENTICATION (Application Level)
┌─────────────────────────────────────────────────────────────────┐
│  Game Developers                                               │
│  ├─ Current: Bearer Token → DDC Application                   │
│  └─ Future: OIDC/SAML → Identity Center → DDC Application     │
│                                                                 │
│  Purpose: Let users access DDC application                     │
│  Users: Game developers, build systems                         │
│  Auth Flow: User Login → Identity Provider → DDC App          │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                    DDC Application                              │
│  ├─ Current: Validates bearer tokens                          │
│  └─ Future: Validates OIDC tokens                             │
└─────────────────────────────────────────────────────────────────┘
```

#### Layer 1: Infrastructure Authentication (IRSA)

**IAM Roles for Service Accounts (IRSA)** allows Kubernetes pods to assume AWS IAM roles without storing AWS credentials.

**Components**:
1. **EKS OIDC Provider** - Created automatically by EKS, enables trust relationship between EKS and AWS IAM
2. **IAM Role** - Standard AWS IAM role with specific permissions and trust policy for OIDC provider
3. **Kubernetes Service Account** - Annotated with IAM role ARN (`eks.amazonaws.com/role-arn`)

**Authentication Flow**:
```
K8s Pod → K8s Token → AWS STS → Temporary AWS Credentials → AWS Service
```

**Module Implementation**:
The CGD Toolkit automatically creates OIDC provider and IRSA roles for infrastructure components like AWS Load Balancer Controller, Fluent Bit, and Cert Manager.

#### Layer 2: User Authentication (Application Level)

**Current**: DDC application uses bearer token authentication
**Future (v1.1)**: Planned OIDC integration with AWS IAM Identity Center or external providers

**Key Differences**:
| Aspect | Infrastructure OIDC (IRSA) | User OIDC |
|--------|---------------------------|-----------|
| **Purpose** | Pod → AWS API access | User → Application access |
| **Scope** | Infrastructure components | End users |
| **Tokens** | Kubernetes service account tokens | User identity tokens |
| **Provider** | EKS OIDC Provider | External identity provider |
| **Setup** | Required for module function | Optional feature enhancement |

### kubeconfig Management

#### What is kubeconfig?

**What**: Configuration file that tells kubectl how to connect to clusters
**Where**: `~/.kube/config` (default) or `KUBECONFIG` env var
**Contains**: Cluster endpoints, certificates, authentication methods

```yaml
# Example kubeconfig structure
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://ABC123.gr7.us-east-1.eks.amazonaws.com
    certificate-authority-data: LS0tLS1CRUdJTi...
  name: my-cluster
contexts:
- context:
    cluster: my-cluster
    user: my-cluster
  name: my-cluster
current-context: my-cluster
users:
- name: my-cluster
  user:
    exec:
      command: aws
      args: ["eks", "get-token", "--cluster-name", "my-cluster", "--region", "us-east-1"]
```

#### aws eks update-kubeconfig Explained

**What it does**:
1. Calls EKS API to get cluster endpoint + certificate
2. Creates/updates `~/.kube/config` with cluster info
3. Sets up AWS IAM authentication method

**Why the name is confusing**: It's not "logging in" - it's configuring your local kubectl to know how to connect and authenticate.

**Real-world analogy**: Like programming your garage door opener with the frequency and security code for your specific garage.

#### Authentication Flow
```
kubectl command
├── Reads ~/.kube/config
├── Sees exec: aws eks get-token
├── Runs aws eks get-token (uses your AWS credentials)
├── Gets temporary Kubernetes token
├── Sends request to EKS with token
└── EKS validates token with AWS IAM
```

**Security Benefits**: 
- kubeconfig is safe to store locally (no long-term secrets)
- Uses your existing AWS credentials (IAM roles/users)
- Tokens are temporary (15 minutes)

### EKS Access Control

#### Three-Layer Security Model

1. **Network Layer**: IP allowlist (`public_access_cidrs`) - controls who can reach the EKS API server
2. **Authentication**: AWS IAM - verifies who you are
3. **Authorization**: EKS access entries - defines what you can do in the cluster

#### Cluster Creator Automatic Access

**Important**: The IAM principal that creates the EKS cluster automatically receives cluster admin permissions via `bootstrapClusterCreatorAdminPermissions=true` (default behavior).

**Implications**:
- The cluster creator can run kubectl commands without additional configuration
- CI/CD pipelines work automatically if they use the same IAM role that created the cluster
- No additional EKS access entries are required for the cluster creator

#### EKS Access Entries (Additional Users)

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

#### Three Separate Authentication Systems

1. **EKS Cluster Management** (kubectl, CI/CD, troubleshooting)
   - Uses EKS access entries for additional users beyond cluster creator
   - Managed via AWS APIs and Terraform

2. **Infrastructure Component Authentication** (AWS Load Balancer Controller, Fluent Bit, etc.)
   - Uses IRSA (IAM Roles for Service Accounts) with EKS OIDC Provider
   - Allows Kubernetes pods to call AWS APIs securely
   - Managed via Terraform (OIDC provider + IAM roles)

3. **DDC Application Authentication** (Unreal Engine clients, build systems)
   - Uses ConfigMap containing DDC bearer tokens
   - Completely separate from EKS cluster access
   - Managed via Kubernetes resources

### Security Best Practices

#### No Long-Term Secrets

**Traditional Kubernetes**:
- Service account tokens (never expire)
- Client certificates (long-lived)
- Static kubeconfig files with embedded secrets

**EKS with IAM**:
- **15-minute tokens**: `aws eks get-token` generates temporary tokens
- **No embedded secrets**: kubeconfig contains commands, not credentials
- **Automatic rotation**: New token generated for each kubectl command
- **Revocation**: Disable IAM user/role = immediate access revocation

#### Multi-User Access Patterns

**Single Developer**:
```hcl
public_access_cidrs = ["149.120.37.45/32"]  # Your current IP
```

**Team Development**:
```hcl
public_access_cidrs = [
  "149.120.37.45/32",  # Developer 1
  "203.0.113.10/32",   # Developer 2
  "198.51.100.5/32"    # CI/CD system
]
```

**Office Network**:
```hcl
public_access_cidrs = ["10.0.0.0/8"]  # Corporate network
```

## Networking

### Load Balancer Architecture

#### Network Load Balancer (NLB) Strategy

**Why NLB over ALB**:
- **Static IPs**: Consistent endpoints for DNS configuration (ALB uses dynamic IPs)
- **Simpler architecture**: Layer 4 passthrough, less complexity than Layer 7 processing
- **TargetGroupBinding compatibility**: Works seamlessly with our Terraform + Kubernetes integration
- **Cost efficiency**: Lower cost per hour than ALB for simple HTTP forwarding

#### Traffic Flow

```
Game Developers (UE Clients)
├── DNS Resolution: us-east-1.ddc.example.com
├── NLB (Public Subnets)
├── TargetGroupBinding (Kubernetes CRD)
├── DDC Service (ClusterIP)
└── DDC Pods (Private Subnets)
```

### Kubernetes Networking Fundamentals

#### The Connection Between AWS and Kubernetes Networking

**CRITICAL**: EKS uses AWS VPC networking directly - pods get IP addresses from VPC subnet CIDR ranges via AWS VPC CNI. This is fundamentally different from overlay networking used by other Kubernetes distributions.

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS VPC NETWORK                         │
│  ├─ VPC CIDR: 10.0.0.0/16                                     │
│  ├─ Public Subnets: 10.0.1.0/24, 10.0.2.0/24                 │
│  ├─ Private Subnets: 10.0.10.0/24, 10.0.20.0/24               │
│  ├─ EC2 Instances (EKS Nodes): 10.0.10.5, 10.0.20.8          │
│  └─ Pod IPs: 10.0.10.100, 10.0.20.200 (from VPC subnets!)    │
│                                                                 │
│    ┌─────────────────────────────────────────────────────────┐ │
│    │           KUBERNETES SERVICE NETWORK                    │ │
│    │  ├─ Service CIDR: 10.96.0.0/12 (virtual only)          │ │
│    │  └─ Service IPs: 10.96.45.123 (not routable from VPC)  │ │
│    └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Key Technical Facts**:
- **Pod IPs** (10.0.x.x) come DIRECTLY from VPC subnet CIDR ranges via AWS VPC CNI
- **Same IP space**: Pods, nodes, and other VPC resources share the same network layer
- **No overlay network**: Unlike other Kubernetes distributions, EKS uses "underlay mode"
- **Service IPs** (10.96.x.x) are VIRTUAL - they don't exist on any network interface
- **AWS Load Balancers** can route to Pod IPs (VPC IPs) but NOT Service IPs (virtual)

**Example IP Allocation**:
```
VPC CIDR: 10.0.0.0/16
├─ Private Subnet 1: 10.0.10.0/24
│  ├─ Node: 10.0.10.5
│  └─ Pods: 10.0.10.100, 10.0.10.101, 10.0.10.102
└─ Private Subnet 2: 10.0.20.0/24
   ├─ Node: 10.0.20.8
   └─ Pods: 10.0.20.200, 10.0.20.201, 10.0.20.202
```

**Why This Matters**: AWS VPC CNI allocates IP addresses to pods from the node subnets, making pod IPs directly routable within the VPC. This enables direct load balancer → pod communication without complex overlay networking.

#### Kubernetes Service Types Explained

**ClusterIP** (What We Use):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cgd-unreal-cloud-ddc-initialize
spec:
  type: ClusterIP  # Default type
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: unreal-cloud-ddc
```

**What ClusterIP Does**:
- **Creates**: Virtual IP address (10.96.45.123) inside Kubernetes cluster
- **Accessible**: Only from inside Kubernetes cluster (pods, nodes)
- **NOT accessible**: From internet, AWS VPC, or external systems
- **Purpose**: Internal service discovery and load balancing

**What You See in AWS Console**: NOTHING - ClusterIP creates no AWS resources

**LoadBalancer** (What We DON'T Use):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer  # Creates AWS Load Balancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: my-app
```

**What LoadBalancer Does**:
- **Creates**: AWS Network Load Balancer automatically
- **Creates**: AWS Target Group with pod IPs or node IPs
- **Creates**: Security groups, listeners, health checks
- **Accessible**: From internet (if in public subnets)
- **Problem**: Terraform can't manage controller-created AWS resources

**What You See in AWS Console**: New NLB, target group, security groups (managed by Kubernetes, not Terraform)

**NodePort** (Traditional Approach):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Opens port 30080 on every node
  selector:
    app: my-app
```

**What NodePort Does**:
- **Opens**: Port 30080 on EVERY Kubernetes node (EC2 instance)
- **Routes**: Node IP:30080 → Pod IP:80
- **Accessible**: From VPC (if security groups allow)
- **Problem**: Random high ports, requires security group management

**What You See in AWS Console**: Nothing new, but nodes listen on port 30080

#### Our Architecture: ClusterIP + TargetGroupBinding

**Why We Use ClusterIP**:
- **No AWS resources created**: Terraform maintains full control
- **Internal service**: Perfect for TargetGroupBinding to discover pods
- **Clean separation**: Kubernetes handles service, AWS handles load balancing

**How TargetGroupBinding Bridges the Gap**:
```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: cgd-unreal-cloud-ddc-tgb
spec:
  serviceRef:
    name: cgd-unreal-cloud-ddc-initialize  # ClusterIP service
    port: 80
  targetGroupARN: arn:aws:elasticloadbalancing:...  # Terraform-created
  targetType: ip
```

**What TargetGroupBinding Does**:
1. **Finds ClusterIP service**: `cgd-unreal-cloud-ddc-initialize`
2. **Gets pod IPs**: 10.244.1.100, 10.244.2.200 (from service endpoints)
3. **Registers with AWS**: Calls AWS ELB API to add pod IPs to target group
4. **Monitors changes**: Adds/removes pod IPs as pods start/stop

**Traffic Flow**:
```
Internet Request
├─ DNS: us-east-1.ddc.example.com → NLB IP
├─ NLB: Routes to registered pod IP (10.244.1.100:80)
├─ AWS VPC: Routes pod IP to correct node
├─ Node: Forwards to pod on that node
└─ Pod: Handles request directly
```

#### AWS Load Balancer Controller Architecture

**What AWS Load Balancer Controller Does**:

**Function 1: Create Load Balancers** (We DON'T Use):
- **Triggered by**: Kubernetes Service type: LoadBalancer
- **Creates**: New AWS NLB, target groups, security groups
- **Requires**: Subnet discovery tags for load balancer placement
- **Problem**: Terraform can't manage these resources

**Function 2: Manage Existing Load Balancers** (We DO Use):
- **Triggered by**: TargetGroupBinding custom resource
- **Manages**: Existing Terraform-created target groups
- **Registers**: Pod IPs in existing target groups
- **No AWS resource creation**: Only target registration/deregistration

**Why We Need the Controller**:
- **TargetGroupBinding is a CRD**: Custom Resource Definition requires controller
- **Pod IP registration**: Controller watches pods and updates target groups
- **Automatic updates**: Adds new pods, removes terminated pods
- **Health monitoring**: Integrates with Kubernetes readiness probes

**Can We Remove It?**: NO - Without the controller, TargetGroupBinding resources would exist but do nothing.

#### Target Type Deep Dive

**Target Type "ip" (What We Use)**:

**AWS Console View**:
```
Target Group: cgd-unreal-cloud-ddc-tg
┌─────────────────┬──────┬─────────┬─────────┐
│ Target          │ Port │ Health  │ AZ      │
├─────────────────┼──────┼─────────┼─────────┤
│ 10.244.1.100    │ 80   │ Healthy │ us-e-1a │  ← Pod IP
│ 10.244.2.200    │ 80   │ Healthy │ us-e-1b │  ← Pod IP
│ 10.244.3.150    │ 80   │ Healthy │ us-e-1c │  ← Pod IP
└─────────────────┴──────┴─────────┴─────────┘
```

**Traffic Flow**: NLB → Pod IP (direct)
**Benefits**: Lower latency, no extra hops
**Required For**: EKS Auto Mode, Fargate

**Target Type "instance" (Traditional)**:

**AWS Console View**:
```
Target Group: my-target-group
┌─────────────────┬──────┬─────────┬─────────┐
│ Target          │ Port │ Health  │ AZ      │
├─────────────────┼──────┼─────────┼─────────┤
│ i-1234567890abc │ 30080│ Healthy │ us-e-1a │  ← EC2 Instance ID
│ i-0987654321def │ 30080│ Healthy │ us-e-1b │  ← EC2 Instance ID
│ i-5678901234ghi │ 30080│ Healthy │ us-e-1c │  ← EC2 Instance ID
└─────────────────┴──────┴─────────┴─────────┘
```

**Traffic Flow**: NLB → Node IP:30080 → Pod IP:80 (extra hop)
**Benefits**: Works with older Kubernetes versions
**Requires**: NodePort service (opens random high ports)

#### Network Flow Comparison

**Our Architecture (ClusterIP + TargetGroupBinding + IP targets)**:
```
Game Client
├─ DNS Lookup: us-east-1.ddc.example.com
├─ HTTPS Request: 443 → NLB
├─ NLB: Forwards to Pod IP (10.244.1.100:80)
├─ AWS VPC: Routes to node containing pod
├─ Node: Delivers directly to pod
└─ Pod: Processes request

Hops: 4 (Client → NLB → VPC → Node → Pod)
```

**Traditional Architecture (LoadBalancer service + Instance targets)**:
```
Game Client
├─ DNS Lookup: service-domain.com
├─ HTTPS Request: 443 → NLB (created by Kubernetes)
├─ NLB: Forwards to Node IP (10.0.10.5:30080)
├─ Node: Receives on NodePort 30080
├─ Node: Forwards to Pod IP (10.244.1.100:80)
└─ Pod: Processes request

Hops: 5 (Client → NLB → Node → Node Internal → Pod)
```

**Performance Difference**: Our approach eliminates one network hop and uses standard ports.

#### Why Our Architecture Works

**Terraform Controls**:
- ✅ NLB creation and configuration
- ✅ Target group creation and health checks
- ✅ Security groups and networking rules
- ✅ DNS records and SSL certificates
- ✅ Complete resource lifecycle management

**Kubernetes Controls**:
- ✅ Pod lifecycle and health
- ✅ Service discovery and endpoints
- ✅ Internal load balancing
- ✅ Application configuration

**AWS Load Balancer Controller Bridges**:
- ✅ Registers pod IPs in Terraform-created target groups
- ✅ Updates registrations as pods start/stop
- ✅ Integrates Kubernetes health with AWS health checks
- ✅ No AWS resource creation (only target management)

**Result**: Best of both worlds - Terraform infrastructure control + Kubernetes application flexibility.

### EKS Compute Types: Networking Behavior Comparison

#### The VAST Differences Between EKS Compute Types

**EKS networking behavior changes dramatically** based on compute type. What works on managed nodes may fail on Fargate or Auto Mode.

#### EKS Managed Node Groups (Traditional)

**Network Architecture**:
```
AWS VPC Network: 10.0.0.0/16
├─ Nodes: 10.0.10.5, 10.0.20.8 (EC2 instances)
├─ Pod Network: 10.244.0.0/16 (overlay on nodes)
└─ Service Network: 10.96.0.0/12 (virtual IPs)
```

**LoadBalancer Service Behavior**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
```

**What AWS Load Balancer Controller Creates**:
- **Target Type**: `instance` (EC2 instance IDs)
- **Target Registration**: Node IPs with NodePort
- **Security Groups**: Attaches to nodes (you control)
- **Subnets**: Uses node subnets automatically
- **Health Checks**: To NodePort on nodes

**AWS Console Target View**:
```
┌─────────────────┬──────┬────────┐
│ Target          │ Port │ Health │
├─────────────────┼──────┼────────┤
│ i-1234567890abc │ 32080│ Healthy│  ← EC2 Instance
│ i-0987654321def │ 32080│ Healthy│  ← EC2 Instance
└─────────────────┴──────┴────────┘
```

**Traffic Flow**: NLB → Node IP:32080 → Pod IP:80

**TargetGroupBinding Support**: ✅ Works with both `ip` and `instance` target types

#### EKS Fargate

**Network Architecture**:
```
AWS VPC Network: 10.0.0.0/16
├─ No Nodes: Fargate manages compute
├─ Pod Network: 10.0.x.x (pods get VPC IPs directly)
└─ Service Network: 10.96.0.0/12 (virtual IPs)
```

**LoadBalancer Service Behavior**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
```

**What AWS Load Balancer Controller Creates**:
- **Target Type**: `ip` (REQUIRED - no nodes exist)
- **Target Registration**: Pod IPs directly
- **Security Groups**: Creates new security groups (limited control)
- **Subnets**: REQUIRES subnet discovery tags
- **Health Checks**: Directly to pod IPs

**AWS Console Target View**:
```
┌─────────────────┬──────┬────────┐
│ Target          │ Port │ Health │
├─────────────────┼──────┼────────┤
│ 10.0.10.100     │ 80   │ Healthy│  ← Pod IP (VPC IP)
│ 10.0.20.200     │ 80   │ Healthy│  ← Pod IP (VPC IP)
└─────────────────┴──────┴────────┘
```

**Traffic Flow**: NLB → Pod IP:80 (direct)

**TargetGroupBinding Support**: ✅ Works with `ip` target type only

**CRITICAL Fargate Limitation**: Pods get VPC IPs, so security group rules must allow NLB → Pod communication in VPC CIDR ranges.

#### EKS Auto Mode

**Network Architecture**:
```
AWS VPC Network: 10.0.0.0/16
├─ Nodes: 10.0.10.5, 10.0.20.8 (managed by Karpenter)
├─ Pod Network: 10.244.0.0/16 (overlay network)
└─ Service Network: 10.96.0.0/12 (virtual IPs)
```

**LoadBalancer Service Behavior**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
```

**What AWS Load Balancer Controller Creates**:
- **Target Type**: `ip` (REQUIRED - nodes are ephemeral)
- **Target Registration**: Pod IPs from overlay network
- **Security Groups**: Creates new security groups (limited control)
- **Subnets**: REQUIRES subnet discovery tags
- **Health Checks**: Directly to pod IPs

**AWS Console Target View**:
```
┌─────────────────┬──────┬────────┐
│ Target          │ Port │ Health │
├─────────────────┼──────┼────────┤
│ 10.0.10.100     │ 80   │ Healthy│  ← Pod IP (VPC subnet)
│ 10.0.20.200     │ 80   │ Healthy│  ← Pod IP (VPC subnet)
└─────────────────┴──────┴────────┘
```

**Traffic Flow**: NLB → Pod IP:80 (direct to VPC subnet IP)

**TargetGroupBinding Support**: ✅ Works with `ip` target type only

**CRITICAL Auto Mode Issue**: Nodes are ephemeral and security groups are auto-managed, making Terraform integration complex.

### Service Type Impact on Load Balancer Controller

#### ClusterIP + TargetGroupBinding (Our Approach)

**All EKS Compute Types**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: ClusterIP  # No AWS resources created
---
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
spec:
  serviceRef:
    name: my-service
  targetGroupARN: arn:aws:elasticloadbalancing:...  # Terraform-created
```

**What Load Balancer Controller Does**:
- **No AWS resource creation**: Uses existing target group
- **Target registration only**: Registers pod IPs in existing target group
- **Works with all compute types**: Managed nodes, Fargate, Auto Mode
- **Terraform control**: Full control over NLB, target groups, security groups

**Benefits**:
- ✅ **Consistent behavior**: Same across all EKS compute types
- ✅ **Terraform control**: All AWS resources managed by Terraform
- ✅ **No subnet tags needed**: Not creating load balancers
- ✅ **Predictable**: No controller-managed AWS resources

#### LoadBalancer Service (Standard Kubernetes)

**EKS Managed Nodes**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
  # Creates NLB with instance targets
```

**What Load Balancer Controller Does**:
- **Creates**: AWS NLB, target group, security groups
- **Target type**: `instance` (registers EC2 instance IDs)
- **Requires**: NodePort service (opens random high ports)
- **Security groups**: Attaches to existing node security groups
- **Subnet discovery**: Uses node subnets (no tags needed)

**EKS Fargate**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
  # Creates NLB with IP targets
```

**What Load Balancer Controller Does**:
- **Creates**: AWS NLB, target group, security groups
- **Target type**: `ip` (registers pod VPC IPs)
- **Requires**: Subnet discovery tags (controller must find subnets)
- **Security groups**: Creates new security groups (limited Terraform control)
- **Health checks**: Direct to pod IPs

**EKS Auto Mode**:
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer
  # Creates NLB with IP targets
```

**What Load Balancer Controller Does**:
- **Creates**: AWS NLB, target group, security groups
- **Target type**: `ip` (registers pod overlay IPs)
- **Requires**: Subnet discovery tags (controller must find subnets)
- **Security groups**: Creates new security groups (conflicts with Terraform)
- **Complex networking**: VPC subnet IP management through ephemeral nodes

### Would LoadBalancer Service Eliminate TargetGroupBinding?

**YES** - If you use `type: LoadBalancer`, the controller creates everything automatically:

**LoadBalancer Service Creates**:
- AWS Network Load Balancer
- AWS Target Group
- Target registration (pod IPs or instance IDs)
- Security group rules
- Health check configuration

**No TargetGroupBinding needed** - the controller handles target registration automatically.

**But you lose Terraform control**:
- ❌ Can't customize NLB settings
- ❌ Can't control security groups
- ❌ Can't integrate with existing DNS/certificates
- ❌ Terraform destroy fails (can't delete controller-managed resources)
- ❌ No predictable resource names

### Security Group Behavior by Compute Type

#### EKS Managed Nodes

**LoadBalancer Service**:
- **Attaches to existing node security groups**: You control the rules
- **Predictable**: Uses security groups you created
- **Terraform friendly**: Can reference and modify

**TargetGroupBinding**:
- **Uses your security groups**: Full Terraform control
- **Custom rules**: Allow NLB → Pod communication

#### EKS Fargate

**LoadBalancer Service**:
- **Creates new security groups**: Controller-managed
- **Limited control**: Can't easily customize rules
- **Terraform conflicts**: Can't reference controller-created resources

**TargetGroupBinding**:
- **Uses your security groups**: But must allow VPC CIDR ranges
- **Complex rules**: Pods get VPC IPs, need broader access

#### EKS Auto Mode

**LoadBalancer Service**:
- **Creates new security groups**: Controller-managed
- **Conflicts with Terraform**: Auto-managed vs Terraform-managed
- **Ephemeral nodes**: Security group attachments change frequently

**TargetGroupBinding**:
- **Requires careful setup**: Must force consistent security groups
- **Our workaround**: Make EKS cluster use Terraform-managed security groups
- **Complex troubleshooting**: Overlay network + ephemeral nodes

### Subnet Discovery Tags by Compute Type

#### When Subnet Tags Are Required

**EKS Managed Nodes + LoadBalancer Service**: ❌ **Not required**
- Uses node subnets automatically
- No subnet discovery needed

**EKS Fargate + LoadBalancer Service**: ✅ **Required**
- Controller must discover subnets for load balancer placement
- Tags: `kubernetes.io/role/elb=1` (public), `kubernetes.io/role/internal-elb=1` (private)

**EKS Auto Mode + LoadBalancer Service**: ✅ **Required**
- Controller must discover subnets for load balancer placement
- Same tags as Fargate

**Any Compute Type + TargetGroupBinding**: ❌ **Not required**
- Uses existing Terraform-created load balancer
- No subnet discovery needed

### Recommendation by Use Case

#### For Terraform Infrastructure-as-Code

**Use**: ClusterIP + TargetGroupBinding
**Reason**: Full Terraform control, consistent across compute types
**Works with**: All EKS compute types

#### For Simple Console Deployments

**EKS Managed Nodes**: LoadBalancer service (simple, works well)
**EKS Fargate**: LoadBalancer service (requires subnet tags)
**EKS Auto Mode**: LoadBalancer service (requires subnet tags, complex troubleshooting)

#### For Enterprise/Production

**Use**: ClusterIP + TargetGroupBinding
**Reason**: Predictable, controllable, integrates with existing infrastructure
**Avoid**: LoadBalancer service (creates unmanaged resources)

### Summary: The Networking Complexity Reality

**EKS Managed Nodes**: Most flexible, supports both approaches well
**EKS Fargate**: Simpler compute, more complex networking (VPC IPs)
**EKS Auto Mode**: Most complex - "simplified" compute pushes complexity to networking

**Key Insight**: "Simplified" EKS compute options (Fargate, Auto Mode) often create more networking complexity, especially when integrating with Terraform infrastructure-as-code.

**Our Choice**: ClusterIP + TargetGroupBinding provides consistent behavior across all compute types while maintaining Terraform control.

#### IRSA Configuration

**Service Account**: `aws-load-balancer-controller`
**IAM Role**: Created automatically with required permissions
**Permissions**:
- `elasticloadbalancing:*` - Manage target groups and listeners
- `ec2:DescribeInstances` - Discover node IPs
- `ec2:DescribeNetworkInterfaces` - Manage ENI attachments
- `iam:CreateServiceLinkedRole` - Create ELB service-linked roles

**CRITICAL**: The controller needs these permissions to register/deregister pod IPs in target groups, even though we don't create load balancers.

```hcl
# Automatic IRSA role creation in ddc-infra
resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name = "${var.name_prefix}-aws-load-balancer-controller-role"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}
```

#### Installation Process

**Helm Chart**: `eks/aws-load-balancer-controller`
**Repository**: `https://aws.github.io/eks-charts`
**Configuration**:
```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --repo https://aws.github.io/eks-charts \
  --namespace kube-system \
  --set clusterName=${cluster_name} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${role_arn}
```

### Network Mode Decision Matrix

| Scenario | EKS Compute | Service Type | Target Type | Terraform Control | Complexity |
|----------|-------------|--------------|-------------|-------------------|------------|
| **Our Approach** | Auto Mode | ClusterIP + TGB | ip | Full | Medium |
| **Simple Console** | Managed Nodes | LoadBalancer | instance | None | Low |
| **Fargate Standard** | Fargate | LoadBalancer | ip | Limited | Medium |
| **Auto Mode Standard** | Auto Mode | LoadBalancer | ip | Limited | High |
| **Enterprise** | Managed Nodes | ClusterIP + TGB | ip | Full | Low |

**TGB = TargetGroupBinding**

**Key Takeaway**: Our approach (ClusterIP + TargetGroupBinding) provides the best balance of control and consistency across EKS compute types.

### TargetGroupBinding Deep Dive

#### What is TargetGroupBinding?

**Purpose**: Connects Terraform-managed AWS target groups to Kubernetes services
**CRD**: Custom Resource Definition provided by AWS Load Balancer Controller
**Lifecycle**: Managed by ddc-infra module (infrastructure concern)
**Location**: Deployed to application namespace but managed by infrastructure

#### Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                    TERRAFORM LAYER                             │
│  ├─ Network Load Balancer                                      │
│  ├─ Target Group (empty initially)                             │
│  ├─ Listeners (80 → target group, 443 → target group)         │
│  └─ Security Groups                                            │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                 TARGETGROUPBINDING LAYER                       │
│  ├─ Kubernetes CRD Resource                                    │
│  ├─ References: Target Group ARN + Service Name                │
│  ├─ Managed by: AWS Load Balancer Controller                   │
│  └─ Result: Populates target group with pod IPs               │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                   KUBERNETES LAYER                             │
│  ├─ ClusterIP Service (cgd-unreal-cloud-ddc-initialize)        │
│  ├─ Service Endpoints (pod IPs + ports)                        │
│  └─ DDC Pods (actual application containers)                   │
└─────────────────────────────────────────────────────────────────┘
```

#### TargetGroupBinding Configuration

**Resource Definition**:
```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: cgd-unreal-cloud-ddc-tgb
  namespace: unreal-cloud-ddc
spec:
  serviceRef:
    name: cgd-unreal-cloud-ddc-initialize  # Must match DDC service name
    port: 80                               # Service port
  targetGroupARN: arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/cgd-unreal-cloud-ddc-tg/abc123
  targetType: ip                           # Use pod IPs directly
```

**Key Fields Explained**:
- **serviceRef.name**: Must exactly match the DDC service name
- **serviceRef.port**: Must match the service port (80)
- **targetGroupARN**: References Terraform-created target group
- **targetType**: "ip" for direct pod IP registration (required for Fargate/EKS Auto Mode)

#### How TargetGroupBinding Works

**Step 1: Service Discovery**
```bash
# AWS Load Balancer Controller watches for TargetGroupBinding resources
kubectl get targetgroupbinding -n unreal-cloud-ddc
```

**Step 2: Endpoint Resolution**
```bash
# Controller resolves service to pod IPs
kubectl get endpoints cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc
# Shows: 10.0.1.100:80, 10.0.2.200:80 (pod IPs)
```

**Step 3: Target Registration**
```bash
# Controller registers pod IPs with AWS target group
aws elbv2 describe-target-health --target-group-arn <arn>
# Shows: 10.0.1.100:80 healthy, 10.0.2.200:80 healthy
```

**Step 4: Health Monitoring**
- NLB performs health checks directly to pod IPs
- Unhealthy pods automatically removed from target group
- New pods automatically added when they become ready

#### Troubleshooting TargetGroupBinding

**Common Issues**:

**Issue 1: TargetGroupBinding Not Ready**
```bash
# Check TargetGroupBinding status
kubectl describe targetgroupbinding cgd-unreal-cloud-ddc-tgb -n unreal-cloud-ddc

# Common error: "service not found"
# Solution: Ensure DDC service exists and name matches exactly
kubectl get svc cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc
```

**Issue 2: Targets Not Registering**
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common error: "subnet not associated with target group"
# Solution: Ensure pod subnets match target group subnets
```

**Issue 3: Health Check Failures**
```bash
# Check target health in AWS
aws elbv2 describe-target-health --target-group-arn <arn>

# Common error: "connection refused"
# Solution: Verify pod is listening on correct port (80)
kubectl exec -it <pod-name> -n unreal-cloud-ddc -- netstat -tlnp
```

#### Security Group Strategy

**NLB Security Group**:
- Ingress: HTTPS (443) from allowed CIDRs
- Ingress: HTTP (80) from allowed CIDRs (debug mode only)
- Egress: To EKS cluster security group on port 80

**EKS Cluster Security Group**:
- Ingress: From NLB security group on port 80
- Egress: All traffic (managed by EKS)

**Why This Works**:
- NLB sends traffic directly to pod IPs (not node IPs)
- Security group rules allow NLB → Pod communication
- TargetGroupBinding handles IP registration automatically

**Internal Security Group**:
- ScyllaDB communication (port 9042)
- Inter-service communication within VPC

### Custom NLB Architecture

#### Why Custom NLB vs Kubernetes LoadBalancer

**Standard Kubernetes Approach**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ddc-service
spec:
  type: LoadBalancer  # Creates AWS NLB automatically
  ports:
  - port: 80
    targetPort: 80
```

**Problems with Standard Approach**:
- **No Terraform control**: Load balancer created by Kubernetes controller
- **Limited configuration**: Can't customize security groups, subnets, DNS
- **Destroy issues**: Terraform can't clean up controller-created resources
- **No integration**: Can't reference load balancer in other Terraform resources

**Our Custom Approach**:
```hcl
# Terraform creates and manages NLB directly
resource "aws_lb" "nlb" {
  name               = "${var.name_prefix}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.nlb.id]
  
  enable_deletion_protection = false
  
  tags = local.common_tags
}

resource "aws_lb_target_group" "ddc" {
  name        = "${var.name_prefix}-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Direct pod IP targeting
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health/live"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "ddc_https" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ddc.arn
  }
}
```

**Benefits of Custom Approach**:
- ✅ **Full Terraform control**: All resources managed by Terraform
- ✅ **Custom configuration**: Security groups, health checks, SSL policies
- ✅ **Clean destroy**: Terraform handles all cleanup
- ✅ **Integration**: Can reference NLB in Route53, security groups, etc.
- ✅ **Predictable**: No controller-managed resources to cause conflicts

#### NLB Configuration Details

**Load Balancer Settings**:
- **Type**: Network Load Balancer (Layer 4)
- **Scheme**: Internet-facing (public subnets)
- **IP Address Type**: IPv4
- **Deletion Protection**: Disabled (allows Terraform destroy)

**Target Group Settings**:
- **Target Type**: IP (direct pod IP targeting)
- **Protocol**: TCP (Layer 4)
- **Health Check**: HTTP GET /health/live
- **Deregistration Delay**: 300 seconds (default)

**Listener Configuration**:
- **HTTPS (443)**: TLS termination with ACM certificate
- **HTTP (80)**: Optional for debugging (disabled by default)
- **SSL Policy**: TLS 1.3 for security

**Health Check Configuration**:
```hcl
health_check {
  enabled             = true
  healthy_threshold   = 2      # 2 successful checks = healthy
  interval            = 30     # Check every 30 seconds
  matcher             = "200"  # HTTP 200 OK expected
  path                = "/health/live"  # DDC health endpoint
  port                = "traffic-port" # Same port as traffic (80)
  protocol            = "HTTP"  # HTTP health checks
  timeout             = 5      # 5 second timeout
  unhealthy_threshold = 2      # 2 failed checks = unhealthy
}
```

#### Integration with Route53

**DNS Configuration**:
```hcl
resource "aws_route53_record" "ddc" {
  zone_id = var.route53_zone_id
  name    = "${var.region}.ddc"
  type    = "A"
  
  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}
```

**Result**: `us-east-1.ddc.example.com` → NLB → TargetGroupBinding → DDC Pods

#### Multi-Region NLB Strategy

**Regional Isolation**:
- Each region has its own NLB
- Regional DNS names (us-east-1.ddc.example.com)
- No cross-region traffic routing
- Independent scaling and failover

**Benefits**:
- **Lower latency**: Regional traffic stays regional
- **Fault isolation**: Region failures don't affect other regions
- **Simplified networking**: No complex routing rules
- **Cost optimization**: No cross-region data transfer

### Advanced Networking Features

#### VPC Endpoint Integration

**S3 VPC Endpoint**:
- **Type**: Gateway endpoint (no cost)
- **Purpose**: Direct S3 access from pods
- **Benefit**: No NAT Gateway charges for S3 traffic

**EKS VPC Endpoint**:
- **Type**: Interface endpoint
- **Purpose**: Private EKS API access
- **Benefit**: Reduced NAT Gateway usage for kubectl commands

#### Network Security

**Defense in Depth**:
1. **Internet Gateway**: Only in public subnets
2. **NLB Security Group**: Restricts ingress to allowed CIDRs
3. **EKS Security Group**: Only allows traffic from NLB
4. **Pod Security**: DDC application validates bearer tokens
5. **S3 Bucket Policy**: Restricts access to DDC service account

**Zero Trust Principles**:
- No 0.0.0.0/0 ingress rules (except from NLB to pods)
- All inter-service communication authenticated
- Least privilege IAM roles
- Encrypted traffic (TLS at NLB, HTTPS to pods)

### DNS Architecture

#### Regional DNS Pattern

**Public DNS** (internet-accessible):
- Pattern: `<region>.ddc.<domain>`
- Example: `us-east-1.ddc.example.com`
- Points to: Regional NLB

**Private DNS** (VPC-internal):
- Pattern: `<region>.<service>.<private-zone>`
- Example: `us-east-1.unreal-cloud-ddc.cgd.local`
- Points to: Internal services, ScyllaDB cluster

#### Multi-Region DNS Strategy

```
Primary Region (us-east-1):
├── us-east-1.ddc.example.com → NLB us-east-1
└── Creates private zone: cgd.local

Secondary Region (us-west-2):
├── us-west-2.ddc.example.com → NLB us-west-2
└── Associates with private zone: cgd.local
```

### VPC Endpoints

#### EKS API Endpoint Benefits

**Without VPC Endpoint**:
- EKS API calls go through internet
- Requires NAT Gateway for private subnets
- Higher latency and costs

**With VPC Endpoint**:
- Direct private connection to EKS API
- No internet egress required
- Lower latency and costs
- Enhanced security

#### Supported VPC Endpoints

| Service | Type | Purpose | Cost Impact |
|---------|------|---------|-------------|
| EKS | Interface | Private EKS API access | Reduces NAT Gateway usage |
| S3 | Gateway | DDC S3 bucket access | No additional cost |
| CloudWatch Logs | Interface | Log shipping | Reduces data transfer costs |
| Secrets Manager | Interface | Bearer token access | Reduces NAT Gateway usage |
| SSM | Interface | ScyllaDB automation | Reduces NAT Gateway usage |

## Compute

### EKS Auto Mode Overview

**Application-Driven Infrastructure**: With EKS Auto Mode, the application requests infrastructure (not Terraform).

#### Node Groups vs EKS Auto Mode: Complete Terminology Guide

**CRITICAL**: Node Groups ≠ Node Pools - These are completely different concepts!

**Traditional EKS Node Groups**:
- **Node Group** = Terraform-managed collection of identical EC2 instances
- **Configuration**: You specify instance type, count (min/max/desired), security groups
- **Scaling**: Manual via Auto Scaling Groups or Cluster Autoscaler
- **Pod Placement**: Kubernetes scheduler assigns pods to any available node
- **Example**: "Create 3 m5.large instances with specific security groups"

**EKS Auto Mode (Completely Different)**:
- **Built-in Node Pools** = AWS-managed templates ("general-purpose", "system")
- **Custom NodePool** = Your workload requirements template
- **NodeClass** = Your infrastructure configuration (subnets, security groups, storage)
- **Dynamic Scaling**: AWS creates/destroys instances based on pod requests
- **Pod Placement**: Karpenter analyzes pod requirements and creates matching nodes
- **Example**: "When pods need NVMe storage, create appropriate instances automatically"

#### EKS Auto Mode Architecture: 4 Key Components

**1. Built-in Node Pools** (AWS-Managed):
```hcl
compute_config {
  node_pools = ["general-purpose", "system"]  # AWS built-in templates
}
```
- **"general-purpose"**: For application workloads (DDC pods)
- **"system"**: For Kubernetes system pods (kube-system namespace)
- **AWS manages**: Instance selection, scaling, lifecycle
- **You cannot customize**: These are AWS-controlled templates

**2. Custom NodeClass** (Your Infrastructure Config):
```yaml
# Created via kubectl (see bottom of eks.tf)
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: comprehensive-nodeclass
spec:
  role: my-node-role
  subnetSelectorTerms:
    - id: subnet-12345
  securityGroupSelectorTerms:
    - id: sg-67890  # Our Terraform-managed security group
```
- **Purpose**: Infrastructure-level configuration
- **Contains**: Subnets, security groups, storage, networking
- **Reusable**: Multiple NodePools can reference same NodeClass

**3. Custom NodePool** (Your Workload Requirements):
```yaml
# Created via kubectl (see bottom of eks.tf)
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: comprehensive
spec:
  template:
    spec:
      nodeClassRef:
        name: comprehensive-nodeclass  # References NodeClass above
      requirements:
        - key: eks.amazonaws.com/instance-category
          operator: In
          values: ["i"]  # NVMe instance families only
```
- **Purpose**: Workload-specific requirements
- **Contains**: Instance types, capacity types, architecture
- **References**: NodeClass for infrastructure config

**4. Pod Specifications** (Triggers Node Creation):
```yaml
# In Helm chart (ddc-app module)
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      nodeSelector:
        node.kubernetes.io/instance-type: "i4i.xlarge"  # Preferred instance
      containers:
      - name: ddc
        resources:
          requests:
            cpu: "2000m"     # 2 CPU cores
            memory: "8Gi"    # 8GB RAM
```
- **Purpose**: Actual workload requirements
- **Triggers**: Karpenter node provisioning
- **Contains**: Resource requests, node selectors, tolerations

#### Where Node Scaling is Configured

**Traditional EKS**:
```hcl
node_group {
  desired_size = 2
  max_size     = 10
  min_size     = 1
  instance_types = ["m5.large"]
}
```

**EKS Auto Mode**:
```hcl
# No node counts in Terraform!
# Scaling happens automatically based on pod requests:
ddc_application_config = {
  compute = {
    replica_count    = 2             # Number of DDC pods
    cpu_requests     = "2000m"       # Each pod needs 2 CPU cores
    memory_requests  = "8Gi"         # Each pod needs 8GB RAM
    instance_type    = "i4i.xlarge"  # Preferred instance type
  }
}
```

**How EKS Auto Mode Determines Node Count**:
1. **Pod requests**: 2 replicas × 2 CPU cores = 4 CPU cores needed
2. **Instance capacity**: i4i.xlarge has 4 vCPUs
3. **Auto scaling decision**: Create 1 node (sufficient for workload)
4. **Dynamic adjustment**: If you scale to 4 replicas, creates 2 nodes

#### NodeClass vs Security Groups

**What NodeClass Does**:
- **Selects security groups** to attach to EC2 instances (nodes)
- **Selects subnets** where nodes should be created
- **Configures storage** (NVMe, EBS settings)
- **Sets networking policies** (SNAT, network policies)

**Our NodeClass Configuration** (see bottom of eks.tf):
```yaml
securityGroupSelectorTerms:
  - id: ${aws_security_group.cluster_security_group.id}
```

**This tells EKS Auto Mode**: "When creating nodes, attach our Terraform-managed security group instead of the default EKS-managed one"

**Why This Matters**:
- **Traditional**: EKS creates security groups automatically (we can't control rules)
- **Our approach**: We create security group in Terraform (we control all rules)
- **Result**: NLB can communicate with nodes because we explicitly allow it

#### Key Architectural Differences

| Aspect | Traditional Node Groups | EKS Auto Mode |
|--------|------------------------|----------------|
| **Node Count** | Set explicitly (min/max/desired) | Determined by pod requests |
| **Scaling** | Manual or scheduled | Automatic based on workload |
| **Instance Types** | Fixed per node group | Dynamic based on pod requirements |
| **Security Groups** | Attached to node group | Selected via NodeClass |
| **Lifecycle** | Long-lived instances | Instances created/destroyed as needed |
| **Configuration** | Terraform node group resources | Kubernetes NodeClass/NodePool |

#### Practical Implications

**For Developers**:
- **No capacity planning**: Don't worry about node counts
- **Resource-driven**: Specify what your pods need, get appropriate nodes
- **Cost optimization**: Pay only for nodes actually needed

**For Operations**:
- **Less configuration**: No node group sizing decisions
- **Better utilization**: Nodes sized for actual workloads
- **Automatic optimization**: AWS handles instance selection

**For Troubleshooting**:
- **Check pod requests**: If nodes aren't scaling, verify pod resource requests
- **Verify NodeClass**: Ensure security groups and subnets are correct
- **Monitor node lifecycle**: Nodes come and go based on demand

#### How It Works

1. **Pod Specification**: Application defines resource requirements
2. **Karpenter Analysis**: Reads pod requirements and node selectors
3. **Node Provisioning**: Creates matching EC2 instances on-demand
4. **Pod Scheduling**: Kubernetes schedules pods on appropriate nodes

#### Configuration Structure

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

#### Destructive Changes

| Change | Impact | Recommendation |
|--------|--------|----------------|
| `instance_type` | **Node replacement** | Plan maintenance window |
| `cpu_requests` | **Maybe new nodes** | Test in dev first |
| `memory_requests` | **Maybe new nodes** | Test in dev first |
| `replica_count` | **Pod scaling only** | Safe to change |

#### Node Lifecycle

**Terraform apply behavior**: 
```
Helm upgrade → Pod rescheduling → EKS Auto Mode creates new nodes → Old nodes drained
```

**Backup strategy**: 
```bash
kubectl get all -n unreal-cloud-ddc -o yaml > backup.yaml
```

### Instance Type Selection

#### NVMe Requirements

**Why NVMe**: DDC requires high-performance storage for cache operations

**Supported Instance Families**:
- `i4i.*` - Latest generation NVMe (recommended)
- `i3en.*` - Previous generation NVMe
- `i3.*` - Older generation NVMe

**Performance Characteristics**:
- **i4i.xlarge**: 4 vCPU, 32 GB RAM, 1x 937 GB NVMe SSD
- **i4i.2xlarge**: 8 vCPU, 64 GB RAM, 1x 1,875 GB NVMe SSD
- **i4i.4xlarge**: 16 vCPU, 128 GB RAM, 2x 1,875 GB NVMe SSD

## Dependency Management & Timing

### Resource Dependencies

#### Critical Path Analysis

```
EKS Cluster Creation (2-3 min)
├── Wait for Cluster Active (5-10 min)
├── Install CRDs (30 sec)
├── Deploy Infrastructure Charts (2-3 min)
│   ├── Fluent Bit (logging)
│   └── Cert Manager (SSL certificates)
├── Deploy DDC Application (3-5 min)
└── Create TargetGroupBinding (1-2 min)
```

#### Timing Optimizations

**Parallel Operations**:
- ScyllaDB deployment (parallel with EKS)
- S3 bucket creation (parallel with EKS)
- Security group creation (parallel with EKS)

**Sequential Operations**:
- CRD installation (requires active cluster)
- Helm deployments (requires CRDs)
- TargetGroupBinding (requires DDC service)

### Readiness Checks

#### kubectl wait Commands

```bash
# Wait for pods to be ready (containers started, health checks passing)
kubectl wait --for=condition=ready pod -l app=unreal-cloud-ddc --timeout=600s

# Wait for service endpoints (pods registered with service)
kubectl wait --for=jsonpath='{.subsets[0].addresses[0].ip}' endpoints/my-service --timeout=300s

# Wait for deployments to be ready (all replicas available)
kubectl wait --for=condition=available deployment/my-app --timeout=600s
```

#### Health Check Validation

**DDC Health Endpoint**:
```bash
curl -f -s "https://us-east-1.ddc.example.com/health" > /dev/null 2>&1
```

**Expected Response**: `HEALTHY`

## Helm Architecture

### Package Management for Kubernetes

**What is Helm**: Bundles multiple Kubernetes resources into reusable "charts"

**Comparisons**:
- **vs npm/package.json**: Helm charts are like npm packages, `values.yaml` is like package.json config
- **vs Docker Compose**: Compose defines containers, Helm defines K8s resources with templating
- **vs brew**: `helm install nginx` is like `brew install nginx` but for K8s clusters

### Chart Architecture

#### Epic's Official Chart

- **Location**: `oci://ghcr.io/epicgames/unreal-cloud-ddc`
- **Contains**: DDC application pods, services, config
- **Assumptions**: Standard K8s LoadBalancer service (creates AWS ELB)
- **Problem**: We use NLB created by Terraform, not K8s-managed ELB

#### Our Wrapper Chart

- **Location**: `./charts/ddc-wrapper`
- **Purpose**: Customize Epic's chart for our architecture
- **Contains**: Epic's chart as dependency + our overrides
- **Customizations**: 
  - ClusterIP service (instead of LoadBalancer)
  - Custom configuration for Terraform-managed NLB
  - EKS Auto Mode compatibility (hostPath fixes)

#### Our Infrastructure Chart

- **Location**: `./charts/ddc-infrastructure`
- **Purpose**: Just the TargetGroupBinding resource
- **Why Separate**: Different lifecycle than application

### Chart Dependency Management

#### How Epic's Chart Gets Downloaded

**Our Wrapper Chart Structure**:
```
ddc-wrapper/
├── Chart.yaml                    # Declares Epic's chart as dependency
├── templates/
│   └── deployment-override.yaml   # Our EKS Auto Mode fixes
└── charts/                        # Helm dependency storage (gitignored)
    └── unreal-cloud-ddc-1.2.0+helm.tgz  # Epic's chart (downloaded at runtime)
```

**Chart.yaml Dependency Declaration**:
```yaml
apiVersion: v2
name: ddc-wrapper
version: 1.0.0
description: A wrapper chart for Unreal Cloud DDC with EKS Auto Mode compatibility

dependencies:
  - name: unreal-cloud-ddc
    version: "1.2.0+helm"
    repository: "oci://ghcr.io/epicgames"
```

#### Dependency Download Flow

**During Terraform Apply**:
1. **Terraform local-exec runs**: `helm dependency update charts/ddc-wrapper`
2. **Helm reads Chart.yaml**: Sees Epic's chart as dependency
3. **Helm checks local cache**: Looks in `charts/ddc-wrapper/charts/` directory
4. **If missing, downloads**: Pulls `unreal-cloud-ddc-1.2.0+helm.tgz` from `oci://ghcr.io/epicgames`
5. **Stores locally**: Saves to `charts/ddc-wrapper/charts/unreal-cloud-ddc-1.2.0+helm.tgz`
6. **Helm combines charts**: Merges Epic's chart + our wrapper overrides
7. **Deploys to cluster**: Single combined deployment

**File Locations**:
```bash
# Epic's chart gets downloaded to:
modules/unreal/unreal-cloud-ddc/modules/ddc-app/charts/ddc-wrapper/charts/unreal-cloud-ddc-1.2.0+helm.tgz

# Size: ~31KB (small, safe to cache locally)
# Gitignored: Yes (prevents version conflicts)
# Self-healing: Missing files re-downloaded automatically
```

#### Why This Architecture Works

**Epic's Chart Provides**:
- Base DDC application deployment
- Container image references (`ghcr.io/epicgames/unreal-cloud-ddc:1.2.0`)
- Standard Kubernetes service definitions
- DDC configuration templates

**Our Wrapper Adds**:
- **EKS Auto Mode compatibility**: hostPath volume fixes for Bottlerocket OS
- **Terraform integration**: ClusterIP service instead of LoadBalancer
- **Custom configuration**: NLB integration via TargetGroupBinding
- **Regional customization**: Multi-region DNS and networking

**Benefits of Wrapper Pattern**:
- ✅ **Use Epic's official chart**: Get updates and support from Epic
- ✅ **Add our customizations**: EKS Auto Mode, Terraform integration
- ✅ **Version control**: Pin to stable Epic chart versions
- ✅ **Maintainable**: Clear separation between Epic's code and our overrides

### Container Images vs Helm Charts

**The Confusion**: Helm charts are NOT container images

**Helm Chart Structure**:
```
epic-ddc-chart/
├── Chart.yaml          # Chart metadata (name, version, dependencies)
├── values.yaml         # Default configuration values
├── templates/          # Kubernetes YAML templates
│   ├── deployment.yaml # References container image: ghcr.io/epicgames/ddc:1.2.0
│   ├── service.yaml    # Networking configuration
│   ├── configmap.yaml  # DDC application config
│   └── secret.yaml     # Authentication tokens
└── charts/             # Dependency charts (if any)
```

**What's in the Chart**:
- **Container image references**: Points to `ghcr.io/epicgames/ddc:1.2.0`
- **Kubernetes manifests**: Deployment, Service, ConfigMap templates
- **Configuration templates**: How to customize DDC settings
- **Dependencies**: Other charts this chart needs

**Real-world analogy**: Helm chart is like IKEA assembly instructions. Container image is like the actual wood pieces. You need both to build furniture.

### GHCR Authentication

**NOT Git Credentials** - Container Registry Credentials:
- **GitHub Personal Access Token** with `read:packages` permission
- **Same concept** as `docker login` to private registry
- **Required because**: Epic's DDC chart is in private GitHub Container Registry

```bash
# Similar to docker login
echo $GITHUB_TOKEN | docker login ghcr.io --username $GITHUB_USER --password-stdin

# Helm equivalent
echo $GITHUB_TOKEN | helm registry login ghcr.io --username $GITHUB_USER --password-stdin
```

### Chart Lifecycle

**Deployment Flow**:
1. **Initial deployment**: Pull chart from registry, deploy to cluster
2. **Configuration changes**: Re-run helm with new values (uses cached chart)
3. **Version upgrades**: Pull new chart version from registry
4. **Redeployments**: Use locally cached chart
5. **Rollbacks**: Use previously cached chart versions

## Troubleshooting

### Case Study: The Custom NodeClass Security Group Nightmare

**This was the most difficult issue we encountered with EKS Auto Mode + Terraform integration. Documenting the complete troubleshooting process to help future developers.**

#### The Problem

**Symptoms**:
- Built-in NodePools (c6a.large) worked perfectly
- Custom NodeClass instances (i4i.xlarge) launched but never joined cluster
- NodeClaims showed `Status: Ready, Reason: ReconcilingDependents` (stuck state)
- No Kubernetes nodes appeared despite EC2 instances running

#### The Investigation Process

**Step 1: NodeClaim Analysis**
```bash
# Check NodeClaim status
kubectl get nodeclaims -o custom-columns="NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason"

# Results showed:
# comprehensive-249t2     i4i.xlarge      Ready    ReconcilingDependents  # STUCK
# general-purpose-577m2   c6a.large       Ready    Ready                  # WORKING

# Detailed inspection:
kubectl describe nodeclaim comprehensive-249t2
# Key findings:
# ✅ Launched = True (EC2 instance created successfully)
# ❌ Registered = Unknown ("Node not registered with cluster")
# ❌ Provider ID: aws:///us-east-1c/i-066562cbad1dd4704
```

**Step 2: EC2 Console Output Investigation**
```bash
# Get the actual kubelet logs from EC2 console
aws ec2 get-console-output --instance-id i-066562cbad1dd4704 --latest --output text | tail -50

# SMOKING GUN - Networking component failures:
# [FAILED] Failed to start kube-proxy.
# [FAILED] Failed to start aws k8s agent IPAMD.
# [FAILED] Failed to start aws network policy agent.
#
# kubelet errors:
# "dial tcp 10.0.6.23:443: i/o timeout"
# "dial tcp 10.0.5.192:443: i/o timeout"
# "Unable to register node with API server"
```

**Step 3: Security Group Discovery**
```bash
# Check what security groups each instance type was using
aws ec2 describe-instances --instance-ids i-021e810daed731725 --query 'Reservations[].Instances[].SecurityGroups[].GroupId'  # Working c6a.large
# ["sg-017fe74d3b0cfa248"]  # EKS-managed security group

aws ec2 describe-instances --instance-ids i-066562cbad1dd4704 --query 'Reservations[].Instances[].SecurityGroups[].GroupId'  # Failing i4i.xlarge
# ["sg-0b1efa580994f854f"]  # Our custom security group
```

**Step 4: The Root Cause Revelation**
```bash
# Check EKS cluster security group configuration
aws eks describe-cluster --name cgd-unreal-cloud-ddc-cluster-us-east-1 --query 'cluster.resourcesVpcConfig.{SecurityGroupIds:securityGroupIds,ClusterSecurityGroupId:clusterSecurityGroupId}'
# {
#   "SecurityGroupIds": [],  # Empty - no additional security groups
#   "ClusterSecurityGroupId": "sg-017fe74d3b0cfa248"  # EKS-managed only
# }

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-017fe74d3b0cfa248  # EKS-managed
# Has self-referential rule: sg-017fe74d3b0cfa248 → sg-017fe74d3b0cfa248 ✅

aws ec2 describe-security-groups --group-ids sg-0b1efa580994f854f  # Our custom
# Has self-referential rule: sg-0b1efa580994f854f → sg-0b1efa580994f854f ✅
# BUT: No communication rules between the two security groups ❌
```

#### The Root Cause

**EKS cluster and custom NodeClass instances were using different security groups with no communication between them:**

- **EKS Control Plane**: EKS-managed security group `sg-017fe74d3b0cfa248`
- **Built-in NodePools**: Same EKS-managed security group (worked fine)
- **Custom NodeClass**: Our custom security group `sg-0b1efa580994f854f`
- **Problem**: kubelet on custom instances couldn't reach EKS API server endpoints

#### Failed Solutions We Tried

**❌ Attempt 1: Add VPC CIDR ingress rule**
```hcl
# This didn't work - wrong direction (ingress vs egress)
resource "aws_vpc_security_group_ingress_rule" "cluster_vpc_ingress" {
  security_group_id = aws_security_group.cluster_security_group.id
  ip_protocol       = "-1"
  cidr_ipv4         = data.aws_vpc.main.cidr_block
}
```

**❌ Attempt 2: Cross-security group rules**
```hcl
# This failed due to circular dependency - can't reference EKS-managed SG in Terraform
resource "aws_vpc_security_group_ingress_rule" "custom_from_eks_managed" {
  security_group_id            = aws_security_group.cluster_security_group.id
  referenced_security_group_id = "sg-017fe74d3b0cfa248"  # Hardcoded - terrible!
}
```

**❌ Attempt 3: Use EKS-managed SG in NodeClass**
```hcl
# This failed due to circular dependency - can't reference cluster SG during creation
securityGroupSelectorTerms:
  - id: ${aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id}
```

#### The Working Solution

**✅ Force both EKS cluster and NodeClass to use the same custom security group:**

```hcl
# 1. EKS cluster uses our custom security group
resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  vpc_config {
    security_group_ids = [aws_security_group.cluster_security_group.id]  # CRITICAL FIX
  }
}

# 2. NodeClass also uses our custom security group (already was)
securityGroupSelectorTerms:
  - id: ${aws_security_group.cluster_security_group.id}

# 3. Self-referential rule allows all communication within the security group
resource "aws_vpc_security_group_ingress_rule" "cluster_self" {
  security_group_id            = aws_security_group.cluster_security_group.id
  referenced_security_group_id = aws_security_group.cluster_security_group.id
  ip_protocol                  = "-1"  # All traffic
}
```

#### The Result

**Before Fix**:
```bash
kubectl get nodes
# NAME                  STATUS   ROLES    AGE   VERSION
# i-021e810daed731725   Ready    <none>   88m   v1.33.4-eks-e386d34  # c6a.large only
# i-0f736bf750de0678d   Ready    <none>   88m   v1.33.4-eks-e386d34  # c6a.large only
```

**After Fix**:
```bash
kubectl get nodes -o custom-columns="NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,AGE:.metadata.creationTimestamp"
# NAME                  INSTANCE-TYPE   AGE
# i-01c43c95c3f6d3b21   i4i.xlarge      2025-11-08T09:04:22Z  ✅
# i-08b7332d8ec20d149   i4i.xlarge      2025-11-08T09:04:10Z  ✅
# i-096c7a1167de3d05a   i4i.xlarge      2025-11-08T09:07:05Z  ✅
# i-0a08ec163ab1f7985   i4i.xlarge      2025-11-08T09:07:02Z  ✅
```

#### Key Lessons Learned

**For Troubleshooting**:
1. **Check EC2 console output** - kubelet logs show the real networking errors
2. **Compare working vs failing instances** - security group differences are critical
3. **Don't assume "auto" means "compatible"** - EKS Auto Mode has hidden complexity
4. **Test custom NodeClass early** - don't wait until full deployment to discover issues

**For EKS Auto Mode + Terraform**:
1. **Force consistent security groups** - don't let EKS and Terraform manage different ones
2. **Self-referential rules are critical** - all cluster components need to communicate
3. **Avoid circular dependencies** - can't reference EKS-managed resources in Terraform
4. **Document workarounds thoroughly** - this will happen to others

**For Future Architecture Decisions**:
1. **Consider traditional EKS** - managed node groups avoid these issues
2. **Test integration complexity early** - "simplified" services often push complexity elsewhere
3. **Plan for troubleshooting** - complex integrations need comprehensive debugging procedures
4. **Evaluate trade-offs honestly** - convenience vs control has real implications

#### Prevention Checklist

**Before Using Custom NodeClass**:
- ✅ Ensure EKS cluster uses Terraform-managed security groups
- ✅ Verify NodeClass references the same security group as cluster
- ✅ Test with simple workload before complex applications
- ✅ Have troubleshooting procedures documented
- ✅ Consider if traditional managed node groups would be simpler

**Red Flags to Watch For**:
- ❌ NodeClaims stuck in "ReconcilingDependents" state
- ❌ EC2 instances launched but no Kubernetes nodes
- ❌ kubelet timeout errors in console output
- ❌ Different security groups between cluster and nodes
- ❌ Networking component startup failures

**This issue cost us hours of debugging and represents the hidden complexity of EKS Auto Mode when integrated with Terraform for enterprise networking requirements.**

### Common Issues

#### 1. TargetGroupBinding Not Ready

**Symptoms**: TargetGroupBinding shows `Ready=False`, DDC service unreachable

**Diagnosis**:
```bash
kubectl describe targetgroupbinding <name-prefix>-tgb -n <namespace>
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Common Causes**:
- "Target not in subnet associated with target group" → Check subnet alignment
- "Security group rules" → Verify security group allows traffic
- "Pod not ready" → Check pod status with `kubectl get pods`

#### 2. Service Account Missing IAM Role (Auto-Recovery)

**Symptoms**:
- DDC pods crash with `CrashLoopBackOff` status
- Error: `webIdentityTokenFile must be an absolute path`
- AWS authentication failures in pod logs
- Pods can't access S3 or other AWS services

**Root Cause**: Service account missing `eks.amazonaws.com/role-arn` annotation required for IRSA (IAM Roles for Service Accounts)

**Technical Details**:
- DDC uses IRSA to authenticate with AWS services (S3, etc.)
- Without the IAM role annotation, Kubernetes doesn't mount the AWS token file
- DDC application fails to start because it can't authenticate with AWS

**Diagnosis**:
```bash
# Check service account annotations
kubectl get serviceaccount unreal-cloud-ddc-sa -n unreal-cloud-ddc -o jsonpath='{.metadata.annotations}' | jq .

# Expected: Should include eks.amazonaws.com/role-arn
{
  "eks.amazonaws.com/role-arn": "arn:aws:iam::ACCOUNT:role/cgd-unreal-cloud-ddc-sa-role-xxxxx"
}

# Check pod logs for AWS auth errors
kubectl logs <pod-name> -n unreal-cloud-ddc -c unreal-cloud-ddc --tail=20
```

**Expected vs Actual**:
```bash
# ❌ Missing IAM role annotation (causes crashes)
{
  "meta.helm.sh/release-name": "cgd-unreal-cloud-ddc-initialize",
  "meta.helm.sh/release-namespace": "unreal-cloud-ddc"
}

# ✅ Correct service account with IAM role
{
  "eks.amazonaws.com/role-arn": "arn:aws:iam::ACCOUNT:role/cgd-unreal-cloud-ddc-sa-role-xxxxx",
  "meta.helm.sh/release-name": "cgd-unreal-cloud-ddc-initialize",
  "meta.helm.sh/release-namespace": "unreal-cloud-ddc"
}
```

**Automatic Recovery**:
The module includes intelligent self-healing logic:
1. **Detects crashing pods** (`CrashLoopBackOff`, `Error`, `CreateContainerError`)
2. **Only restarts deployments when broken** - healthy pods are left alone
3. **Forces rolling update** to pick up correct service account configuration
4. **Waits for new pods** to be ready with proper AWS authentication

**Manual Recovery (if needed)**:
```bash
# Force deployment restart to pick up service account changes
kubectl rollout restart deployment -l app.kubernetes.io/name=unreal-cloud-ddc -n unreal-cloud-ddc

# Wait for rollout to complete
kubectl rollout status deployment -l app.kubernetes.io/name=unreal-cloud-ddc -n unreal-cloud-ddc
```

**Prevention & Self-Healing**:
- Module automatically ensures service account has IAM role annotation
- Self-healing logic only intervenes when pods are actually broken
- Healthy deployments are never disrupted by `terraform apply`
- Future applies show "No changes" when system is healthy
- **Critical**: This issue should never happen again due to automatic recovery

**Historical Context**:
This was a major issue that caused DDC deployments to fail with AWS authentication errors. The module now includes comprehensive self-healing logic that:
- Automatically detects and fixes stuck Helm releases
- Only restarts deployments when pods are actually crashing
- Preserves healthy deployments during routine `terraform apply` operations
- Eliminates the need for manual intervention in most cases

#### 3. Pod Crashes with Configuration Errors

**Symptoms**: `CrashLoopBackOff`, logs show configuration parsing errors

**Diagnosis**:
```bash
kubectl logs -f <pod-name> -n unreal-cloud-ddc
kubectl describe pod <pod-name> -n unreal-cloud-ddc
```

**Common Causes**:
- DDC version 1.3.0 configuration parsing bugs
- Invalid keyspace configuration
- Database connection failures

#### 4. Stuck Helm Releases (Auto-Recovery)

**Symptoms**:
- `terraform apply` hangs during Helm installation
- Helm release stuck in `pending-upgrade` or `pending-install` state
- DDC pods crash but new deployments don't fix the issue

**Root Cause**: Helm upgrade process interrupted, leaving release in incomplete state

**Automatic Recovery**:
The module now includes automatic recovery logic that:
1. **Detects stuck releases** before attempting installation
2. **Automatically cleans up** stuck releases with `helm delete`
3. **Proceeds with fresh installation** after cleanup

**Manual Recovery (if needed)**:
```bash
# Check Helm release status
helm status cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc

# If stuck in pending state, delete and retry
helm delete cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc
terraform apply -auto-approve
```

**Prevention**:
- The module automatically handles this scenario
- No manual intervention required for stuck releases
- `terraform apply` is now self-healing for Helm issues

#### 5. GitHub Container Registry Access Denied

**Symptoms**: Pod image pull failures, `ImagePullBackOff` status

**Solutions**:
1. **Verify Epic Games organization membership**
2. **Check GitHub PAT has `packages:read` permission**
3. **Confirm secret format**:
   ```bash
   aws secretsmanager describe-secret --secret-id "github-ddc-credentials"
   ```

#### 6. DNS Resolution Issues

**Symptoms**: `curl` commands timeout or return connection refused

**Diagnosis**:
```bash
# Check your current IP
curl https://checkip.amazonaws.com/

# Verify DNS resolution
nslookup us-east-1.ddc.dev.yourcompany.com

# Check security group allows your IP
# Verify this IP is in your allowed_external_cidrs
```

### Debug Commands

#### Network Diagnostics
```bash
# Get current IP
curl https://checkip.amazonaws.com/

# Test DNS resolution
nslookup us-east-1.ddc.dev.yourcompany.com

# Test connectivity
curl -v https://us-east-1.ddc.dev.yourcompany.com/health
```

#### Kubernetes Diagnostics
```bash
# Configure kubectl access (REQUIRED first step)
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check cluster status
kubectl get nodes
kubectl cluster-info

# Check application status
kubectl get pods -n unreal-cloud-ddc
kubectl get svc -n unreal-cloud-ddc
kubectl get targetgroupbindings -n unreal-cloud-ddc

# Check logs
kubectl logs -f <pod-name> -n unreal-cloud-ddc
kubectl describe pod <pod-name> -n unreal-cloud-ddc
```

#### AWS Resource Diagnostics
```bash
# Check VPC resources
aws ec2 describe-vpcs --vpc-ids <vpc-id>
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<vpc-id>"

# Check load balancer status
aws elbv2 describe-load-balancers --names <nlb-name>
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

### Prevention Checklist

**Before Deploying**:
- ✅ Using custom VPC (not default VPC)
- ✅ Using custom route tables (not default route tables)
- ✅ Following example patterns exactly
- ✅ GitHub PAT has correct permissions
- ✅ Secret contains username and accessToken fields
- ✅ Route53 hosted zone exists
- ✅ Certificate ARN is valid

**After Deploying**:
- ✅ All pods are running
- ✅ DNS resolves correctly
- ✅ API endpoints respond
- ✅ Health checks pass

**Before Destroying**:
- ✅ In correct directory with terraform.tfstate
- ✅ No critical data needs backup
- ✅ Destroy plan looks reasonable

### Emergency Procedures

#### If Terraform Destroy Hangs

**Common Issue**: Internet Gateway deletion hangs due to ENI dependencies

**Solution**:
```bash
# Manual cleanup if destroy is stuck
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl delete targetgroupbinding --all -n <namespace> --ignore-not-found=true

# Wait for ENIs to be released, then retry destroy
terraform destroy
```

#### If State Corruption Occurs

1. **Stop all operations**: Don't run more Terraform commands
2. **Backup current state**: `cp terraform.tfstate terraform.tfstate.backup`
3. **Manual state recovery**: Use `terraform state mv` commands
4. **Import missing resources**: Use `terraform import` if needed
5. **Verify with plan**: Ensure `terraform plan` shows expected changes

## Architecture Decisions

### Why local-exec Instead of Providers?

**The Problem**: Terraform providers initialize before resources exist, making Helm provider incompatible with single-apply EKS deployments.

**Our Solution**: Use `null_resource` with `local-exec` provisioners running Helm CLI commands.

**Benefits**:
- ✅ **Single terraform apply** - No complex workflows
- ✅ **Same commands as CI/CD** - Uses identical Helm CLI commands
- ✅ **Transparent debugging** - Can run commands manually
- ✅ **No provider timing issues** - Commands run when resources exist

**Trade-offs**:
- ❌ **Less type-safe** - Shell commands vs HCL blocks
- ❌ **Platform dependent** - Requires bash/shell environment
- ✅ **Production proven** - Widely used in enterprise environments

### DDC Application Architecture: Kestrel vs NGINX

#### Epic's Default Architecture

**Epic's Standard Setup**:
```
Internet → NodePort Service → NGINX Reverse Proxy (port 81) → Kestrel Web Server (port 5000)
```

**Components**:
- **NGINX**: Mature reverse proxy with SSL termination, caching, load balancing
- **Kestrel**: ASP.NET Core's built-in web server (C# native)
- **NodePort**: Exposes service on every node IP (bypasses load balancer)

#### Our Optimized Architecture

**CGD Toolkit Setup**:
```
Internet → NLB (443/80) → TargetGroupBinding → ClusterIP Service → Kestrel Web Server (port 80)
```

**Key Changes**:
- **Direct Kestrel**: Bypass NGINX reverse proxy entirely
- **Standard Port 80**: Use HTTP standard port instead of Epic's port 81
- **ClusterIP + NLB**: Controlled traffic flow through Terraform-managed NLB
- **TargetGroupBinding**: Connect Kubernetes service to AWS target group

#### Why We Bypass NGINX

**Performance Benefits**:
- **Lower Latency**: One less network hop (NGINX → Kestrel eliminated)
- **Reduced Resource Usage**: Fewer containers per pod (no NGINX sidecar)
- **Simpler Networking**: Direct connection to application server

**Operational Benefits**:
- **Fewer Moving Parts**: Less complexity in troubleshooting
- **Standard Ports**: Port 80 expected by NLB health checks
- **Cleaner Architecture**: Single-purpose containers

**When NGINX is Still Useful**:
- **SSL Termination**: We handle this at NLB level instead
- **Caching**: DDC has its own caching layer (S3 + local NVMe)
- **Load Balancing**: We handle this at AWS NLB level instead
- **Request Routing**: DDC is single-purpose application

#### Kestrel Web Server Explained

**What is Kestrel**:
- **Built-in**: Comes with ASP.NET Core applications
- **High Performance**: Optimized for .NET applications
- **Cross-Platform**: Runs on Linux containers in Kubernetes
- **Production Ready**: Used by Microsoft for high-scale applications

**Kestrel vs NGINX Comparison**:

| Aspect | Kestrel | NGINX |
|--------|---------|-------|
| **Purpose** | Application web server | Reverse proxy |
| **Language** | C# (.NET Core) | C |
| **Performance** | High for .NET apps | High for general use |
| **Features** | HTTP/HTTPS, WebSockets | SSL, caching, load balancing |
| **Resource Usage** | Lower (single process) | Higher (separate process) |
| **Configuration** | Code-based | Config files |
| **DDC Integration** | Native (same process) | External (separate container) |

#### Configuration Details

**Environment Variables**:
```yaml
env:
  - name: ASPNETCORE_URLS
    value: "http://0.0.0.0:80"  # Primary: Configure Kestrel to listen on port 80
  - name: Kestrel__Endpoints__Http__Url  
    value: "http://0.0.0.0:80"  # Backup: Additional Kestrel endpoint override
```

**Why Two Variables**:
- **ASPNETCORE_URLS**: ASP.NET Core standard environment variable
- **Kestrel__Endpoints__Http__Url**: Kestrel-specific configuration override
- **Redundancy**: Ensures port 80 configuration regardless of Epic's defaults

**Service Configuration**:
```yaml
service:
  type: ClusterIP          # Internal service only
  port: 80                 # Service port (what TargetGroupBinding references)
  targetPort: http         # Container port name (resolves to port 80)
```

**NGINX Disabled**:
```yaml
nginx:
  enabled: false           # Disable NGINX reverse proxy entirely
  useDomainSockets: false  # Disable NGINX-Kestrel domain socket optimization
```

#### Networking Flow Comparison

**Epic's Default Flow**:
```
Game Client
├── DNS: us-east-1.ddc.example.com
├── NodePort Service (random port on every node)
├── NGINX Container (port 81)
├── Domain Socket or HTTP
└── Kestrel Container (port 5000)
```

**Our Optimized Flow**:
```
Game Client
├── DNS: us-east-1.ddc.example.com
├── NLB (port 443 HTTPS, port 80 HTTP)
├── TargetGroupBinding (connects NLB to K8s)
├── ClusterIP Service (port 80)
└── Kestrel Container (port 80)
```

#### Benefits for Game Development

**Lower Latency**:
- **Fewer Hops**: Direct connection to application server
- **No Proxy Overhead**: Eliminates NGINX processing time
- **Optimized Path**: Straight from load balancer to application

**Better Resource Utilization**:
- **Single Container**: No NGINX sidecar consuming CPU/memory
- **More DDC Capacity**: Resources go to actual DDC processing
- **Simpler Scaling**: Scale application containers, not proxy containers

**Operational Simplicity**:
- **Fewer Logs**: Only application logs, no proxy logs
- **Simpler Debugging**: Direct connection for troubleshooting
- **Standard Ports**: Port 80/443 as expected by tools and monitoring

#### When You Might Want NGINX Back

**Complex Routing Needs**:
- Multiple applications behind same domain
- Path-based routing requirements
- Custom header manipulation

**Advanced Caching**:
- HTTP response caching (DDC has its own S3/NVMe caching)
- Static asset serving (DDC serves dynamic content)

**Custom SSL Requirements**:
- Client certificate authentication
- Custom SSL configurations (we use AWS NLB SSL termination)

**How to Re-enable NGINX** (if needed):
```yaml
nginx:
  enabled: true            # Re-enable NGINX reverse proxy
  useDomainSockets: true   # Enable NGINX-Kestrel optimization

service:
  targetPort: nginx-http   # Point to NGINX instead of Kestrel

env:
  # Remove ASPNETCORE_URLS overrides to use Epic's defaults
```

**Summary**: Our architecture optimizes for DDC's specific use case (high-performance binary asset serving) by eliminating unnecessary proxy layers and using standard networking patterns that integrate well with AWS load balancers.

## Kubernetes Resource Naming

### Clear Resource Identification

The module uses a consistent naming pattern that makes it easy to identify resource types and purposes in kubectl commands.

**Naming Structure**:
```
Helm Release: {name_prefix}-app           # DDC application deployment
Service:      {name_prefix}               # DDC service endpoint  
Deployment:   {name_prefix}               # DDC server deployment
Worker:       {name_prefix}-worker        # DDC worker deployment
Pods:         {name_prefix}-xxxxx         # DDC server pods
Worker Pods:  {name_prefix}-worker-xxxxx  # DDC worker pods
```

**Example with `name_prefix = "cgd-unreal-cloud-ddc"`**:
```bash
# Clear kubectl commands
kubectl get service cgd-unreal-cloud-ddc              # DDC service
kubectl get deployment cgd-unreal-cloud-ddc           # DDC server deployment
kubectl get deployment cgd-unreal-cloud-ddc-worker    # DDC worker deployment
kubectl logs deployment/cgd-unreal-cloud-ddc          # DDC server logs
kubectl logs deployment/cgd-unreal-cloud-ddc-worker   # DDC worker logs

# Helm release management
helm list -n unreal-cloud-ddc                         # Shows: cgd-unreal-cloud-ddc-app
helm status cgd-unreal-cloud-ddc-app -n unreal-cloud-ddc
```

**Resource Purpose Identification**:
- **No suffix**: Main DDC service and server deployment
- **`-worker`**: Background maintenance tasks (garbage collection, replication)
- **`-app`**: Helm release identifier (deployment management)

**Benefits**:
- ✅ **Clear identification**: Easy to distinguish between service, server, and worker resources
- ✅ **Tab completion**: Predictable names work well with kubectl tab completion
- ✅ **No confusion**: Impossible to mistake which resource you're operating on
- ✅ **Standard pattern**: Follows Kubernetes naming conventions

**Key Point**: Helm release names and Kubernetes resource names are completely separate. The module uses `fullnameOverride` to ensure clean, predictable Kubernetes resource names regardless of the Helm release name.

## EKS Auto Mode and Terraform Integration Challenges

### The Reality of EKS Auto Mode with Terraform

**EKS Auto Mode was designed for console/CLI deployments, not infrastructure-as-code.** While AWS markets it as "simplified Kubernetes," it creates significant complexity when using Terraform for enterprise infrastructure management.

#### Core Problem: Hidden Complexity

**AWS Marketing**: "EKS Auto Mode eliminates node management complexity"
**Reality**: "EKS Auto Mode eliminates YOUR control over node management"

**What AWS Doesn't Tell You**:
- Auto-managed security groups you can't reference in Terraform
- Hidden networking dependencies that break custom integrations
- Limited customization options for enterprise requirements
- Complex troubleshooting when "auto" doesn't work

#### Specific Terraform Integration Issues

**Issue 1: Security Group Management**

**The Problem**: EKS Auto Mode creates its own security groups that Terraform cannot reference or manage.

```hcl
# ❌ This doesn't work - can't reference auto-created security groups
resource "aws_security_group_rule" "nlb_to_nodes" {
  security_group_id        = "???"  # EKS-managed SG not accessible
  source_security_group_id = aws_security_group.nlb.id
}
```

**Our Workaround**: Force EKS cluster to use Terraform-managed security groups
```hcl
# ✅ This works - we control the security group
resource "aws_eks_cluster" "cluster" {
  vpc_config {
    security_group_ids = [aws_security_group.cluster_security_group.id]
  }
}
```

**Issue 2: NodeClass Security Group References**

**The Problem**: Custom NodeClass instances couldn't communicate with EKS control plane because they used different security groups.

**Symptoms We Experienced**:
- Built-in NodePools (c6a.large) worked fine
- Custom NodeClass (i4i.xlarge) instances launched but never joined cluster
- kubelet logs showed: `dial tcp 10.0.6.23:443: i/o timeout`
- Networking components failed: `[FAILED] Failed to start kube-proxy`

**Root Cause**: 
- EKS cluster used auto-managed security group `sg-017fe74d3b0cfa248`
- Custom NodeClass used our custom security group `sg-0b1efa580994f854f`
- No communication rules between the two security groups

**Our Solution**: Make both use the same security group
```hcl
# Force EKS cluster to use our custom security group
vpc_config {
  security_group_ids = [aws_security_group.cluster_security_group.id]
}

# NodeClass also uses our custom security group
securityGroupSelectorTerms:
  - id: ${aws_security_group.cluster_security_group.id}
```

**Issue 3: NLB Integration Complexity**

**Standard Kubernetes Approach** (doesn't work with Terraform):
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer  # Creates AWS NLB automatically
```

**Problems**:
- Terraform can't manage controller-created load balancers
- No control over security groups, DNS, SSL certificates
- Destroy operations fail due to resource dependencies
- Can't integrate with existing Terraform networking

**Our Complex Workaround**:
1. Create NLB in Terraform with custom security groups
2. Create TargetGroupBinding to connect Kubernetes service to Terraform NLB
3. Ensure security group rules allow NLB → Pod communication
4. Handle cleanup order during destroy operations

#### When EKS Auto Mode Works Well

**✅ Great for**:
- Console-based deployments
- Simple applications with standard requirements
- Getting started with Kubernetes
- Teams without infrastructure-as-code requirements

**✅ Use Cases**:
- Development environments
- Proof-of-concept deployments
- Standard web applications
- Teams comfortable with manual configuration

#### When EKS Auto Mode Causes Problems

**❌ Problematic for**:
- Terraform infrastructure-as-code
- Custom networking requirements (like our NLB integration)
- Enterprise security requirements
- Multi-service integration
- Predictable resource management

**❌ Specific Issues We Encountered**:
- **Security group conflicts**: Auto-managed vs Terraform-managed
- **Network Load Balancer integration**: Required complex workarounds
- **Troubleshooting complexity**: "Auto" behavior is opaque
- **Resource lifecycle management**: Terraform can't manage auto-created resources
- **Enterprise networking**: Doesn't integrate well with existing VPC patterns

#### Alternative: Traditional EKS with Managed Node Groups

**What we could have used instead**:
```hcl
resource "aws_eks_node_group" "ddc_nodes" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "ddc-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["i4i.xlarge"]
  
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 1
  }
  
  # Full Terraform control
  remote_access {
    ec2_ssh_key = var.key_pair_name
  }
}
```

**Benefits of Traditional Approach**:
- ✅ **Full Terraform control**: All resources managed by Terraform
- ✅ **Predictable networking**: Standard security group patterns
- ✅ **Clear troubleshooting**: No hidden "auto" behavior
- ✅ **Enterprise integration**: Works with existing infrastructure patterns
- ✅ **Simpler NLB integration**: Standard AWS networking patterns

**Why We Didn't Use It**:
- **Manual scaling**: Need to configure Auto Scaling Groups
- **Instance management**: Need to handle AMI updates, node lifecycle
- **More configuration**: More Terraform resources to manage

#### Lessons Learned

**For Future Projects**:

1. **Evaluate "Auto" Solutions Carefully**: "Auto" often means "less control"
2. **Test Integration Early**: Don't assume AWS services integrate well with Terraform
3. **Plan for Complexity**: "Simplified" services often push complexity elsewhere
4. **Consider Traditional Approaches**: Sometimes more configuration = more control
5. **Document Workarounds**: Complex integrations need comprehensive documentation

**For Teams Considering EKS Auto Mode**:

**Choose EKS Auto Mode if**:
- Using AWS Console or CLI for deployments
- Standard application requirements
- Comfortable with less infrastructure control
- Small team with simple networking needs

**Choose Traditional EKS if**:
- Using Terraform for infrastructure-as-code
- Custom networking requirements
- Enterprise security and compliance needs
- Need predictable resource management
- Integration with existing infrastructure

#### The Bottom Line

**EKS Auto Mode is not inherently bad** - it's designed for a specific use case (console-based, simple deployments). The problem is that AWS marketing doesn't clearly communicate the trade-offs.

**For CGD Toolkit**: We made EKS Auto Mode work, but it required significant engineering effort to overcome integration challenges. The complexity we eliminated in node management was transferred to security group management, networking integration, and troubleshooting.

**Recommendation**: For future infrastructure-as-code projects requiring custom networking, consider traditional EKS with managed node groups. The additional configuration overhead is often worth the predictable behavior and full Terraform control.

**Key Takeaway**: "Simplified" cloud services often mean "simplified for specific use cases." Always evaluate whether your use case matches the service's design assumptions.

## Quick Reference

> **Note**: Replace placeholders with your actual values:
> - `<region>` = Your AWS region (e.g., us-east-1)
> - `<cluster-name>` = Your EKS cluster name (typically `{project_prefix}-unreal-cloud-ddc-cluster-{region}`)
> - `<namespace>` = Your Kubernetes namespace (default: `unreal-cloud-ddc`)
> - `<name-prefix>` = Your resource prefix (typically `{project_prefix}-unreal-cloud-ddc`)

### Critical Commands

**EKS Access Setup** (ALWAYS FIRST):
```bash
# Configure kubectl access - REQUIRED before any kubectl commands
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

**Health Check Commands**:
```bash
# Check DDC service health
curl <DDC_ENDPOINT>/health/live
# Expected: "HEALTHY"

# Check pod status
kubectl get pods -n <namespace>
# Expected: All pods "Running"

# Check service and deployments (using clean naming)
kubectl get service <name-prefix> -n <namespace>              # DDC service
kubectl get deployment <name-prefix> -n <namespace>           # DDC server
kubectl get deployment <name-prefix>-worker -n <namespace>    # DDC worker

# Check TargetGroupBinding
kubectl describe targetgroupbinding <name-prefix>-tgb -n <namespace>
# Expected: Status: Ready=True
```

**Debug Commands**:
```bash
# Get current IP (for security group troubleshooting)
curl https://checkip.amazonaws.com/

# Check DNS resolution
nslookup <region>.ddc.<domain>

# View pod logs
kubectl logs -f <pod-name> -n <namespace>

# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Known Issues & Solutions

#### Issue: TargetGroupBinding Not Ready
**Symptoms**: `Ready=False`, DDC service unreachable
**Root Cause**: AWS Load Balancer Controller cannot bind pods to target group
**Solution**:
```bash
kubectl describe targetgroupbinding <name-prefix>-tgb -n <namespace>
kubectl logs -n kube-system deployment/aws-load-balancer-controller
# Common fixes: Check subnet alignment, security group rules, pod readiness
```

#### Issue: Service Account Missing IAM Role (Auto-Recovery)
**Symptoms**: `CrashLoopBackOff`, `webIdentityTokenFile must be an absolute path`
**Root Cause**: Service account missing `eks.amazonaws.com/role-arn` annotation
**Solution**: Module has auto-recovery - `terraform apply` will fix automatically
**Manual Fix**:
```bash
kubectl rollout restart deployment -l app.kubernetes.io/name=unreal-cloud-ddc -n <namespace>
```

#### Issue: Stuck Helm Releases (Auto-Recovery)
**Symptoms**: `terraform apply` hangs, release in `pending-upgrade` state
**Root Cause**: Helm upgrade process interrupted
**Solution**: Module has auto-recovery - detects and cleans up stuck releases
**Manual Fix**:
```bash
helm delete <release-name> -n <namespace>
terraform apply -auto-approve
```

#### Issue: GitHub Container Registry Access Denied
**Symptoms**: `ImagePullBackOff`, container image pull failures
**Root Cause**: Missing Epic Games organization access or invalid GitHub PAT
**Solution**:
1. Verify Epic Games GitHub organization membership
2. Check GitHub PAT has `packages:read` permission
3. Confirm secret format in AWS Secrets Manager

#### Issue: Terraform Destroy Hangs on IGW
**Symptoms**: `aws_internet_gateway.igw: Still destroying... [20m00s elapsed]`
**Root Cause**: Using default route tables or improper networking setup
**Emergency Fix**:
```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl delete targetgroupbinding --all -n <namespace> --ignore-not-found=true
# Wait for ENIs to be released, then retry destroy
terraform destroy
```

#### Issue: DNS Resolution Failures
**Symptoms**: `curl` commands timeout, connection refused
**Root Cause**: IP not in security group allowlist or DNS misconfiguration
**Solution**:
```bash
# Check your current IP
curl https://checkip.amazonaws.com/
# Verify this IP is in your allowed_external_cidrs

# Test DNS resolution
nslookup <region>.ddc.<domain>

# Test connectivity
curl -v https://<region>.ddc.<domain>/health
```

### Emergency Procedures

**If Deployment Fails**:
1. Check pod status: `kubectl get pods -n <namespace>`
2. Check logs: `kubectl logs -f <pod-name> -n <namespace>`
3. Check TargetGroupBinding: `kubectl describe targetgroupbinding -n <namespace>`
4. Re-run: `terraform apply -auto-approve` (module has auto-recovery)

**If Destroy Hangs**:
1. Clean up TargetGroupBinding: `kubectl delete targetgroupbinding --all -n <namespace>`
2. Wait 2-3 minutes for ENI cleanup
3. Retry: `terraform destroy`

**If State Corruption**:
1. Backup state: `cp terraform.tfstate terraform.tfstate.backup`
2. Manual recovery: Use `terraform state mv` and `terraform import`
3. Verify: `terraform plan` should show expected changes

### Critical Configuration Notes

**⚠️ NEVER Use Default VPC/Subnets**: Always use custom networking resources to avoid destroy failures

**⚠️ DDC Namespaces ≠ Kubernetes Namespaces**: 
- DDC logical namespaces = URL paths (`/api/v1/refs/<ddc_namespace>/`)
- Kubernetes namespace = Infrastructure container (default: `unreal-cloud-ddc`)

**⚠️ S3 Bucket Risk**: All DDC logical namespaces share same S3 bucket - enable replication for multi-title deployments

**⚠️ NVMe Recommended**: DDC works on general-purpose instances but NVMe provides optimal cache performance

### Why Both kubernetes and kubectl Providers?

**Strategic Usage**:
- **kubernetes provider**: Standard Kubernetes resources (services, deployments, etc.)
- **kubectl provider**: TargetGroupBinding CRD only

**Technical Reason**: The `kubectl` provider enables single-apply deployment by deferring cluster API validation until apply phase.

**Note**: In our current implementation, we've moved away from both providers in favor of `null_resource` with `local-exec` for better reliability and single-apply compatibility.

### Control Our Own Networking

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

This architectural approach provides the best balance of functionality, reliability, and operational simplicity for enterprise Kubernetes deployments on AWS.

**Remember**: The choice between Terraform and GitOps for application management depends on your team size, change frequency, and operational requirements. Both approaches have trade-offs in terms of flexibility vs governance.

#### Pod Scheduling: How Pods Choose Nodes

**The Question**: "How do you say which pods run on which node groups?"
**The Answer**: Through **nodeSelector**, **tolerations**, and **resource requests** in your Helm charts.

**Method 1: nodeSelector** (Most Common):
```yaml
# In Helm chart values or templates
nodeSelector:
  node.kubernetes.io/instance-type: "i4i.xlarge"  # Only i4i.xlarge nodes
  # OR
  eks.amazonaws.com/instance-category: "i"         # Any NVMe instance family
  # OR
  karpenter.sh/capacity-type: "spot"              # Only spot instances
```

**Method 2: Resource Requests** (Automatic Matching):
```yaml
# Karpenter reads these and creates appropriate nodes
resources:
  requests:
    cpu: "8000m"        # Needs 8 CPU cores → triggers larger instance
    memory: "32Gi"      # Needs 32GB RAM → triggers memory-optimized instance
    ephemeral-storage: "100Gi"  # Needs local storage → triggers NVMe instance
```

**Method 3: Tolerations** (For Specialized Nodes):
```yaml
# For nodes with taints (advanced use case)
tolerations:
- key: "nvidia.com/gpu"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

#### Real-World Example: DDC Pod Scheduling

**Our DDC Configuration** (in ddc-app Helm chart):
```yaml
# This is what we configure in Terraform:
ddc_application_config = {
  compute = {
    instance_type = "i4i.xlarge"     # Preferred instance type
    cpu_requests = "2000m"           # 2 CPU cores per pod
    memory_requests = "8Gi"          # 8GB RAM per pod
    replica_count = 2                # 2 DDC pods
  }
}
```

**How This Becomes Kubernetes Configuration**:
```yaml
# Generated in Helm template:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unreal-cloud-ddc
spec:
  replicas: 2  # From replica_count
  template:
    spec:
      nodeSelector:
        node.kubernetes.io/instance-type: "i4i.xlarge"  # From instance_type
      containers:
      - name: ddc
        resources:
          requests:
            cpu: "2000m"    # From cpu_requests
            memory: "8Gi"   # From memory_requests
```

**What Happens When Pod is Created**:
1. **Kubernetes scheduler**: "I need to place a pod with these requirements"
2. **Karpenter analysis**: "No existing nodes match these requirements"
3. **Node provisioning**: "Create i4i.xlarge instance with NVMe storage"
4. **Pod scheduling**: "Place pod on the new node"
5. **Result**: Pod runs on exactly the type of node it requested

#### Multiple NodePools: When and Why

**Single NodePool** (Our Current Approach):
```yaml
# One NodePool handles all workload types
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: comprehensive
spec:
  template:
    spec:
      requirements:
        - key: eks.amazonaws.com/instance-category
          operator: In
          values: ["i", "m", "c"]  # NVMe, general-purpose, compute-optimized
```
- **Good for**: Simple deployments, mixed workloads
- **Benefit**: One configuration to manage
- **Limitation**: Less control over specific workload placement

**Multiple NodePools** (Advanced Approach):
```yaml
# NodePool 1: For storage-intensive workloads (DDC)
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: storage-optimized
spec:
  template:
    spec:
      requirements:
        - key: eks.amazonaws.com/instance-category
          operator: In
          values: ["i"]  # Only NVMe instances
      taints:  # Prevent other pods from using these nodes
      - key: "workload-type"
        value: "storage"
        effect: "NoSchedule"

---
# NodePool 2: For general workloads
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: general-purpose
spec:
  template:
    spec:
      requirements:
        - key: eks.amazonaws.com/instance-category
          operator: In
          values: ["m", "c"]  # General-purpose, compute-optimized
```

**When to Use Multiple NodePools**:
- **Different cost profiles**: Spot vs On-Demand
- **Different performance requirements**: GPU vs CPU vs Storage
- **Different security requirements**: Isolated workloads
- **Different availability requirements**: Multi-AZ vs single-AZ

#### Summary: Pod → Node Mapping

| Configuration Level | Purpose | Example |
|-------------------|---------|----------|
| **Terraform** | High-level requirements | `instance_type = "i4i.xlarge"` |
| **Helm Chart** | Kubernetes pod spec | `nodeSelector: {"node.kubernetes.io/instance-type": "i4i.xlarge"}` |
| **NodeClass** | Infrastructure config | Security groups, subnets, storage |
| **NodePool** | Workload requirements | Instance families, capacity types |
| **Karpenter** | Automatic provisioning | Creates matching EC2 instances |
| **Kubernetes** | Pod scheduling | Places pods on appropriate nodes |

**Key Insight**: You don't directly assign pods to "node groups" in EKS Auto Mode. Instead, you specify what your pods need, and Karpenter creates appropriate nodes automatically.

#### Built-in vs Custom Node Pools

**Built-in Node Pools** (AWS-Managed):
- **"general-purpose"**: Handles most application workloads
- **"system"**: Handles Kubernetes system pods (kube-system namespace)
- **Cannot be customized**: AWS controls instance selection and configuration
- **Automatic**: Works without any additional configuration

**Custom Node Pools** (Your Configuration):
- **Full control**: You specify instance types, capacity, networking
- **Advanced features**: Taints, tolerations, specialized hardware
- **More complex**: Requires NodeClass + NodePool + Access Entry configuration
- **Use cases**: Specific performance requirements, cost optimization, isolation

**When to Use Each**:
- **Built-in only**: Simple deployments, standard workloads, getting started
- **Custom only**: Advanced requirements, specific instance types, cost optimization
- **Both**: Mixed workloads with some standard and some specialized requirements

**Our DDC Implementation**: Uses both built-in (for system pods) and custom (for DDC workloads requiring NVMe storage).