# COMPREHENSIVE STEERING DOCUMENT: Amazon Keyspaces Integration for Unreal Cloud DDC

## Project Overview

**Objective**: Add Amazon Keyspaces as an alternative database backend to ScyllaDB for the Unreal Cloud DDC module, providing users with a choice between self-managed Scylla clusters and fully-managed AWS Keyspaces.

**Timeline**: ~12-15 hours across 4 phases
**Status**: Planning Complete - Ready for Implementation

---

## Keyspace Creation Analysis

### What is a "Keyspace" and How DDC Uses It

**Keyspace Definition**: A keyspace is the top-level namespace in Cassandra/Scylla/Keyspaces - equivalent to a "database" in SQL terms. It contains tables and defines replication strategy.

**DDC Usage**: DDC uses keyspaces to store metadata about cached objects (file paths, checksums, expiration times, etc.). The actual cache data (large files) is stored in S3, but the keyspace tracks what's cached and where.

### Current Scylla Keyspace Creation Process

1. **Infrastructure**: Terraform creates Scylla EC2 instances
2. **DDC Initialization**: DDC pods start and connect to Scylla
3. **Automatic Keyspace Creation**: DDC automatically creates keyspace `jupiter_local_ddc_${region_suffix}` on first connection
4. **SSM Post-Processing**: SSM document runs to fix replication strategy for multi-region setups

### Amazon Keyspaces Creation Process

