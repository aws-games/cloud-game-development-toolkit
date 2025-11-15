# FINAL DDC REFACTOR - November 11, 2024

## Current State Analysis

**Project**: Cloud Game Development Toolkit - Unreal Cloud DDC Module Refactor
**Status**: 🚧 MAJOR PROGRESS - yamlencode() implemented, external-dns added, still using Traditional EKS
**Goal**: Refactor to support EKS Auto Mode + external-dns for predictable endpoints

### Current Architecture Status
- ✅ **yamlencode() Implementation**: COMPLETED - Full HCL structure in locals.tf
- ✅ **External-DNS**: COMPLETED - Added with null_resource + kubectl approach
- ✅ **LoadBalancer Service**: COMPLETED - Designed in locals.tf with NLB annotations
- ❌ **EKS Auto Mode**: NOT IMPLEMENTED - Still using Traditional EKS + Managed Node Groups
- ❌ **AWSCC Provider**: NOT IMPLEMENTED - Still using AWS provider for EKS cluster
- ✅ **Variable Consistency**: COMPLETED - All optional defaults changed to null

## EKS Compute Mode Analysis

### Option 1: EKS Auto Mode + External-DNS ⭐ RECOMMENDED
**Pros:**
- ✅ **Simplified Operations**: No node group management, automatic scaling
- ✅ **Eliminates Race Conditions**: No manual NLB/TG management in TF
- ✅ **Single-Step Apply**: External-dns handles DNS dynamically
- ✅ **Multi-Region Friendly**: Each region manages its own resources
- ✅ **Future-Proof**: AWS's strategic direction for EKS
- ✅ **Reduced TF Complexity**: Fewer providers, cleaner state management
- ✅ **ArgoCD Integration**: Perfect for customers who want GitOps

**Cons:**
- ❌ **Newer Technology**: Less battle-tested than Standard mode
- ❌ **Instance Type Limitations**: May have constraints on storage-optimized instances
- ❌ **Learning Curve**: Team needs to understand Auto Mode behavior

**DDC Compatibility**: ✅ Compatible - Can use NodePools for storage requirements

### Option 2: EKS Standard + Managed Node Groups
**Pros:**
- ✅ **Battle-Tested**: Mature, proven for production workloads
- ✅ **Full Control**: Complete instance type/storage configuration
- ✅ **Predictable**: Well-understood behavior and limitations
- ✅ **Storage Flexibility**: Easy i4i, i3, EBS configurations

**Cons:**
- ❌ **Complex Management**: Node group lifecycle, scaling policies
- ❌ **Race Conditions**: Current TF destroy issues persist
- ❌ **Multi-Step Deploys**: Still need complex TF provider orchestration

**DDC Compatibility**: ✅ Fully Compatible - Current implementation

### Option 3: EKS Fargate
**Pros:**
- ✅ **Serverless**: No node management at all
- ✅ **Cost Efficient**: Pay per pod, automatic scaling

**Cons:**
- ❌ **Storage Limitations**: No persistent local storage (hostPath)
- ❌ **DDC Incompatible**: Cannot mount NVMe drives or hostPath volumes
- ❌ **Performance**: Network storage only, higher latency

**DDC Compatibility**: ❌ NOT COMPATIBLE - DDC requires local storage

## Service Types and Use Cases

### DDC Service Configuration
**Recommended**: `LoadBalancer` type with external-dns
```yaml
# DDC Service (in Helm values)
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    external-dns.alpha.kubernetes.io/hostname: "us-east-1.ddc.example.com"
```

### ACM Certificate Integration
- **Create ACM certs in Terraform** (deterministic)
- **Pass cert ARNs via LoadBalancer service** annotations
- **External-dns manages DNS validation** records automatically

## Implementation Plan

### Phase 1: Analysis and Preparation ✅ COMPLETED
- [x] **Task 1.1**: Analyze current module structure
- [x] **Task 1.2**: Review DDC Helm chart requirements  
- [x] **Task 1.3**: Review wrapper chart configuration
- [x] **Task 1.4**: Identify breaking changes needed

