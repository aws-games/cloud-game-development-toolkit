# DDC Services Submodule

This submodule deploys the [Unreal Cloud DDC](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine) application services on Kubernetes using Helm charts and manages advanced load balancer integration patterns.

> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

**What this submodule creates**: DDC application deployment via Helm, ECR pull-through cache for GitHub container images, Kubernetes service integration with external NLB via TargetGroupBinding, and EKS addons for cluster functionality.

## Architecture

**Advanced Integration Pattern**: Combines Terraform infrastructure management with Kubernetes service discovery for seamless load balancer integration.

**Core Components**:
- **ECR Pull-Through Cache**: Caches GitHub Container Registry images locally
- **DDC Application**: Helm deployment with ScyllaDB and S3 integration
- **Kubernetes Resources**: Service accounts, namespaces, RBAC configurations
- **EKS Addons**: CoreDNS, VPC-CNI, EBS CSI driver, certificate manager
- **Load Balancer Integration**: ClusterIP service with automatic NLB target registration

## Prerequisites

### Required Infrastructure
- **EKS cluster** (provided by ddc-infra submodule)
- **Target group ARN** from parent module NLB
- **ScyllaDB cluster** with accessible IPs
- **S3 bucket** for asset storage

### GitHub Container Registry Access
- **Epic Games organization membership** - [Join here](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)
- **GitHub Personal Access Token** with `packages:read` permission
- **AWS Secrets Manager secret** with `ecr-pullthroughcache/` prefix containing GitHub credentials

### Authentication
- **DDC bearer token** for API authentication
- **Kubernetes service account** with appropriate RBAC permissions

## Infrastructure Change Behavior

### ⚠️ CRITICAL: Automatic Redeployment on ScyllaDB Changes

**When ScyllaDB IPs change** (from ddc-infra module):

1. **Terraform detects `scylla_ips` change** → Module input updated
2. **Helm template re-renders** → New connection string generated
3. **Helm deployment triggered** → DDC pods restart automatically
4. **Service briefly unavailable** → ~30-60 seconds during restart

**This ensures DDC always connects to healthy ScyllaDB nodes.**

### Change Propagation Flow

```
ddc-infra: ScyllaDB IP Change
         ↓
Parent Module: scylla_ips Updated
         ↓
ddc-services: Helm Values Changed
         ↓
Kubernetes: Pod Restart
         ↓
DDC: New ScyllaDB Connection
```

### Impact on Operations

**✅ Automatic Recovery:**
- No manual intervention required
- DDC automatically discovers new database IPs
- Service resumes after pod restart

**⚠️ Service Interruption:**
- Brief downtime during redeployment
- Active cache operations interrupted
- Clients must reconnect

**🔧 Best Practices:**
- Schedule infrastructure changes during maintenance windows
- Monitor DDC service health after ScyllaDB changes
- Verify connectivity after automatic redeployment

## Configuration

### Key Variables

**Application Configuration**:
- `unreal_cloud_ddc_version`: DDC version (e.g., "1.2.0") - **Use 1.2.0, avoid 1.3.0**
- `namespace`: Kubernetes namespace for DDC services
- `ddc_bearer_token`: Authentication token for DDC API

**Infrastructure Integration**:
- `nlb_target_group_arn`: Target group ARN from parent module NLB
- `scylla_ips`: ScyllaDB node IPs for database connection
- `s3_bucket_id`: S3 bucket for asset storage
- `region`: AWS region for ECR pull-through cache

**GitHub Integration**:
- `ghcr_credentials_secret_manager_arn`: GitHub credentials for container image access

## Critical Configuration: Bring-Your-Own Load Balancer

**⚠️ IMPORTANT**: When using `nlb_target_group_arn` (bring-your-own NLB), this module requires specific configuration to disable Unix sockets and use standard HTTP.

### The Problem
Unreal Cloud DDC defaults to Unix socket communication with NGINX sidecar:
- **Default behavior**: DDC application binds to `unix:///nginx/jupiter-http.sock`
- **NGINX sidecar**: Proxies requests between load balancer and Unix socket
- **Bring-your-own NLB**: Needs direct HTTP communication, no NGINX sidecar
- **Result**: DDC crashes with `Invalid url: 'unix:///nginx/jupiter-http.sock'`

### The Solution
This module implements a **multi-layer configuration override** to force standard HTTP:

```hcl
# Disable NGINX sidecar completely
set {
  name  = "nginx.enabled"
  value = "false"
}

# Disable Unix socket logic
set {
  name  = "nginx.useDomainSockets"
  value = "false"
}

# Override ASP.NET Core URL binding
set {
  name  = "env[0].name"
  value = "ASPNETCORE_URLS"
}
set {
  name  = "env[0].value"
  value = "http://0.0.0.0:80"
}

# CRITICAL: Override Kestrel-specific configuration
set {
  name  = "env[1].name"
  value = "Kestrel__Endpoints__Http__Url"
}
set {
  name  = "env[1].value"
  value = "http://0.0.0.0:80"
}
```

### Why Multiple Overrides Are Required

The DDC application has **multiple configuration layers**:

1. **Chart-level settings**: `nginx.enabled`, `nginx.useDomainSockets`
2. **General ASP.NET Core**: `ASPNETCORE_URLS` environment variable
3. **Configuration files**: Hardcoded Unix socket settings in application config
4. **Kestrel-specific**: `Kestrel__Endpoints__Http__Url` (highest precedence)

**Critical insight**: Only `Kestrel__Endpoints__Http__Url` has sufficient precedence to override the persistent file-based Unix socket configuration.

### Troubleshooting Unix Socket Errors