1. **Infrastructure**: Terraform creates Keyspaces keyspace directly
2. **Table Creation**: Terraform creates required tables (DDC doesn't auto-create in Keyspaces)
3. **DDC Connection**: DDC connects to pre-existing keyspace via IAM authentication
4. **No SSM Needed**: Replication handled by AWS automatically

---

## Current State Analysis

### Existing Architecture
```
ddc_infra_config != null → Creates EKS + Scylla infrastructure
scylla_topology_config → Configures Scylla nodes and replication
DDC → Auto-creates keyspace on first connection
SSM → Fixes replication strategy post-deployment
```

### Current Files Requiring Updates
- `variables.tf` - Rename scylla_topology_config → scylla_config
- `main.tf` - Update conditional logic for ddc_infra_config
- `modules/ddc-infra/` - Add Keyspaces resources alongside Scylla
- `modules/ddc-services/` - Update DDC connection configuration
- `locals.tf` - Update database connection logic
- `examples/` - Create Keyspaces variants

### Scylla vs Amazon Keyspaces Mapping

| **Scylla Concept** | **Amazon Keyspaces Equivalent** | **DDC Usage** |
|-------------------|----------------------------------|---------------|
| **Keyspace** | **Keyspace** | Schema container (e.g., `jupiter_local_ddc_us_east_1`) |
| **Datacenter** | **Region** | Geographic distribution unit |
| **Replication Factor** | **Multi-Region Replication** | Data redundancy across regions |
| **Node Count** | **N/A (Serverless)** | Keyspaces auto-scales |
| **Private DNS** | **Public Endpoint** | Connection method |
| **CQL Port 9042** | **CQL Port 9142** | Connection port |
| **Username/Password** | **IAM Authentication** | Authentication method |
| **SSM Keyspace Setup** | **Terraform Resource Creation** | Provisioning method |

---

## Target State Architecture

### New Dual-Backend Architecture
```
# Mutual exclusivity
scylla_config != null XOR amazon_keyspaces_config != null

# Conditional infrastructure
(scylla_config != null || amazon_keyspaces_config != null) → ddc_infra_config created

# Database-specific resources
scylla_config != null → Scylla EC2, Security Groups, SSM docs
amazon_keyspaces_config != null → Keyspaces, Tables, IAM roles

# DDC services configuration
ddc_services_config → Database connection based on backend type
```

---

## Implementation Plan

### **Phase 1: Variable Restructuring & Validation** (2-3 hours)

**Tasks:**
1. Rename `scylla_topology_config` → `scylla_config` in variables.tf
2. Add new `amazon_keyspaces_config` variable
3. Add mutual exclusivity validation
4. Update all references to old variable name
5. Update centralized logging to support `keyspaces` component

**Deliverables:**
- Updated variables.tf with both database configs
- Validation preventing both backends being configured
- All existing references updated

**Files Modified:**
- `variables.tf`
- `main.tf`
- `locals.tf`
- `modules/ddc-infra/main.tf`
- `modules/ddc-services/main.tf`

---

### **Phase 2: Keyspaces Infrastructure in ddc-infra Module** (4-5 hours)

**Tasks:**
1. Add Keyspaces resources to `modules/ddc-infra/`
2. Create IAM roles/policies for Keyspaces access
3. Implement multi-region Keyspaces replication
4. Add conditional logic for Scylla vs Keyspaces creation
5. Update module outputs for both database types

**Deliverables:**
- Keyspaces keyspace and table resources
- IAM authentication setup
- Multi-region replication configuration
- Conditional resource creation logic

**Files Modified:**
- `modules/ddc-infra/main.tf`
- `modules/ddc-infra/keyspaces.tf` (new)
- `modules/ddc-infra/iam.tf`
- `modules/ddc-infra/outputs.tf`
- `modules/ddc-infra/variables.tf`

---

### **Phase 3: DDC Services Integration** (3-4 hours)

**Tasks:**
1. Update main module conditional logic for ddc_infra_config
2. Modify DDC services configuration for both database types
3. Update connection strings and authentication methods
4. Add database-specific outputs and locals
5. Update SSM logic to only run for Scylla

**Deliverables:**
- Updated main.tf with dual-backend support
- DDC Helm configuration for both database types
- Proper connection endpoints and authentication

**Files Modified:**
- `main.tf`
- `locals.tf`
- `modules/ddc-services/main.tf`
- `modules/ddc-services/variables.tf`
- `ssm.tf`

---

### **Phase 4: Examples & Documentation** (2-3 hours)

**Tasks:**
1. Update existing single-region example to use Keyspaces by default
2. Update existing multi-region example to use Keyspaces by default
3. Create new Scylla variants of both examples
4. Add validation tests for mutual exclusivity
5. Update README to mention both database support

**Deliverables:**
- 4 total examples (2 Keyspaces, 2 Scylla)
- Updated README mentioning dual database support
- Terraform validation tests

**Files Modified:**
- `examples/single-region-basic/` (convert to Keyspaces)
- `examples/multi-region-basic/` (convert to Keyspaces)
- `examples/single-region-scylla/` (new)
- `examples/multi-region-scylla/` (new)
- `README.md`

---

## Technical Implementation Details

### New Variable Structure

```hcl
variable "scylla_config" {
  type = object({
    current_region = object({
      datacenter_name    = optional(string, null)
      keyspace_suffix    = optional(string, null)
      replication_factor = optional(number, 3)
      node_count        = optional(number, 3)
    })
    peer_regions = optional(map(object({
      datacenter_name    = optional(string, null)
      replication_factor = optional(number, 2)
    })), {})
    enable_cross_region_replication = optional(bool, true)
    keyspace_naming_strategy       = optional(string, "region_suffix")
  })
  default = null
}

variable "amazon_keyspaces_config" {
  type = object({
    current_region = object({
      keyspace_name = optional(string, "unreal_cloud_ddc")
      billing_mode  = optional(string, "PAY_PER_REQUEST")
      point_in_time_recovery = optional(bool, false)
    })
    peer_regions = optional(map(object({
      replication_enabled = optional(bool, true)
    })), {})
    enable_cross_region_replication = optional(bool, true)
  })
  default = null
}
```

### Mutual Exclusivity Validation

```hcl
validation {
  condition = (var.scylla_config != null) != (var.amazon_keyspaces_config != null)
  error_message = "Exactly one database backend must be configured: either scylla_config OR amazon_keyspaces_config, not both."
}
```

### Database Connection Logic

```hcl
locals {
  database_type = var.scylla_config != null ? "scylla" : "keyspaces"
  
  database_connection = var.scylla_config != null ? {
    host = "scylla.${aws_route53_zone.private.name}"
    port = 9042
    auth_type = "credentials"
  } : {
    host = "cassandra.${var.region}.amazonaws.com"
    port = 9142
    auth_type = "iam"
  }
}
```

### Key Differences Implementation

1. **Keyspaces is serverless** - no node management needed
2. **Different port**: Scylla uses 9042, Keyspaces uses 9142
3. **Authentication**: Scylla uses credentials, Keyspaces uses IAM
4. **Connection**: Scylla via private DNS, Keyspaces via public endpoint
5. **SSM automation**: Still needed for DDC namespace initialization, not keyspace creation

---

## Risk Assessment & Mitigation

### Risks
1. **Breaking Changes**: Renaming scylla_topology_config
2. **Complex Conditional Logic**: Multiple database backends
3. **Authentication Differences**: Credentials vs IAM

### Mitigation
1. **Comprehensive Testing**: Validate both backends independently
2. **Clear Documentation**: Examples for both database types
3. **Gradual Rollout**: Phase-by-phase implementation with validation

---

## Success Criteria

- [ ] Both Scylla and Keyspaces backends work independently
- [ ] Mutual exclusivity properly enforced
- [ ] Multi-region support for both backends
- [ ] All existing functionality preserved
- [ ] Examples demonstrate both database types

---

## Phase Completion Tracking

### Phase 1: Variable Restructuring & Validation
- [ ] Rename scylla_topology_config → scylla_config
- [ ] Add amazon_keyspaces_config variable
- [ ] Add mutual exclusivity validation
- [ ] Update all variable references
- [ ] Update centralized logging

### Phase 2: Keyspaces Infrastructure
- [ ] Add Keyspaces resources to ddc-infra
- [ ] Create IAM roles/policies
- [ ] Implement multi-region replication
- [ ] Add conditional creation logic
- [ ] Update module outputs

### Phase 3: DDC Services Integration
- [ ] Update main module conditional logic
- [ ] Modify DDC services configuration
- [ ] Update connection strings
- [ ] Add database-specific outputs
- [ ] Update SSM logic

### Phase 4: Examples & Documentation
- [ ] Convert existing examples to Keyspaces
- [ ] Create Scylla example variants
- [ ] Add validation tests
- [ ] Update README
- [ ] Validate all examples work

---

**Document Created**: $(date)
**Next Action**: Begin Phase 1 Implementation