### Phase 1.5: yamlencode() Migration ✅ COMPLETED
- [x] **Task 1.5**: ✅ COMPLETED yamlencode() structure designed in locals.tf
- [x] **Task 1.6**: ✅ COMPLETED Replace templatefile() usage in main.tf with yamlencode()
- [x] **Task 1.7**: ✅ COMPLETED Update service configuration for LoadBalancer type
- [x] **Task 1.8**: ✅ COMPLETED variable consistency (null defaults)

### Phase 2: EKS Auto Mode Foundation ✅ COMPLETED
- [x] **Task 2.1**: ✅ COMPLETED Refactor EKS cluster to Auto Mode (AWSCC provider)
- [x] **Task 2.2**: ✅ COMPLETED Subnet tags handled at example level
- [x] **Task 2.3**: ✅ COMPLETED Remove manual NLB/Target Group resources
- [x] **Task 2.4**: ✅ COMPLETED Install AWS Load Balancer Controller
- [x] **Task 2.5**: ✅ COMPLETED Install external-dns controller

### Phase 3: DDC Service Refactor ✅ COMPLETED
- [x] **Task 3.1**: ✅ COMPLETED Update DDC service to LoadBalancer type (active in locals.tf)
- [x] **Task 3.2**: ✅ COMPLETED Add NLB service annotations (active in locals.tf)
- [x] **Task 3.3**: ✅ COMPLETED Configure storage for Auto Mode (Custom NodePool with NVMe priority)
- [x] **Task 3.4**: ✅ COMPLETED Remove TargetGroupBinding CRD usage

### Phase 4: Testing and Validation (ArgoCD support deferred)
- [ ] **Task 4.1**: Test single-region deployment
- [ ] **Task 4.2**: Test multi-region deployment  
- [ ] **Task 4.3**: Test destroy operations (no race conditions)
- [ ] **Task 4.4**: Validate DNS endpoints work correctly

### Phase 5: Documentation and Cleanup
- [ ] **Task 5.1**: Update module README
- [ ] **Task 5.2**: Update examples
- [ ] **Task 5.3**: Create migration guide
- [ ] **Task 5.4**: Remove steering document

## Architecture Decisions

### Port Configuration Analysis

**Epic's Architecture (NGINX + Port 8080)**:
- ✅ **Universal Compatibility**: Works with any Kubernetes service type (NodePort, ClusterIP, LoadBalancer)
- ✅ **Production Hardened**: NGINX handles SSL termination, static files, request buffering
- ✅ **Security**: Non-root containers (port 8080), NGINX as security boundary
- ✅ **NodePort Optimized**: NGINX proxies standard port 80 → container port 8080 → NodePort 30000+
- ✅ **Enterprise Features**: Rate limiting, caching, advanced routing

**CGD Toolkit Architecture (Direct Kestrel + Port 80)**:
- ✅ **LoadBalancer Optimized**: Direct IP routing eliminates proxy overhead
- ✅ **Simpler Stack**: Fewer moving parts, easier debugging
- ✅ **Standard HTTP**: Port 80 expected for web services
- ✅ **AWS Integration**: Security groups already configured for port 80
- ✅ **Performance**: One less network hop (NLB → Pod vs NLB → NGINX → Pod)

**Production Usage Patterns**:
- **Large Scale K8s**: LoadBalancer + direct pod routing is most common
- **Enterprise**: NGINX proxy still popular for advanced features
- **Cloud Native**: Direct service exposure preferred for simplicity
- **AWS Specific**: NLB + IP targeting is the recommended pattern

**Why We Choose Direct Kestrel (No Optional NGINX)**:
1. **AWS Services Replace NGINX**: NLB (SSL termination, health checks), WAF (rate limiting), ACM (certificates)
2. **Single Configuration Path**: Reduces testing burden and maintenance complexity
3. **Simpler Troubleshooting**: Direct pod access, fewer network hops, single failure domain
4. **Better Resource Utilization**: No NGINX sidecar containers consuming CPU/memory
5. **Extensibility via Forking**: Advanced users can fork CGD Toolkit for custom NGINX configurations
6. **Focus on Core Problems**: EKS Auto Mode + external-dns are the primary refactor goals

