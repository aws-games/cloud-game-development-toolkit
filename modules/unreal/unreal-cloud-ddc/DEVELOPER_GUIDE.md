# Developer Reference Guide

> **Technical deep dive for developers working with the Unreal Cloud DDC Terraform module**
>
> **Based on actual code analysis - every statement verified against implementation**

## Prerequisites

- Epic Games GitHub organization access for `oci://ghcr.io/epicgames/unreal-cloud-ddc` chart
- Understanding of Kubernetes concepts and EKS Auto Mode
- Familiarity with Helm charts and Terraform Actions

## Module Architecture

**Two-Submodule Design** with conditional deployment:

```
Unreal Cloud DDC Module (Parent)
├── ddc-infra (Always Created)
│   ├── EKS Auto Mode Cluster
│   ├── External-DNS EKS Addon
│   ├── Fluent Bit EKS Addon (optional)
│   ├── Custom NodeClass + NodePool (NVMe)
│   ├── ScyllaDB on EC2 instances
│   ├── S3 Bucket + IRSA roles
│   └── CodeBuild (cluster setup)
└── ddc-app (Conditional - only if ddc_application_config provided)
    ├── CodeBuild (deploy + test)
    ├── Helm deployment (Epic's chart)
    └── LoadBalancer service (creates NLB)
```

### What Actually Gets Installed

**ddc-infra submodule**:
- ✅ EKS Auto Mode cluster with compute_config enabled
- ✅ External-DNS EKS Addon (creates Route53 DNS records)
- ✅ Fluent Bit EKS Addon (if `enable_centralized_logging = true`)
- ✅ Custom NodeClass "ddc-nodeclass" + NodePool "ddc-compute"
- ✅ ScyllaDB on dedicated EC2 instances (not in EKS)
- ✅ CodeBuild project for cluster setup (creates NodePools via kubectl)

**ddc-app submodule** (only when `ddc_application_config` provided):
- ✅ CodeBuild projects for deployment and testing
- ✅ Helm deployment using Epic's official chart
- ✅ Service type: LoadBalancer (EKS Auto Mode creates NLB automatically)
- ❌ NO AWS Load Balancer Controller installation (EKS Auto Mode handles LoadBalancer services natively)

## EKS Auto Mode Deep Dive

### Core Concept: Application-Driven Infrastructure

**Traditional EKS**: "Create 3 m5.large nodes, then deploy applications"
**EKS Auto Mode**: "Deploy applications with resource requirements, get appropriate nodes automatically"

### Cluster Configuration

```hcl
# From ddc-infra/main.tf
resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  bootstrap_self_managed_addons = false  # CRITICAL for EKS Auto Mode
  
  compute_config {
    enabled       = true
    node_role_arn = aws_iam_role.eks_node_role.arn
    node_pools    = ["general-purpose", "system"]  # Built-in pools
  }
  
  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true  # Enables LoadBalancer service support
    }
  }
}
```

### Custom NodePool Strategy

**Why Custom NodePool**: Built-in pools don't guarantee NVMe storage for DDC cache performance.

**NodeClass Configuration** (from `create-nodepools.sh`):
```yaml
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: ddc-nodeclass
spec:
  role: ${NODE_ROLE_NAME}
  securityGroupSelectorTerms:
    - id: ${CLUSTER_SG_ID}  # Uses Terraform-managed security group
```

**NodePool Configuration**:
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ddc-compute
spec:
  template:
    spec:
      requirements:
        - key: eks.amazonaws.com/instance-local-nvme
          operator: Gt
          values: ["100"]  # Requires NVMe storage
```

**Application Targeting**:
```yaml
# From ddc-app/locals.tf
nodeSelector:
  "eks.amazonaws.com/instance-category": "i"  # Targets i-family instances
