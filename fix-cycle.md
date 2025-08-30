# Terraform Circular Dependency Issue & Resolution

## Problem: Circular Dependency in DDC Module

### Root Cause
The DDC parent module has a circular dependency issue when using Kubernetes and Helm providers:

1. **ddc-infra module** creates EKS cluster AND kubernetes resources (namespace, service account)
2. **Kubernetes provider** needs EKS cluster endpoint to be configured
3. **EKS cluster endpoint** is created by the ddc-infra module

This creates a chicken-and-egg problem:
```
ddc-infra needs kubernetes provider → kubernetes provider needs EKS endpoint → EKS endpoint created by ddc-infra
```

### Error Manifestation
```
Error: Cycle: module.unreal_cloud_ddc.module.ddc_infra.kubernetes_service_account.unreal_cloud_ddc_service_account, 
module.unreal_cloud_ddc.module.ddc_infra.output.service_account (expand), ...
```

### Files Involved
- `modules/unreal/unreal-cloud-ddc/modules/ddc-infra/addons.tf` - Contains kubernetes resources
- `modules/unreal/unreal-cloud-ddc/versions.tf` - Requires kubernetes/helm providers
- Examples trying to configure providers with module outputs

## Resolution: Move Kubernetes Resources

The only viable solution while maintaining the unified parent module approach is to move kubernetes resources from ddc-infra to ddc-services:

**Before (Broken):**
- ddc-infra: EKS cluster + kubernetes resources (namespace, service account) ❌
- ddc-services: Helm charts only

**After (Fixed):**
- ddc-infra: EKS cluster + AWS resources only ✅
- ddc-services: Kubernetes resources + Helm charts ✅

This breaks the circular dependency because:
1. ddc-infra creates EKS cluster (no kubernetes provider needed)
2. Kubernetes provider configured with EKS cluster outputs
3. ddc-services uses configured kubernetes provider for namespace/service account + helm charts

## Current Workaround (Temporary)
Use empty provider configurations and let modules handle provider setup internally:

```hcl
provider "kubernetes" {
  # Empty config - module handles internally
}

provider "helm" {
  # Empty config - module handles internally  
}
```

**Note:** This is a temporary workaround. The proper fix requires moving kubernetes resources as described in the implementation steps.

## Samples Architecture (Working)
The samples avoid this by using separate modules:
- `unreal_cloud_ddc_infra_region_1` - Infrastructure only
- `unreal_cloud_ddc_intra_cluster_region_1` - Services with explicit provider mapping

```hcl
providers = {
  kubernetes = kubernetes.region-1
  helm       = helm.region-1
}
```

## Why Other Options Don't Work

- **Split modules**: Would break existing parent module API
- **Two-step deployment**: Requires users to change their deployment process
- **Internal provider config**: Not possible with current Terraform provider architecture

**Option 2 is the only solution that:**
- Maintains existing parent module interface
- Fixes circular dependency
- Requires minimal user-facing changes

## Implementation Steps

### 1. Move Kubernetes Resources
- Move `kubernetes_namespace` from `ddc-infra/addons.tf` to `ddc-services/`
- Move `kubernetes_service_account` from `ddc-infra/addons.tf` to `ddc-services/`
- Update outputs in ddc-infra to remove kubernetes resource references
- Update ddc-services to create these resources and provide outputs

### 2. Update Module Dependencies
- Remove kubernetes provider requirement from ddc-infra versions.tf
- Ensure ddc-services has kubernetes provider requirement
- Update parent module to pass kubernetes outputs from ddc-services

### 3. Update Documentation (CRITICAL)
**All module documentation currently incorrectly describes ddc-services scope:**

#### Files to Update:
- `modules/unreal/unreal-cloud-ddc/modules/ddc-services/README.md`
- `modules/unreal/unreal-cloud-ddc/README.md` 
- Any architecture diagrams or documentation

#### Current (Incorrect) Description:
> "ddc-services: Handles Helm chart deployments only"

#### New (Correct) Description:
> "ddc-services: Handles Kubernetes resources (namespace, service account) AND Helm chart deployments"

#### Update Required Providers Documentation:
- ddc-infra: Remove kubernetes/helm from required providers
- ddc-services: Add kubernetes to required providers (already has helm)

### 4. Test Multi-Region Scenarios
- Verify single-region deployment still works
- Verify multi-region deployment works without circular dependency
- Test provider configuration with module outputs

### 5. Update Examples
- Update example provider configurations if needed
- Verify examples work with new module structure