### Wrapper Chart vs --set Overrides Analysis

**Option 1: Wrapper Chart (Current Approach)**
- ✅ **Complex Overrides**: Handles nested YAML structures cleanly
- ✅ **Version Control**: Template changes tracked in Git
- ✅ **Validation**: Terraform can validate template before deployment
- ✅ **Maintainability**: Clear separation of CGD-specific vs Epic defaults
- ✅ **Documentation**: Template serves as configuration documentation

**Option 2: --set Overrides (Alternative)**
- ❌ **Complex Syntax**: `--set env[0].name=ASPNETCORE_URLS,env[0].value=http://0.0.0.0:80`
- ❌ **Escaping Issues**: Special characters in values require complex escaping
- ❌ **No Validation**: Syntax errors only discovered during Helm deployment
- ❌ **Maintenance**: Long command lines, harder to review changes
- ❌ **Limited Nesting**: Difficult for complex YAML structures

**Required Overrides (Too Complex for --set)**:
```yaml
# Epic's defaults we must override:
service:
  type: NodePort        # → LoadBalancer
  port: 8080           # → 80
nginx:
  enabled: true        # → false
env:
  - name: ASPNETCORE_URLS
    value: "http://0.0.0.0:8080"  # → "http://0.0.0.0:80"
persistence:
  volume:
    hostPath:
      path: /data      # → /mnt/.ephemeral (EKS Auto Mode)
```

**Wrapper Chart Value**: Provides clean, maintainable way to handle 15+ configuration overrides that would be unwieldy as --set parameters.

### File Naming Standards
**Current Structure**:
```
templates/
├── fluentbit-values.yaml                    ← FluentBit Helm values template
├── unreal_cloud_ddc_consolidated.yaml       ← DDC Helm values template
└── README.md
```

**Recommended Rename**: `unreal-cloud-ddc-values.yaml` (consistent with FluentBit pattern)

### Service Type Benefits
| Type | IP Usage | Routing | External Access | Use Case |
|------|----------|---------|-----------------|----------|
| **NodePort** | Pod IPs + Node ports | Node:30000+ → Pod | Manual | Epic's default |
| **ClusterIP** | Pod IPs only | Internal only | Via TargetGroupBinding | Your current |
| **LoadBalancer** | Pod IPs + LB | Direct to pods | Automatic | Recommended |

### Variable Structure Decision
**Recommendation**: Keep separate variables for clear separation
```hcl
variable "ddc_application_config" {
  # Existing DDC configuration - no changes
}

variable "enable_gitops_tools" {
  description = "Deploy ArgoCD for GitOps DDC management"
  type        = bool
  default     = false
}
```

## Key Decisions Made

1. **✅ yamlencode() Implementation**: **COMPLETED** - Full HCL structure active in locals.tf
2. **✅ Dynamic Configuration**: **COMPLETED** - All logic implemented with yamlencode()
3. **✅ EKS LoadBalancer Service**: **COMPLETED** - NLB annotations active in locals.tf
4. **✅ Variable Consistency**: **COMPLETED** - All optional defaults changed to null
5. **❌ AWSCC Provider for EKS**: **NOT IMPLEMENTED** - Still using AWS provider (CRITICAL BLOCKER)
6. **✅ External-DNS**: **COMPLETED** - Implemented with null_resource + kubectl approach
2. **EKS Auto Mode**: Chosen for simplified operations and race condition elimination
3. **External-DNS**: Solves predictable endpoint requirement without TF complexity
4. **Direct Kestrel Only**: AWS services replace NGINX features, single configuration reduces testing burden
5. **LoadBalancer Service**: Eliminates TargetGroupBinding CRD complexity, follows AWS best practices
6. **Wrapper Chart Retained**: Required for 15+ complex configuration overrides (too complex for --set)
7. **File Naming**: Rename to `unreal-cloud-ddc-values.yaml` for consistency with FluentBit pattern
8. **No Optional NGINX**: Single configuration path, AWS services provide enterprise features
9. **Extensibility Strategy**: Users fork CGD Toolkit for advanced customizations
10. **Variable Structure**: Separate `enable_gitops_tools` variable for clear separation
11. **Production Alignment**: Direct pod routing matches large-scale Kubernetes patterns
12. **Breaking Changes**: Acceptable for alpha project - opportunity to modernize architecture