```

## Networking Architecture

### LoadBalancer Service (NOT Terraform NLB)

**CRITICAL**: The module uses Kubernetes LoadBalancer services, NOT Terraform-managed NLBs.

**Service Configuration** (from `ddc-app/locals.tf`):
```yaml
service:
  type: "LoadBalancer"  # EKS Auto Mode creates NLB
  loadBalancerClass: "eks.amazonaws.com/nlb"
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    external-dns.alpha.kubernetes.io/hostname: "us-east-1.ddc.example.com"
```

**Traffic Flow**:
```
Game Clients → DNS (External-DNS) → NLB (EKS Auto Mode) → DDC Pods (direct IP targeting)
```

**How It Works**:
1. **Helm deploys LoadBalancer service** with EKS Auto Mode annotations
2. **EKS Auto Mode creates NLB** automatically (no AWS Load Balancer Controller needed)
3. **External-DNS creates Route53 records** based on service annotations
4. **Direct IP targeting**: NLB routes to pod IPs (not node IPs)

### Security Group Architecture

**Critical Fix**: EKS cluster and NodeClass must use same security group.

**Problem**: Default EKS creates its own security group, but custom NodeClass needs explicit configuration.

**Solution** (from `ddc-infra/main.tf`):
```hcl
resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  vpc_config {
    security_group_ids = [aws_security_group.cluster_security_group.id]
  }
}
```

**NodeClass uses same security group** (from `create-nodepools.sh`):
```yaml
securityGroupSelectorTerms:
  - id: $CLUSTER_SG_ID  # Same as EKS cluster
```

## Database Architecture (ScyllaDB)

### EC2-Based Deployment

**Why not EKS**: Persistent data requirements and Epic Games compatibility.

**Configuration**:
```hcl
scylla_config = {
  current_region = {
    replication_factor = 3  # Creates 3 instances AND 3 data replicas
  }
}
```

### Multi-Region Naming Issue

**Problem**: ScyllaDB has parsing conflicts with AWS region names ending in `-1`.

**CGD Toolkit Solution**:
- `us-east-1` → `us-east` datacenter name
- `us-west-2` → `us-west-2` datacenter name (no change)

**Impact**: Cannot use `us-east-1` + `us-east-2` together (both become `us-east`).

**Recommended Combinations**:
- ✅ `us-east-1` + `us-west-2`
- ✅ `us-east-1` + `eu-west-1`
- ❌ `us-east-1` + `us-east-2` (naming collision)

## Deployment Orchestration

### Terraform Actions Architecture

**The Challenge**: EKS cluster creation (2-3 min) vs cluster readiness (8-15 min).

**Solution**: CodeBuild + Terraform Actions for reliable coordination.

### ddc-infra Deployment

**Terraform Action** (from `ddc-infra/main.tf`):
```hcl
resource "terraform_data" "cluster_setup_trigger" {
  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.cluster_setup]
    }
  }
}
```

**What CodeBuild Does** (`cluster-setup.yml`):
1. Installs kubectl and helm
2. Configures kubectl access to EKS cluster
3. Runs `create-nodepools.sh` to create custom NodeClass and NodePool
4. Waits for cluster readiness

### ddc-app Deployment

**Two CodeBuild Projects**:

1. **Deploy** (`ddc_deployer`):
   - Downloads Epic's chart from GHCR
   - Deploys via Helm with generated values
   - Waits for pods to be ready

2. **Test** (`ddc_tester`):
   - Validates DDC service health
   - Tests API endpoints with bearer tokens
   - Runs multi-region tests (if enabled)

**Terraform Actions Control**:
```hcl
# Deploy - always runs when ddc_application_config present
resource "terraform_data" "deploy_trigger" {
  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.deploy_ddc]
    }
  }
}

# Test - controlled by validation flags
resource "terraform_data" "test_trigger" {
  count = (
    var.ddc_application_config.enable_single_region_validation ||
    (var.ddc_application_config.enable_multi_region_validation && 
     var.ddc_application_config.peer_region_ddc_endpoint == null)
  ) ? 1 : 0
}
```

## Helm Architecture

### Epic's Official Chart

**Chart Source**: `oci://ghcr.io/epicgames/unreal-cloud-ddc:1.2.0+helm`

**Authentication Required**: GitHub token with `read:packages` permission.

