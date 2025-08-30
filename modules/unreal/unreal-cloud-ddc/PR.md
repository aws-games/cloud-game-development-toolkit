**🚧 DRAFT PR - DO NOT MERGE UNTIL DRAFT STATUS HAS BEEN REMOVED AS WELL AS THIS LINE 🚧**
**Issue number:**
#[ISSUE_NUMBER]

## Summary

This PR implements **Major DDC Module Architecture Consolidation** that eliminates circular dependencies, implements robust cleanup mechanisms, and establishes the gold standard for all CGD Toolkit modules. The fragmented infrastructure/applications split has been replaced with a unified, production-ready conditional submodule architecture.

## Problem Statement

### Previous Architecture
The DDC module was split across separate `unreal-cloud-ddc-infra/` and `unreal-cloud-ddc-intra-cluster/` modules, which presented some architectural challenges:

```
modules/
├── unreal-cloud-ddc-infra/        # EKS + nodes + ScyllaDB + S3 (deployed first)
└── unreal-cloud-ddc-intra-cluster/ # EKS addons + Helm + references NLBs (deployed second)
```

**Areas for Improvement:**
1. **Circular Dependencies**: Applications module created AWS infrastructure (NLBs via Load Balancer Controller) that it then tried to reference in the same module
2. **Cross-Module Resource Creation**: Applications module shouldn't create AWS infrastructure
3. **Unpredictable Timing**: When does the NLB get created vs referenced?
4. **Destroy Order Issues**: Which module destroys the NLB? Frequent orphaned resources
5. **Multi-Region Complexity**: Complex cross-region deployment coordination
6. **IP Access Dependencies**: Destroy operations failed when user IP changed since deployment

### User Impact
- Occasional destroy failures with orphaned ENIs and Load Balancers
- Deployment timing dependencies that could be simplified
- Multi-region setup requiring manual coordination
- Error messages that could be more helpful

## Solution Overview

### New Consolidated Architecture
Following the successful Perforce module pattern, implemented conditional submodule architecture:

```
modules/unreal-cloud-ddc/
├── main.tf                    # Conditional submodule orchestration
├── modules/
│   ├── ddc-infra/            # Infrastructure: EKS + ScyllaDB + NLB + Kubernetes
│   ├── ddc-monitoring/       # Monitoring: ScyllaDB monitoring + ALB
│   └── ddc-services/         # Services: Helm charts only (no AWS resources)
└── assets/
    ├── media/diagrams/       # Architecture documentation
    └── submodules/           # Submodule-specific assets
        ├── ddc-infra/
        ├── ddc-monitoring/
        └── ddc-services/
```

### Key Architectural Principles
1. **Conditional Submodules**: `count = var.config != null ? 1 : 0` pattern
2. **Deterministic Infrastructure**: All AWS resources created via Terraform
3. **Clean Separation**: Infrastructure vs Applications vs Monitoring
4. **Multi-Region Ready**: Multiple parent module instances approach
5. **User Choice**: Flexible deployment patterns (infrastructure-only, full-stack, etc.)

## Major Changes

### 1. Eliminated Circular Dependencies
**Before:**
```hcl
# applications module creating AND referencing NLB
enable_aws_load_balancer_controller = true  # Creates NLB
data "aws_lb" "ddc_nlb" {
  depends_on = [helm_release.ddc]  # Circular dependency!
}
```

**After:**
```hcl
# ddc-infra creates deterministic NLB
resource "aws_lb" "ddc_nlb" {
  name_prefix = "${var.project_prefix}-"
  # ... predictable configuration
}

# ddc-services uses ClusterIP + target group annotation
service:
  type: ClusterIP
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-target-group-arn: ${target_group_arn}
```

### 2. Implemented Conditional Submodule Pattern
```hcl
# Users can deploy only what they need
module "ddc_infra" {
  source = "./modules/ddc-infra"
  count  = var.ddc_infra_config != null ? 1 : 0
}

module "ddc_monitoring" {
  source = "./modules/ddc-monitoring"
  count  = var.ddc_monitoring_config != null ? 1 : 0
}

module "ddc_services" {
  source = "./modules/ddc-services"
  count  = var.ddc_services_config != null ? 1 : 0
}
```

### 3. Enhanced Multi-Region Support
**Before:** Complex internal multi-region logic with provider aliases
**After:** Multiple parent module instances (one per region)

