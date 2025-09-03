# Unreal Cloud DDC Module - Design Decisions

This document captures the deep technical decisions, architecture rationale, and implementation details for the Unreal Cloud DDC module.

## Module Architecture Design

### Parent-Child Submodule Pattern

This module uses a parent-child architecture with specialized submodules:

#### DDC Infrastructure (`ddc-infra`)
Creates core AWS resources: EKS cluster with specialized node groups, ScyllaDB database cluster on dedicated EC2 instances, S3 storage buckets, and load balancers for external access.

#### DDC Services (`ddc-services`)
Deploys Unreal Cloud DDC applications to the EKS cluster using Helm charts, manages container orchestration, and configures service networking with load balancer integration.

**Rationale**: Separation of concerns allows independent scaling and management of infrastructure vs application layers.

## Security Configuration Deep Dive

### HTTP vs HTTPS Security

**⚠️ SECURITY**: This module implements **HTTPS-first security** with optional HTTP for development.

#### Production Security (Default)

```hcl
debug_mode = "disabled"  # Default - HTTPS only
```

- ✅ **HTTPS only** (port 443) - Encrypted traffic
- ✅ **Bearer tokens protected** - Authentication encrypted
- ✅ **Game assets encrypted** - Cache data protected in transit
- ❌ **No HTTP listener** - Port 80 blocked

#### Development Mode (Optional)

```hcl
debug_mode = "enabled"  # Enable debug features including HTTP
```

- ✅ **HTTPS available** (port 443) - Production-ready
- ⚠️ **HTTP available** (port 80) - **UNENCRYPTED**
- ⚠️ **Bearer tokens visible** - Network sniffing possible
- ⚠️ **Cache data unencrypted** - Man-in-the-middle attacks possible

#### Recommended Usage

```hcl
# Production
debug_mode = "disabled"

# Development/Testing
debug_mode = "enabled"
```

**Unreal Engine Configuration:**

```ini
; Production (HTTPS only)
[DDC]
Cloud=(Type=HTTPDerivedDataBackend, Host="https://us-east-1.ddc.example.com")

; Development (HTTP available)
[DDC]
Cloud=(Type=HTTPDerivedDataBackend, Host="http://us-east-1.ddc.example.com")  # Only for internal networks
```

## ScyllaDB Architecture Deep Dive

### Core Concepts

| Component                   | Purpose                      | Example                       | Relationship                        |
| --------------------------- | ---------------------------- | ----------------------------- | ----------------------------------- |
| **Replication Factor (RF)** | Number of data copies        | RF=3 means 3 copies           | Must be ≤ node count per datacenter |
| **Nodes**                   | Physical ScyllaDB instances  | 3 EC2 instances               | Independent of EKS node count       |
| **Datacenters**             | Logical node groupings       | `us-east`, `us-west`          | Usually = AWS regions               |
| **Keyspaces**               | Database namespaces          | `jupiter_local_ddc_us_east_1` | Contains tables for specific region |
| **DDC Namespaces**          | Application-level separation | `ddc`, `project-a`            | Logical separation within keyspaces |

### Replication Factor Guidelines

**Single Region Recommendations:**

```hcl
# Small deployment (cost-optimized)
scylla_replication_factor = 1  # ⚠️ No fault tolerance
nodes_per_region = 1

# Production deployment (recommended)
scylla_replication_factor = 3  # ✅ Survives 1 node failure
nodes_per_region = 3

# High availability deployment
scylla_replication_factor = 5  # ✅ Survives 2 node failures
nodes_per_region = 5
```

**Multi-Region Recommendations:**

```hcl
# Balanced approach
us_east_rf = 3  # Primary region
us_west_rf = 2  # Secondary region

# High availability
us_east_rf = 3  # Primary region
us_west_rf = 3  # Full redundancy
```

### Replication Factor Trade-offs