**Deployment Process** (from `codebuild-deploy-ddc.sh`):
```bash
# Login to GHCR
echo "$GHCR_TOKEN" | helm registry login ghcr.io --username "$GHCR_USERNAME" --password-stdin

# Pull and deploy
helm pull oci://ghcr.io/epicgames/unreal-cloud-ddc --version 1.2.0+helm
helm upgrade --install $NAME_PREFIX-app "unreal-cloud-ddc-1.2.0+helm.tgz" \
  --namespace $NAMESPACE \
  --values /tmp/ddc-helm-values.yaml
```

### Values Generation

**HCL to YAML Conversion** (from `ddc-app/locals.tf`):
```hcl
locals {
  ddc_helm_values = {
    fullnameOverride = local.name_prefix
    replicaCount     = var.ddc_application_config.replica_count
    
    service = {
      type = "LoadBalancer"
      loadBalancerClass = "eks.amazonaws.com/nlb"
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        "external-dns.alpha.kubernetes.io/hostname" = var.ddc_endpoint_pattern
      }
    }
    
    nodeSelector = {
      "eks.amazonaws.com/instance-category" = "i"
    }
  }
  
  helm_values_yaml = yamlencode(local.ddc_helm_values)
}
```

**Why yamlencode() over templatefile()**:
- Guaranteed valid YAML output
- Type safety at Terraform plan time
- Better IDE support and error messages

## Configuration Reference

### Critical Variables

**ddc_infra_config**:
- `eks_node_group_subnets`: Subnets for EKS nodes (also used by CodeBuild)
- `scylla_config.current_region.replication_factor`: ScyllaDB instances + replicas
- `kubernetes_version`: EKS cluster version
- `endpoint_public_access` / `endpoint_private_access`: EKS API access
- `public_access_cidrs`: IP allowlist for EKS API

