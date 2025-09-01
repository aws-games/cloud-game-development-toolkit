# Region Split Implementation Plan

## Challenge

The current DDC module has hardcoded assumptions about single vs multi-region deployments, leading to:

### ScyllaDB Snitch Issues
- **EC2Snitch** (default): Automatically strips AZ numbers (`us-east-1` → `us-east`)
- **Multi-region problem**: Both `us-west-1` and `us-west-2` become `us-west` (collision)
- **DDC expects**: Full region names with underscores (`us_east_1`)
- **Result**: Datacenter name mismatches causing DDC connection failures

### Configuration Nuances
- **Single region**: Can use EC2Snitch + strip `-1` for datacenter matching
- **Multi-region**: Must use PropertyFileSnitch + full region names to avoid collisions
- **Migration scenarios**: Users want to go single → multi → single seamlessly
- **Current state**: Manual configuration required, no auto-detection

### Current Problems
1. DDC pods crash with `Datacenter us_east_1 does not match any of the nodes, available datacenters: us-east`
2. No automatic detection of single vs multi-region deployments
3. Hardcoded snitch configurations
4. Manual datacenter name management required

## Solution Plan

### Step 1: Add Regions Variable
- Add `var.regions` list to example level
- Validation: 1-2 regions only (for now)
- Replace hardcoded `local.region` references

### Step 2: Update Module Interface
- Add `all_deployment_regions` parameter to ddc-infra module
- Add `all_regions` parameter to ddc-services module
- Pass regions list from example to modules

### Step 3: Implement Conditional Snitch Logic
**In ddc-infra module:**
- `length(var.all_deployment_regions) == 1` → `Ec2Snitch`
- `length(var.all_deployment_regions) > 1` → `PropertyFileSnitch`
- Update ScyllaDB user_data JSON accordingly

### Step 4: Implement Conditional Datacenter Naming
**In ddc-services module:**
- Single region: `regex("^([^-]+-[^-]+)", var.region)[0]` → `us-east`
- Multi-region: `replace(var.region, "-", "_")` → `us_east_1`
- Auto-detection based on `length(var.all_regions)`

### Step 5: Update SSM Configuration
- Make SSM datacenter configuration conditional
- Only run for multi-region deployments
- Use PropertyFileSnitch settings

### Step 6: Test Migration Scenarios
- Single region: `regions = ["us-east-1"]`
- Multi-region: `regions = ["us-east-1", "us-west-2"]`
- Back to single: Remove second region

## Implementation Steps

### Phase 1: Example Level Changes
1. Add `variables.tf` with `var.regions`
2. Update `locals.tf` to use `var.regions[0]` instead of hardcoded region
3. Update module calls to pass `all_deployment_regions`

### Phase 2: Module Interface Updates
1. Add `all_deployment_regions` variable to ddc-infra
2. Add `all_regions` variable to ddc-services
3. Update variable descriptions and validations

### Phase 3: Conditional Logic Implementation
1. Update ddc-infra `locals.tf` for conditional snitch
2. Update ddc-services `locals.tf` for conditional datacenter naming
3. Make SSM datacenter config conditional

### Phase 4: Testing
1. Apply with single region - should work without changes
2. Test adding second region - should auto-configure multi-region
3. Test removing second region - should revert to single-region

## Expected Outcomes

### Single Region Deployment
- Uses EC2Snitch (no infrastructure changes)
- DDC connects to `us-east` datacenter
- No SSM datacenter configuration needed
- Seamless transition from current state

### Multi-Region Deployment
- Uses PropertyFileSnitch
- DDC connects to `us_east_1`, `us_west_2` datacenters
- SSM configures ScyllaDB datacenter names
- No datacenter name collisions

### Migration Flexibility
- Users can change `regions` variable to scale up/down
- Module automatically detects and configures appropriately
- No manual snitch or datacenter configuration required
- Infrastructure adapts without destruction/recreation

## Risk Mitigation

### Backward Compatibility
- Single region deployments remain unchanged
- Existing infrastructure continues working
- No breaking changes to module interface

### Rollback Plan
- Changes are additive (new variables, conditional logic)
- Can revert by removing new variables
- Infrastructure state remains intact

### Testing Strategy
- Start with single region (current working state)
- Incrementally add multi-region support
- Validate each step before proceeding