| RF       | Pros                                                                    | Cons                                              | Use Case                   |
| -------- | ----------------------------------------------------------------------- | ------------------------------------------------- | -------------------------- |
| **RF=1** | • Lowest cost<br>• Fastest writes                                       | • No fault tolerance<br>• Data loss if node fails | Development only           |
| **RF=3** | • Good fault tolerance<br>• Balanced performance<br>• Industry standard | • 3x storage cost<br>• Moderate write latency     | Production (recommended)   |
| **RF=5** | • High availability<br>• Survives 2 node failures                       | • 5x storage cost<br>• Higher write latency       | Mission-critical workloads |

### Node Distribution Architecture

**Single Region Setup:**

```
Region: us-east-1 (Datacenter: us-east)
├── ScyllaDB Node 1 (AZ-a) ──┐
├── ScyllaDB Node 2 (AZ-b) ──┼── RF=3 (each piece of data stored on all 3 nodes)
└── ScyllaDB Node 3 (AZ-c) ──┘

Keyspace: jupiter_local_ddc_us_east_1
Replication: {'class': 'NetworkTopologyStrategy', 'us-east': 3}
```

**Multi-Region Setup:**

```
Region: us-east-1 (Datacenter: us-east)     Region: us-west-2 (Datacenter: us-west)
├── ScyllaDB Node 1 (AZ-a)                  ├── ScyllaDB Node 1 (AZ-a)
├── ScyllaDB Node 2 (AZ-b)                  └── ScyllaDB Node 2 (AZ-b)
└── ScyllaDB Node 3 (AZ-c)

Keyspaces:
├── jupiter_local_ddc_us_east_1: {'us-east': 3, 'us-west': 0}  # Primary region data
├── jupiter_local_ddc_us_west_2: {'us-west': 2, 'us-east': 0}  # Secondary region data
└── jupiter (global): {'us-east': 3, 'us-west': 2}             # Shared metadata
```

### EKS vs ScyllaDB Independence

**EKS Nodes (DDC Application):**

- Run DDC application pods
- Handle HTTP API requests
- Can scale independently
- Typically 2-5 nodes

**ScyllaDB Nodes (Database):**

- Store cache metadata
- Handle database queries
- Scale based on data volume
- Typically 3-5 nodes

**Example Independent Scaling:**

```hcl
# EKS Configuration
eks_node_groups = {
  system_nodes = 2   # Kubernetes system pods
  worker_nodes = 3   # DDC application pods
  nvme_nodes = 2     # High-performance caching
}

# ScyllaDB Configuration (independent)
scylla_nodes = 5           # Database cluster size
scylla_replication_factor = 3  # Data copies per datacenter
```

### Keyspace vs Datacenter Naming

**Critical Distinction:**

- **Keyspace names**: Can be descriptive (e.g., `jupiter_local_ddc_us_east_1`)
- **Datacenter names**: Must match ScyllaDB configuration (e.g., `us-east`)
- **Replication map**: Uses datacenter names, not keyspace names

```sql
-- ✅ CORRECT: Keyspace name is descriptive, replication uses datacenter names
CREATE KEYSPACE jupiter_local_ddc_us_east_1 WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'us-east': 3,  -- Must match actual datacenter name
  'us-west': 2   -- Must match actual datacenter name
};

-- ❌ INCORRECT: Using keyspace name in replication
CREATE KEYSPACE jupiter_local_ddc_us_east_1 WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'jupiter_local_ddc_us_east_1': 3  -- Wrong! This is keyspace name, not datacenter
};
```

### DDC Client Access Flow

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│ Unreal Engine       │───▶│ Load Balancer        │───▶│ DDC Application Pod │
│ (Developer Machine) │    │ us-east-1.ddc.com   │    │ (EKS Cluster)       │
│                     │    │ Bearer Token Auth    │    │                     │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
                                     │                            │
                                     │                            ▼