**ddc_application_config**:
- `replica_count`: Number of DDC pods
- `cpu_requests` / `memory_requests`: Pod resource requests
- `container_image`: DDC container image (default: Epic's latest)
- `helm_chart`: Chart reference (default: `1.2.0+helm`)
- `ddc_namespaces`: Game project isolation configuration
- `enable_single_region_validation`: Single-region testing (default: true)
- `enable_multi_region_validation`: Multi-region testing (default: false)
- `peer_region_ddc_endpoint`: Other region endpoint (null = primary region)

### Testing Control System

**Single-Region Testing** (default: enabled):
```hcl
ddc_application_config = {
  enable_single_region_validation = true  # Default
}
```

**Multi-Region Testing** (primary region only):
```hcl
# Primary region (us-east-1)
ddc_application_config = {
  enable_multi_region_validation = true
  peer_region_ddc_endpoint = null  # Identifies as primary
}

# Secondary region (us-west-2)  
ddc_application_config = {
  enable_multi_region_validation = false  # Disabled
  peer_region_ddc_endpoint = "us-east-1.ddc.example.com"
}
```

**Debug Mode** (forces single-region tests only):
```hcl
force_codebuild_run = true  # Adds timestamp to trigger inputs
```

## Troubleshooting

### NodeClass Instances Not Joining Cluster

**Symptoms**: EC2 instances launch but never appear as Kubernetes nodes.

**Root Cause**: Security group mismatch between EKS cluster and NodeClass.

**Diagnosis**:
```bash
# Check instance security groups
aws ec2 describe-instances --instance-ids <id> --query 'Reservations[].Instances[].SecurityGroups[].GroupId'

# Check EKS cluster security groups
aws eks describe-cluster --name <cluster-name> --query 'cluster.resourcesVpcConfig.securityGroupIds'

# Check EC2 console output for kubelet errors
aws ec2 get-console-output --instance-id <id>
```

**Solution**: Ensure EKS cluster uses Terraform-managed security group.

### LoadBalancer Service Not Creating NLB

**Symptoms**: Service exists but no NLB appears in AWS console.

**Diagnosis**:
```bash
# Check service configuration
kubectl describe svc <name-prefix> -n <name-prefix>

# Check EKS Auto Mode status
kubectl get events -n <name-prefix>

# Verify loadBalancerClass
kubectl get svc <name-prefix> -n <name-prefix> -o yaml | grep loadBalancerClass
```

**Common Issues**:
- Missing `loadBalancerClass: "eks.amazonaws.com/nlb"`
- EKS cluster missing `elastic_load_balancing.enabled = true`
- Subnet configuration issues

### DDC Pods Not Ready

**Diagnosis**:
```bash
# Check pod status
kubectl get pods -n <name-prefix> -l app.kubernetes.io/name=unreal-cloud-ddc

# Check pod logs
kubectl logs <pod-name> -n <name-prefix>

# Check node resources
kubectl describe nodes
kubectl top nodes
```

**Common Issues**:
- NVMe storage not available (wrong instance type)
- Database connection failures (ScyllaDB not ready)
- Resource constraints (insufficient CPU/memory)

### CodeBuild Deployment Failures

**Check CodeBuild logs**:
```bash
# List recent builds
aws codebuild list-builds-for-project --project-name <project-name>

# Get build logs
aws logs get-log-events --log-group-name /aws/codebuild/<project-name> --log-stream-name <stream>
```

**Common Issues**:
- GHCR authentication failures (invalid GitHub token)
- Helm chart download failures (network/permissions)
- kubectl access issues (EKS access entries)

## Critical Gotchas

### 1. EKS Auto Mode vs Traditional EKS

**EKS Auto Mode Requirements**:
- `bootstrap_self_managed_addons = false`
- `compute_config.enabled = true`
- `kubernetes_network_config.elastic_load_balancing.enabled = true`

**LoadBalancer Service Behavior**:
- EKS Auto Mode: Native support, no controller needed
- Traditional EKS: Requires AWS Load Balancer Controller

### 2. Security Group Configuration

**CRITICAL**: Custom NodeClass instances must use same security group as EKS cluster.

**Default Behavior**: EKS creates its own security group, NodeClass needs explicit configuration.

**Fix**: Force both to use Terraform-managed security group.

### 3. Multi-Region ScyllaDB Naming

**Issue**: AWS regions ending in `-1` cause ScyllaDB datacenter name collisions.

**Solution**: Use geographically distributed regions, not adjacent ones.

### 4. GHCR Authentication

**Requirement**: GitHub Personal Access Token with `read:packages` permission.

**Storage**: Must be in AWS Secrets Manager for CodeBuild access.

**Format**:
```json
{
  "username": "github-username",
  "accessToken": "ghp_xxxxxxxxxxxx"
}
```

### 5. Testing Control Logic

**Multi-Region Killswitch**: Multi-region tests only run when `peer_region_ddc_endpoint = null`.

**Debug Override**: Only forces single-region tests, not multi-region (prevents duplication).

### 6. Terraform Actions Dependencies

**Known Issue**: `depends_on` in Terraform Actions is ignored due to platform bug.

**Workaround**: CodeBuild scripts include retry logic and readiness checks.

### 7. DDC Namespace Confusion

**Two Different Namespaces**:
1. **DDC Logical Namespaces**: Game project isolation in S3 (`project1/`, `project2/`)
2. **Kubernetes Namespace**: Infrastructure container (`unreal-cloud-ddc`)

**S3 Risk**: All DDC projects share same S3 bucket - deletion impacts ALL projects.

## Emergency Procedures

### Cluster Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify cluster status
aws eks describe-cluster --name <cluster-name> --query 'cluster.status'

# Check IAM permissions
aws sts get-caller-identity
```

### Force Redeployment
```bash
# Force CodeBuild re-run
terraform apply -var="force_codebuild_run=true"

# Or replace specific triggers
terraform apply -replace="module.ddc_app[0].terraform_data.deploy_trigger"
```

### DDC Service Recovery
```bash
# Restart deployment
kubectl rollout restart deployment/<name-prefix> -n <name-prefix>

# Check service health
curl -f "https://<region>.ddc.<domain>/health/live"

# Verify NLB health
aws elbv2 describe-target-health --target-group-arn <arn>
```

---

**Key Insight**: This module leverages EKS Auto Mode's native LoadBalancer service support and External-DNS for fully automated AWS resource management. The architecture embraces Kubernetes automation while maintaining Terraform control over core infrastructure (EKS, ScyllaDB, security groups).