```hcl
# Primary region
module "ddc_primary" {
  source = "../../"
  ddc_infra_config = {
    region = "us-east-1"
    create_seed_node = true
  }
}

# Secondary region
module "ddc_secondary" {
  source = "../../"
  ddc_infra_config = {
    region = "us-west-2"
    create_seed_node = false
    existing_scylla_seed = module.ddc_primary.scylla_seed_ip
  }
}
```

### 4. Robust Cleanup & Destroy Safety
**Added automatic Helm cleanup** with comprehensive error handling:
```hcl
# Configurable cleanup behavior
ddc_services_config = {
  auto_cleanup = true  # Default: automatic cleanup
  # auto_cleanup = false  # Manual cleanup for advanced users
}
```

**Enhanced error messages** with troubleshooting guidance:
- IP access validation with specific remediation steps
- Links to documentation sections
- Clear explanation of destroy dependencies
- Configurable timeouts for different environments

### 5. Improved Asset Organization & Examples Enhancement
**Before:** File placement that could be more consistent
**After:** Standardized structure with clear separation:
```
assets/
├── media/diagrams/           # Architecture diagrams
└── submodules/              # Clear submodule boundary
    ├── ddc-infra/          # Infrastructure-specific assets
    ├── ddc-monitoring/     # Monitoring-specific assets
    └── ddc-services/       # Service-specific assets
        ├── unreal_cloud_ddc_consolidated.yaml    # Single chart for all deployments
        ├── unreal_cloud_ddc_single_region.yaml  # Backup/legacy
        └── unreal_cloud_ddc_multi_region.yaml   # Backup/legacy

examples/                    # User-facing tutorials (moved from samples/)
├── single-region/          # Complete working example
└── multi-region/           # Multi-region deployment pattern
```

**Samples → Examples Enhancement:**
- Moved from "samples" to "examples" for clarity
- Enhanced with complete, working tutorials
- Added comprehensive documentation with step-by-step instructions
- Provided tested configurations that users can copy and modify

## Benefits

### For Users
1. **Reliable Destroys**: No more orphaned resources or IP access issues
2. **Flexible Deployment**: Deploy only needed components (infra-only, monitoring, services)
3. **Better Error Messages**: Clear troubleshooting guidance with documentation links
4. **Multi-Region Simplified**: Clean two-instance pattern vs complex internal logic
5. **User Choice**: Automatic vs manual cleanup based on preferences

### For Developers
1. **Clean Architecture**: Clear module boundaries and dependencies
2. **Maintainable Code**: Standardized structure following established patterns
3. **Testable Components**: Each submodule can be tested independently
4. **Extensible Design**: Easy to add new components or regions

### For Operations
1. **Predictable Infrastructure**: All AWS resources created deterministically
2. **Cost Control**: Skip expensive components in secondary regions
3. **Staged Rollouts**: Deploy infrastructure first, applications later
4. **Clear Dependencies**: Explicit dependency flow and coordination

## Usage Examples

### Infrastructure Only
```hcl
module "ddc" {
  source = "path/to/module"
  
  ddc_infra_config = {
    # EKS + ScyllaDB + NLB configuration
  }
  # No monitoring or services - just infrastructure
}
```

### Full Stack Single Region
```hcl
module "ddc" {
  source = "path/to/module"
  
  ddc_infra_config = { /* ... */ }
  ddc_monitoring_config = { /* ... */ }
  ddc_services_config = { 
    auto_cleanup = true  # Automatic Helm cleanup
  }
}
```

### Multi-Region Deployment
```hcl
# Primary region
module "ddc_primary" {
  source = "path/to/module"
  ddc_infra_config = { create_seed_node = true }
  ddc_monitoring_config = { /* ... */ }
  ddc_services_config = { /* ... */ }
}

# Secondary region
module "ddc_secondary" {
  source = "path/to/module"
  ddc_infra_config = { 
    create_seed_node = false
    existing_scylla_seed = module.ddc_primary.scylla_seed_ip
  }
  ddc_services_config = {
    ddc_replication_region_url = module.ddc_primary.nlb_dns_name
  }
  # No monitoring in secondary region (cost optimization)
}
```

## Documentation Enhancements

### Comprehensive README Overhaul
- **Architecture Deep-Dive**: ScyllaDB node mapping, EKS integration, service types
- **Troubleshooting Guide**: Covers creation, update, connection, and deletion issues
- **FAQ Section**: Design decisions, technology choices, operational questions
- **Multi-Region Patterns**: Deployment strategies and coordination mechanisms