If you see crashes with `Invalid url: 'unix:///nginx/jupiter-http.sock'`:

**❌ These alone won't work:**
- `nginx.useDomainSockets=false` only
- `nginx.enabled=false` only  
- `ASPNETCORE_URLS` only

**✅ Required combination:**
- All four configuration overrides above
- Both environment variables are essential
- `Kestrel__Endpoints__Http__Url` is the critical override

### Service Configuration

With bring-your-own NLB:
```hcl
# Use ClusterIP service (no auto load balancer creation)
set {
  name  = "service.type"
  value = "ClusterIP"
}

# Target the HTTP port name
set {
  name  = "service.targetPort"
  value = "http"
}
```

**Result**: 
- Pod listens on port 80 (HTTP)
- Service routes to port 80
- TargetGroupBinding connects service to existing NLB
- No NGINX sidecar, no Unix sockets

## Helm Configuration Patterns

### Understanding Terraform + Helm Integration

This module uses two approaches for configuring Helm charts:

#### **Static Configuration (values blocks)**
```hcl
# Complex, rarely-changing configuration
values = [yamlencode({
  config = {
    S3 = { BucketName = "my-bucket" }
    Scylla = { ConnectionString = "..." }
  }
  global = {
    auth = { ... }
  }
})]
```

**When to use:**
- ✅ Complex nested configuration objects
- ✅ Static values that rarely change
- ✅ Configuration from template files

**Limitation:** Terraform doesn't track changes inside `yamlencode()` - if you modify the YAML structure, Terraform may not detect it as a change.

#### **Dynamic Configuration (set blocks)**
```hcl
# Explicit, trackable configuration
set {
  name  = "service.type"
  value = "NodePort"
}

set {
  name  = "replicaCount"
  value = var.replica_count
}
```

**When to use:**
- ✅ Values that change between environments
- ✅ Configuration you want Terraform to track for drift detection
- ✅ Simple key-value overrides

**Benefit:** Terraform tracks these as explicit resource attributes - changes trigger plan updates.

#### **Precedence Order**
1. **`set` blocks** (highest priority)
2. **`values` blocks** 
3. **Chart default values** (lowest priority)

#### **Best Practice Pattern**
```hcl
resource "helm_release" "ddc" {
  # Static, complex config in values
  values = [yamlencode({
    config = { /* complex nested objects */ }
  })]
  
  # Dynamic, environment-specific config in set blocks
  set {
    name  = "service.type"
    value = var.service_type  # Terraform tracks this
  }
  
  set {
    name  = "image.tag"
    value = var.image_version  # Easy to change per environment
  }
}
```

### Why This Module Uses Both

- **`values`**: DDC auth policies, S3/ScyllaDB connection strings (complex, static)
- **`set` blocks**: Service type, NodePort (simple values that Terraform needs to track)

This ensures Terraform can detect and apply changes to service configuration while maintaining complex static configuration in YAML format.

### Optional Configuration

**EKS Addons**:
- `enable_cert_manager = false` to disable certificate manager addon
- `enable_aws_load_balancer_controller = false` to disable AWS Load Balancer Controller
- Custom addon versions via `cert_manager_version` and `aws_load_balancer_controller_version`

**Helm Configuration**:
- `helm_timeout_seconds` for deployment timeout (default: 1800)
- `helm_wait_for_jobs` to wait for completion (default: true)
- Custom namespace via `namespace` variable

**ECR Pull-Through Cache**:
- Automatically configured based on `region` and `ghcr_credentials_secret_manager_arn`
- Caches GitHub Container Registry images locally for faster pulls

## Testing and Validation

**Functional Testing**: Use the parent module's functional test script to validate DDC deployment:
```bash
# Run from your Terraform directory
../../assets/scripts/ddc_functional_test.sh
```

**Pod Health Checks**:
```bash
# Configure kubectl access first
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check DDC pod status
kubectl get pods -n unreal-cloud-ddc

# Expected: 1/1 Running (single container with bring-your-own NLB)
# Expected: 2/2 Running (DDC + NGINX containers with auto NLB)
```

**Service Integration Validation**:
```bash
# Check TargetGroupBinding status
kubectl get targetgroupbinding -n unreal-cloud-ddc
kubectl describe targetgroupbinding <tgb-name> -n unreal-cloud-ddc

# Verify target group health in AWS
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Troubleshooting

### Unix Socket Configuration Issues

**Problem**: Pod crashes with `Invalid url: 'unix:///nginx/jupiter-http.sock'`

**Root Cause**: Incomplete Unix socket configuration override for bring-your-own NLB

**Solution**: Verify all 4 configuration overrides are applied:
```bash
# Check Helm values
helm get values cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc

# Should show:
# nginx:
#   enabled: false
#   useDomainSockets: false
# env:
# - name: ASPNETCORE_URLS
#   value: http://0.0.0.0:80
# - name: Kestrel__Endpoints__Http__Url
#   value: http://0.0.0.0:80
```

### Target Group Health Issues

**Problem**: Targets show "unhealthy" in AWS target group

**Root Cause**: Health check path mismatch (`/health` vs `/health/live`)

**Solution**: Update target group health check path:
```bash
aws elbv2 modify-target-group \
  --target-group-arn <arn> \
  --health-check-path "/health/live"
```

### TargetGroupBinding Issues

**Problem**: TargetGroupBinding shows "BackendNotFound" events

**Root Cause**: Service name mismatch in TargetGroupBinding configuration

**Solution**: Verify service name matches TargetGroupBinding spec:
```bash
kubectl get svc -n unreal-cloud-ddc
kubectl get targetgroupbinding -n unreal-cloud-ddc -o yaml
```

<!-- BEGIN_TF_DOCS -->