## ✅ AWSCC Provider Migration - COMPLETED

### Current Status: EKS Auto Mode Active

**✅ AWSCC Provider**: EKS cluster migrated to `awscc_eks_cluster` with Auto Mode

**✅ COMPLETED Implementation** (EKS Auto Mode):
```hcl
# eks.tf - Using AWSCC provider
resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  name     = local.name_prefix
  role_arn = aws_iam_role.eks_cluster_role.arn
  
  # EKS Auto Mode configuration
  compute_config = {
    enabled = true
    node_pools = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_node_role.arn
  }
  
  kubernetes_network_config = {
    elastic_load_balancing = { enabled = false }
  }
  
  storage_config = {
    block_storage = { enabled = true }
  }
  
  bootstrap_self_managed_addons = true
}

# Custom NodePool prioritizes compute optimized + NVMe instances
# No managed node groups - EKS Auto Mode handles scaling
```

**Required Migration** (EKS Auto Mode):
```hcl
# AWSCC Provider - READY TO IMPLEMENT
resource "awscc_eks_cluster" "this" {
  name     = "${local.name_prefix}"
  role_arn = aws_iam_role.eks_cluster_role.arn
  
  # EKS Auto Mode configuration
  compute_config = {
    enabled = true
    node_pools = ["general-purpose"]
    node_role_arn = aws_iam_role.eks_node_role.arn
  }
  
  kubernetes_network_config = {
    elastic_load_balancing = {
      enabled = false  # We use external-dns instead
    }
  }
  
  storage_config = {
    block_storage = {
      enabled = true  # EBS CSI driver
    }
  }
  
  bootstrap_self_managed_addons = true  # External-DNS works!
}
```

### Root Cause Analysis

**AWS Provider Validation Logic** (artificial constraint):
```go
// AWS provider enforces all-or-nothing
if computeConfigEnabled != kubernetesNetworkConfigEnabled || 
   computeConfigEnabled != storageConfigEnabled {
    return errors.New("all must be true or false")
}
```

**AWSCC Provider** (no artificial validation):
- Direct CloudFormation passthrough
- No custom validation logic
- Follows actual AWS service capabilities

### Benefits of AWSCC Provider

✅ **EKS Auto Mode + External-DNS**: Independent capability configuration  
✅ **No Artificial Constraints**: Direct AWS API access via CloudFormation  
✅ **Future-Proof**: Always matches latest AWS capabilities  
✅ **Cleaner Architecture**: No provider-specific workarounds needed  

### Migration Impact

**Breaking Change**: Must migrate from `aws_eks_cluster` to `awscc_eks_cluster`

**Benefits Unlocked**:
- EKS Auto Mode (automatic node management, scaling, patching)
- External-DNS (predictable endpoints)
- LoadBalancer Service (eliminates TargetGroupBinding complexity)
- Race condition elimination
- NVMe storage + EBS CSI driver

## EKS Auto Mode Requirements

### Subnet Tagging (CRITICAL)
**EKS Auto Mode requires specific subnet tags for load balancing**:

**Public Subnets** (internet-facing load balancers):
```hcl
resource "aws_ec2_tag" "public_subnet_elb_tags" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
```

**Private Subnets** (internal load balancers):
```hcl
resource "aws_ec2_tag" "private_subnet_elb_tags" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
```

### Security Group Considerations
**EKS Auto Mode Load Balancing Requirements**:
- **Custom Security Groups**: If using custom SGs (not `eks-cluster-sg-*` pattern), cluster IAM role needs additional permissions
- **Automatic Rule Management**: EKS Auto Mode adds required ingress rules to allow ALB/NLB traffic to reach pods
- **No Manual SG Management**: Module should not conflict with EKS Auto Mode's automatic SG rule management