┌─────────────────────┐              │                  ┌─────────────────────┐
│ S3 Bucket           │◀─────────────┼──────────────────│ ScyllaDB Cluster    │
│ (Cache Assets)      │              │                  │ (Metadata Storage)  │
│ us-east-1 bucket    │              │                  │ jupiter_local_ddc_* │
└─────────────────────┘              │                  └─────────────────────┘
                                     │
                            ┌─────────────────────┐
                            │ Multi-Region Sync   │
                            │ us-west-2.ddc.com  │
                            │ (Cross-region)      │
                            └─────────────────────┘
```

**Access Flow Details:**

1. **Developer** makes API call to regional DDC endpoint
2. **Load Balancer** validates bearer token and routes to healthy DDC pod
3. **DDC Application** queries ScyllaDB for cache metadata
4. **ScyllaDB** returns metadata (cache location, hash, etc.)
5. **DDC Application** retrieves/stores actual cache data in S3
6. **Cross-Region Sync** replicates data between regions (if configured)

**DDC Namespace Usage:**

- **Application-level separation**: Different projects can use different namespaces
- **Stored in keyspaces**: Each region's keyspace contains all namespace data
- **Example**: `ddc` namespace in `jupiter_local_ddc_us_east_1` keyspace

```bash
# API calls include namespace in URL
PUT /api/v1/refs/{namespace}/{bucket}/{hash}
GET /api/v1/refs/{namespace}/{bucket}/{hash}

# Examples:
PUT /api/v1/refs/ddc/default/abc123...           # Default DDC namespace
PUT /api/v1/refs/project-a/builds/def456...      # Project-specific namespace
```

## DDC Version Compatibility

### Version 1.2.0 vs 1.3.0 Issue

**IMPORTANT: Use DDC version 1.2.0 - DO NOT use 1.3.0**

Known issue - Configuration Parsing Bug:

- DDC 1.3.0 has stricter configuration validation that fails to read ScyllaDB settings
- Error: `'LocalDatacenterName' field is required` and `'LocalKeyspaceSuffix' field is required`
- **Impact**: DDC pods crash in `CrashLoopBackOff` state
- **Status**: Configuration is present and correct, but DDC 1.3.0 cannot parse it

### Recommended Configuration

```hcl
ddc_services_config = {
  unreal_cloud_ddc_version = "1.2.0"  # ✅ RECOMMENDED - Stable and tested
  # unreal_cloud_ddc_version = "1.3.0"  # ❌ AVOID - Has configuration parsing bugs
}
```

## Advanced Configuration Patterns

### Map-based Namespace Configuration

The module uses map-based namespace configuration for better control and referencing:

```hcl
ddc_application_config = {
  namespaces = {
    "default" = {
      description      = "Default DDC namespace"
      prevent_deletion = false
      deletion_policy  = "retain"
    }
    "production" = {
      description      = "Production game builds"
      prevent_deletion = true
      deletion_policy  = "retain"
    }
  }
}
```

**Benefits over list-based approach:**
- Better referencing and lookup
- Clearer configuration intent
- Easier validation and error handling

### External NLB Integration Support

The module supports bring-your-own load balancer with automatic Unix socket configuration overrides:

```hcl
# Automatic NGINX disable for external NLB
set {
  name  = "nginx.enabled"
  value = "false"
}

set {
  name  = "nginx.useDomainSockets"
  value = "false"
}

# Kestrel HTTP configuration override
set {
  name  = "env[0].name"
  value = "ASPNETCORE_URLS"
}