### Gold Standard Module Structure
Created `HOW_TO_CONTRIBUTE.md` establishing standards for all CGD Toolkit modules:
- **Directory Structure**: Simple vs complex module patterns
- **File Naming Conventions**: Consistent across all modules
- **Documentation Quality**: Comprehensive guidelines and review processes
- **Design Principles**: When to use submodules, asset organization, etc.

### Enhanced User Experience
- **Audience-Specific Callouts**: Clear visual indicators for DevOps vs Game Developers
- **Streamlined Navigation**: Direct GitHub links for examples to preserve documentation flow
- **Improved Code Organization**: Separate code blocks for better copy-paste experience
- **Terraform Output Integration**: Commands use `terraform output` for actual values
- **Security Best Practices**: Clear distinction between infrastructure and application access
- **Progressive Disclosure**: Basic → Advanced configuration patterns

### Documentation Quality Improvements
- **Removed Outdated Content**: Eliminated incorrect provider configuration and migration examples
- **Fixed Inaccuracies**: Updated all code snippets to match actual module structure
- **Enhanced Troubleshooting**: Comprehensive IP access requirements and destroy procedures
- **Clear Prerequisites**: Epic Games organization access and GitHub credential setup
- **Multi-Region Clarity**: Simplified deployment patterns with working examples**Conditional Deployment Messages**: Optional user feedback during operations
- **Comprehensive Examples**: Infrastructure-only, full-stack, multi-region patterns
- **Clear Configuration**: Well-documented variables with validation and examples

## Breaking Changes

### Variable Structure Changes
**Before:**
```hcl
# Separate modules with complex configuration
module "infrastructure" { /* ... */ }
module "applications" { /* ... */ }
```

**After:**
```hcl
# Unified module with conditional submodules
module "ddc" {
  ddc_infra_config = { /* ... */ }      # Optional
  ddc_monitoring_config = { /* ... */ }  # Optional  
  ddc_services_config = { /* ... */ }    # Optional
}
```

### Migration Path
1. **Update variable structure** to use new conditional config objects
2. **Remove separate module calls** - use single unified module
3. **Update multi-region deployments** to use multiple parent instances
4. **Review cleanup configuration** - set `auto_cleanup` preference

## Testing

### Validated Deployment Patterns
- ✅ **Infrastructure Only**: EKS + ScyllaDB + NLB creation
- ✅ **Full Stack Single Region**: All components working together
- ✅ **Multi-Region**: Cross-region coordination and replication
- ✅ **Conditional Logic**: Proper submodule creation/skipping
- ✅ **Cleanup Mechanisms**: Both automatic and manual cleanup paths

### Regression Testing
- ✅ **No Circular Dependencies**: Clean dependency graph
- ✅ **Deterministic Destroys**: Reliable cleanup without orphaned resources
- ✅ **Multi-Region Coordination**: ScyllaDB cross-region replication
- ✅ **Error Handling**: Comprehensive error scenarios covered

## Future Enhancements

### Planned Improvements
1. **Amazon Keyspaces Support**: Alternative to self-managed ScyllaDB
2. **Existing EKS Cluster Support**: Deploy to existing clusters
3. **Additional Regions**: Easy expansion beyond two regions
4. **Enhanced Monitoring**: Cross-region monitoring consolidation

### Extensibility
The new architecture makes these enhancements straightforward:
- **New submodules** can be added easily
- **Additional deployment patterns** supported via conditional logic
- **Cross-region features** simplified with multiple instance pattern

## Conclusion

This refactor transforms the DDC module from a fragmented, unreliable architecture into a production-ready, enterprise-grade solution. By eliminating circular dependencies, implementing robust cleanup mechanisms, and establishing comprehensive documentation standards, the module now serves as the gold standard for all CGD Toolkit modules.

**Key Achievements:**
- ✅ **Eliminated circular dependencies** and destroy issues
- ✅ **Implemented flexible deployment patterns** following Perforce module success
- ✅ **Enhanced multi-region support** with clean coordination mechanisms  
- ✅ **Established documentation gold standard** for entire toolkit
- ✅ **Improved user experience** with better error handling and guidance
- ✅ **Created maintainable architecture** for long-term sustainability

The module is now production-ready and provides a solid foundation for game development teams deploying Unreal Cloud DDC infrastructure on AWS.