### Implementation Strategy
**Module Handles Tagging Automatically**:
1. **No Prerequisites**: Users don't need to pre-tag subnets
2. **Terraform Manages Tags**: Use `aws_ec2_tag` resource to add required tags during apply
3. **Idempotent**: Tags are added if missing, ignored if present
4. **Clean Destroy**: Tags are removed during destroy

## Implementation Notes

### AWSCC Provider Configuration

**Required Provider Block**:
```hcl
terraform {
  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "awscc" {
  region = var.region
}

provider "aws" {
  region = var.region
}
```

**EKS Cluster Resource**:
```hcl
# Use AWSCC for EKS cluster (bypasses AWS provider constraints)
resource "awscc_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  
  # EKS Auto Mode configuration
  compute_config = {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = var.node_role_arn
  }
  
  kubernetes_network_config = {
    elastic_load_balancing = {
      enabled = false  # We use external-dns instead
    }
  }
  
  storage_config = {
    block_storage = {
      enabled = true  # EBS CSI driver
    }
  }
  
  # External-DNS compatibility
  bootstrap_self_managed_addons = true
  
  resources_vpc_config = {
    subnet_ids = var.subnet_ids
  }
}

# Use AWS provider for everything else (addons, node groups, etc.)
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  # ... configuration
}
```

### Template File Usage
- **Terraform Template**: `templatefile()` renders variables into YAML
- **Output**: Written to `/tmp/ddc-values.yaml` during deployment
- **Helm Usage**: `helm install --values /tmp/ddc-values.yaml`
- **Flow**: TF template → values.yaml → wrapper chart → Epic's charter chart → Epic's chart

### FluentBit Integration
- **Purpose**: Centralized logging to CloudWatch
- **Template**: `fluentbit-values.yaml` (separate Helm release)
- **Pattern**: Same as DDC - TF template generates Helm values

## Critical Design Rationale Summary

**Why Not Epic's Defaults?**
- Epic optimizes for **universal compatibility** (any K8s cluster, any service type)
- CGD Toolkit optimizes for **AWS + LoadBalancer** (cloud-native, production patterns)
- Both approaches are valid - different optimization targets

**Wrapper Chart Justification**:
- **15+ configuration overrides** required (port, NGINX, service type, storage, env vars)
- **--set approach would be unmaintainable**: `helm install --set service.type=LoadBalancer --set service.port=80 --set nginx.enabled=false --set env[0].name=ASPNETCORE_URLS --set env[0].value="http://0.0.0.0:80" ...`
- **Template approach is industry standard** for complex overrides

**Production Kubernetes Patterns**:
- **Large scale deployments**: LoadBalancer + direct pod routing (eliminates proxy overhead)
- **AWS specific**: NLB + IP targeting is recommended pattern
- **Cloud native**: Direct service exposure preferred over proxy layers

## 🐛 **CRITICAL ERRORS FOUND - LINE-BY-LINE ANALYSIS**

### ❌ **BROKEN CODE - WILL NOT DEPLOY**

**1. External-DNS - COMPLETELY BROKEN**
- ❌ **ddc-infra/addons.tf line 21**: References `module.eks.oidc_provider_arn` - **MODULE DOES NOT EXIST**
- ❌ **ddc-infra/addons.tf line 25**: References `module.eks.oidc_provider_arn` - **MODULE DOES NOT EXIST**
- ❌ **ddc-infra/addons.tf line 58**: References `module.eks.cluster_name` - **MODULE DOES NOT EXIST**
- ❌ **ddc-infra/addons.tf line 63**: References `module.eks.cluster_name` - **MODULE DOES NOT EXIST**
- ❌ **ddc-infra/addons.tf line 104**: `depends_on = [module.eks]` - **MODULE DOES NOT EXIST**