set {
  name  = "env[0].value"
  value = "http://0.0.0.0:80"
}
```

### Robust Retry Logic

Configurable DDC initialization detection with comprehensive error handling:

```hcl
ssm_retry_config = {
  max_attempts           = 20
  retry_interval_seconds = 30
  initial_delay_seconds  = 60
}
```

**Implementation**: 20 attempts × 30s intervals = 10 minutes maximum wait time for DDC initialization.

## Network Architecture Decisions

### Private-First Design

**Design Principle**: All services deployed in private subnets with controlled access through load balancers.

**Rationale**: 
- Reduces attack surface
- Follows AWS security best practices
- Enables fine-grained access control
- Supports both internal and external access patterns

### NLB-First Strategy

**Design Principle**: All traffic routed through Network Load Balancers.

**Benefits**:
- Consistent access patterns
- SSL termination at load balancer
- Health check integration
- Regional DNS endpoint support

### Regional DNS Endpoints

**Pattern**: `us-east-1.ddc.example.com` format

**Rationale**:
- Explicit region selection for developers
- Easy debugging and troubleshooting
- Simple DNS management
- Optimal routing without complex geo-DNS

## Automatic Keyspace Replication Fixes

### DDC SimpleStrategy Bug

**Issue**: DDC creates keyspaces with `SimpleStrategy` replication, which doesn't work properly in multi-region deployments.

**Solution**: SSM automation that corrects replication strategy to `NetworkTopologyStrategy`.

**Implementation**:
```sql
-- DDC creates (incorrect):
CREATE KEYSPACE jupiter WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};

-- Module fixes to (correct):
ALTER KEYSPACE jupiter WITH replication = {'class': 'NetworkTopologyStrategy', 'us-east': 3, 'us-west': 2};
```

## Container Integration Strategy

### ECR Pull-Through Cache

**Design Decision**: Use ECR pull-through cache instead of direct GHCR access.

**Benefits**:
- Reduced external dependencies
- Improved image pull performance
- Better integration with AWS IAM
- Consistent with AWS best practices

**Implementation**:
```hcl
resource "aws_ecr_pull_through_cache_rule" "unreal_cloud_ddc_ecr_pull_through_cache_rule" {
  ecr_repository_prefix = "github"
  upstream_registry_url = "ghcr.io"
  credential_arn        = var.ghcr_credentials_secret_manager_arn
}
```

## Known Issues and Workarounds

### VSCode Terraform Extension Validation Errors

**Symptom**: Red squiggly lines under `kubernetes` block in `providers.tf` for Helm provider in examples

**Cause**: Known bug in Terraform Language Server schema caching when `.terraform.lock.hcl` files are present

**GitHub Issue**: [hashicorp/vscode-terraform#2059](https://github.com/hashicorp/vscode-terraform/issues/2059)

**Impact**: Visual only - Terraform CLI works correctly, this is purely a display issue

**Solutions**:
1. **Ignore the error** - Configuration is valid, proceed with deployment
2. **Restart VSCode** - Clears language server cache
3. **Re-initialize**: `rm -rf .terraform .terraform.lock.hcl && terraform init`

**Note**: This is a VSCode extension bug, not an issue with the module configuration. The nested `kubernetes` block in the `helm` provider is correct and required syntax.

## Performance Optimization Decisions

### Instance Type Selection

**ScyllaDB**: `i4i.xlarge` (default)
- High-performance NVMe storage
- Optimized for database workloads
- Good balance of CPU, memory, and storage

**EKS Node Groups**:
- **System**: `m5.large` - General purpose for Kubernetes system pods
- **Worker**: `c5.large` - Compute optimized for DDC application
- **NVME**: `i3en.large` - High-performance storage for caching

### Health Check Configuration

**Target Group Health Checks**:
- **Path**: `/health/live` (not `/health`)
- **Protocol**: HTTP
- **Port**: traffic-port
- **Matcher**: 200

**Rationale**: DDC provides specific health endpoints optimized for load balancer health checks.

## Future Architecture Considerations

### Planned Enhancements

1. **Application Metrics Integration**
   - DDC application metrics (cache hit rates, response times)
   - Prometheus endpoint configuration
   - Custom Grafana dashboards

2. **Advanced Multi-Region Patterns**
   - Active-active configurations
   - Geo-DNS routing
   - Cross-region failover automation

3. **Enhanced Security Features**
   - mTLS between regions
   - Advanced RBAC patterns
   - Audit logging integration

### Migration Considerations

**From Single to Multi-Region**:
- Keyspace replication strategy updates
- DNS endpoint migration
- Bearer token replication setup
- Cross-region network connectivity

**Version Upgrades**:
- DDC application version compatibility
- Kubernetes version alignment
- Provider version requirements