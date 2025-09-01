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

<!-- BEGIN_TF_DOCS -->