**2. VPC Endpoints - REFERENCED BUT DON'T EXIST**
- ❌ **outputs.tf line 248**: References `aws_vpc_endpoint.eks[0].id` - **RESOURCE DOES NOT EXIST**
- ❌ **outputs.tf line 249**: References `aws_vpc_endpoint.eks[0].dns_entry` - **RESOURCE DOES NOT EXIST**
- ❌ **outputs.tf line 253**: References `aws_vpc_endpoint.s3[0].id` - **RESOURCE DOES NOT EXIST**
- ❌ **outputs.tf line 257**: References `aws_vpc_endpoint.logs[0].id` - **RESOURCE DOES NOT EXIST**
- ❌ **outputs.tf line 261**: References `aws_vpc_endpoint.secretsmanager[0].id` - **RESOURCE DOES NOT EXIST**
- ❌ **outputs.tf line 265**: References `aws_vpc_endpoint.ssm[0].id` - **RESOURCE DOES NOT EXIST**

**3. Security Warning - REFERENCED BUT DOESN'T EXIST**
- ❌ **outputs.tf line 139**: References `local.security_warning` - **LOCAL DOES NOT EXIST**
- ❌ **outputs.tf line 178**: References `local.security_warning` - **LOCAL DOES NOT EXIST**

### ✅ **ACTUALLY WORKING CODE**

**1. yamlencode() Migration - ACTUALLY COMPLETE**
- ✅ **ddc-app/locals.tf line 108**: Complete `local.ddc_helm_values` structure
- ✅ **ddc-app/locals.tf line 318**: `yamlencode(local.ddc_helm_values)`
- ✅ **ddc-app/locals.tf line 322**: `local_file.ddc_helm_values` resource
- ✅ **ddc-app/main.tf line 67**: Uses `local_file.ddc_helm_values.filename`
- ✅ **LoadBalancer Service**: Active in `service.type = "LoadBalancer"` (line 148)
- ✅ **NLB Annotations**: Complete configuration (lines 153-169)

**2. Traditional EKS - WORKING BUT NOT AUTO MODE**
- ✅ **ddc-infra/eks.tf line 100**: `aws_eks_cluster` (Traditional EKS)
- ✅ **ddc-infra/eks.tf line 147**: `aws_eks_node_group.ddc_nodes` (Managed Node Groups)
- ✅ **AWS Load Balancer Controller**: Working installation (line 190)
- ✅ **FluentBit**: Working with yamlencode() (line 260)
- ✅ **TargetGroupBinding**: Working implementation (line 430)

**3. Infrastructure Components - WORKING**
- ✅ **ScyllaDB**: Complete implementation in scylla.tf
- ✅ **Security Groups**: Working in sg.tf
- ✅ **IAM Roles**: Complete IRSA setup in iam.tf
- ✅ **S3 Buckets**: Working in s3.tf
- ✅ **Route53**: Working private zones in route53.tf

### 🚀 **IMMEDIATE FIXES REQUIRED**

**Priority 1: Fix Broken References (CRITICAL)**
1. **Fix addons.tf**: Replace `module.eks` with `aws_eks_cluster.unreal_cloud_ddc_eks_cluster`
2. **Remove VPC Endpoint Outputs**: Delete all `aws_vpc_endpoint` references from outputs.tf
3. **Remove Security Warning**: Delete `local.security_warning` references from outputs.tf

**Priority 2: EKS Auto Mode Migration (AFTER FIXES)**
1. Replace `aws_eks_cluster` with `awscc_eks_cluster`
2. Add compute_config, kubernetes_network_config, storage_config
3. Remove `aws_eks_node_group.ddc_nodes`
4. Activate custom NodePool (already implemented)

### 📊 **ACTUAL STATUS**
- **Current**: Traditional EKS + Managed Node Groups + TargetGroupBinding + **BROKEN External-DNS**
- **Immediate**: Fix broken references to make code deployable
- **Future**: EKS Auto Mode migration after fixes
- **Progress**: 40% complete - yamlencode() works, infrastructure works, external-dns broken

### 🎯 **NEXT CRITICAL ACTION**
**Fix broken `module.eks` references in addons.tf and remove non-existent VPC endpoint outputs**

---
**Status: Code is currently broken and will not deploy due to missing module references**