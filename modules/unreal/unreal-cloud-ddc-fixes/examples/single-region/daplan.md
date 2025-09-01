# Region Family Validation Plan

## Overview

Implement simple region family validation to prevent ScyllaDB datacenter name collisions while keeping the codebase simple and maintainable.

## How It Works

### The Problem
ScyllaDB's EC2Snitch automatically strips AZ numbers from region names:
- `us-east-1` → datacenter: `us-east`
- `us-east-2` → datacenter: `us-east` 
- **COLLISION!** Both regions think they're in the same datacenter

### The Solution
**Validate that multi-region deployments use different region families:**
- ✅ `us-east-1` + `us-west-2` → datacenters: `us-east` + `us-west` (no collision)
- ❌ `us-east-1` + `us-east-2` → datacenters: `us-east` + `us-east` (collision blocked)

### User Guidance
The validation provides clear error messages guiding users toward sensible geographic distribution:
```
Multi-region should use different geographic areas (us-east-1 + us-west-2, not us-east-1 + us-east-2) for meaningful latency benefits
```

## Implementation Steps

### Step 1: Add Region Family Validation
**Location:** `examples/single-region/variables.tf`

```hcl
variable "regions" {
  type        = list(string)
  description = "List of AWS regions for DDC deployment"
  default     = ["us-east-1"]
  
  validation {
    condition     = length(var.regions) >= 1 && length(var.regions) <= 2
    error_message = "Currently only 1-2 regions supported"
  }
  
  validation {
    condition     = length(var.regions) == length(distinct(var.regions))
    error_message = "All regions must be unique"
  }
  
  validation {
    condition = length(var.regions) <= 1 || length(distinct([for r in var.regions : regex("^([^-]+-[^-]+)", r)[0]])) == length(var.regions)
    error_message = "Multi-region deployments must use different region families (e.g., us-east-1 + us-west-2, not us-east-1 + us-east-2) for meaningful latency benefits and to avoid ScyllaDB datacenter name collisions"
  }
}
```

### Step 2: Update DDC Services Datacenter Logic
**Location:** `modules/ddc-services/locals.tf`

```hcl
locals {
  unreal_cloud_ddc_helm_config = {
    # Always use EC2Snitch datacenter format (strip AZ number)
    region = var.region != null ? regex("^([^-]+-[^-]+)", var.region)[0] : ""
    # us-east-1 → us-east, us-west-2 → us-west
  }
}
```

### Step 3: Keep ScyllaDB Simple
**Location:** `modules/ddc-infra/locals.tf`

```hcl
# Remove all conditional snitch logic - always use EC2Snitch default
scylla_user_data_primary_node = jsonencode({
  "scylla_yaml": {
    "cluster_name": local.scylla_variables.scylla-cluster-name
    # No endpoint_snitch specified = uses EC2Snitch default
  }
  "start_scylla_on_first_boot": true
})
```

### Step 4: Remove Multi-Region Detection Variables
- Remove `all_deployment_regions` from parent module
- Remove `is_multi_region` from child modules
- Remove conditional snitch logic
- Remove SSM datacenter configuration

## Benefits

### Simplicity
- ✅ **No complex snitch configuration**
- ✅ **No user_data scripts**
- ✅ **No conditional logic**
- ✅ **Uses ScyllaDB defaults**

### Reliability
- ✅ **Proven EC2Snitch behavior**
- ✅ **Matches cwwalb working approach**
- ✅ **No version compatibility issues**
- ✅ **No networking changes required**

### User Experience
- ✅ **Clear validation messages**
- ✅ **Guides toward sensible combinations**
- ✅ **Prevents deployment failures**
- ✅ **Works with existing VPC peering**

### Real-World Alignment
- ✅ **Encourages geographic distribution**
- ✅ **Meaningful latency improvements**
- ✅ **Cost-effective multi-region**
- ✅ **Standard industry practice**

## Supported Combinations

### Valid Multi-Region Pairs
- `us-east-1` + `us-west-2` (East Coast + West Coast)
- `us-east-1` + `eu-west-1` (US + Europe)
- `us-west-2` + `ap-southeast-1` (US + Asia)
- `eu-west-1` + `ap-southeast-2` (Europe + Australia)

### Blocked Combinations
- `us-east-1` + `us-east-2` (same region family)
- `us-west-1` + `us-west-2` (same region family)
- `eu-west-1` + `eu-west-2` (same region family)

## Migration Path

### From Current Broken State
1. **Apply validation** - prevents new problematic deployments
2. **Existing deployments** continue working if using valid combinations
3. **Invalid combinations** get clear error messages on next apply

### Future Enhancement
If users absolutely need same-family regions:
1. **Add advanced mode** with GossipingPropertyFileSnitch
2. **Require explicit opt-in** with warnings about complexity
3. **Keep simple mode as default**

## Testing Strategy

### Phase 1: Single Region
- Test with `regions = ["us-east-1"]`
- Verify no changes to existing behavior
- Confirm DDC connects to `us-east` datacenter

### Phase 2: Valid Multi-Region
- Test with `regions = ["us-east-1", "us-west-2"]`
- Verify both regions use correct datacenter names
- Confirm cross-region replication works

### Phase 3: Invalid Combinations
- Test with `regions = ["us-east-1", "us-east-2"]`
- Verify validation blocks deployment
- Confirm error message is clear and helpful

## Implementation Timeline

### Immediate (Phase 1)
- Add region family validation
- Update DDC datacenter logic
- Remove complex conditional code
- Test single region deployment

### Short Term (Phase 2)
- Test valid multi-region combinations
- Update documentation with supported pairs
- Validate with existing VPC peering setup

### Future (Phase 3)
- Consider advanced mode for same-family regions
- Evaluate user feedback and requests
- Implement GossipingPropertyFileSnitch if needed

## Risk Mitigation

### Backward Compatibility
- ✅ **Single region unchanged** - existing deployments continue working
- ✅ **Valid multi-region unchanged** - `us-east-1` + `us-west-2` still works
- ✅ **Only blocks invalid combinations** - prevents broken deployments

### User Communication
- ✅ **Clear error messages** explain why combinations are blocked
- ✅ **Suggest alternatives** in validation messages
- ✅ **Document supported combinations** in README

### Rollback Plan
- ✅ **Validation is additive** - can be removed without breaking existing deployments
- ✅ **No infrastructure changes** - purely configuration validation
- ✅ **Easy to revert** if issues discovered