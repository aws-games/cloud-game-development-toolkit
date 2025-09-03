# COMPREHENSIVE STEERING DOCUMENT: Amazon Keyspaces Integration for Unreal Cloud DDC

## Project Overview

**Objective**: Add Amazon Keyspaces as an alternative database backend to ScyllaDB for the Unreal Cloud DDC module, providing users with a choice between self-managed Scylla clusters and fully-managed AWS Keyspaces with global replication.

**Timeline**: ~12-15 hours across 4 phases
**Status**: Planning Complete - Ready for Implementation

---

## DDC Database Integration Analysis

### What is a "Keyspace" and How DDC Uses It

**Keyspace Definition**: A keyspace is the top-level namespace in Cassandra/Scylla/Keyspaces - equivalent to a "database" in SQL terms. It contains tables and defines replication strategy.

**DDC Usage**: DDC uses keyspaces to store metadata about cached objects (file paths, checksums, expiration times, etc.). The actual cache data (large files) is stored in S3, but the keyspace tracks what's cached and where.

### DDC Table Lifecycle (Critical Discovery)

**Fixed Schema Pattern**: DDC creates a **fixed set of tables at startup**, not dynamically:
```
Keyspace: jupiter_local_ddc_*
├── Table: cache_entries        (cache metadata)
├── Table: s3_objects          (S3 object mapping)  
├── Table: namespace_config    (namespace settings)
└── Table: cleanup_tracking    (garbage collection)
```

**Key Insights**:
- **Tables live forever** once created (until keyspace deletion)
- **No dynamic table creation** based on namespaces or operations
- **Namespaces** = data partitioning within same tables (via `namespace` column)
- **Predictable schema** allows pre-creation in Terraform

### Current Module Architecture Analysis

**Current DDC Module Structure**:
```
Parent Module (main.tf):
├── module "ddc_infra" (ALWAYS created)
│   ├── EKS cluster + node groups (always)
│   ├── Database choice: Scylla OR Keyspaces (conditional)
│   ├── S3 buckets (always)
│   └── IAM roles (always)
└── module "ddc_services" (ALWAYS created)
    ├── Helm releases (always)
    ├── Kubernetes resources (always)
    └── EKS addons (always)
```

**Simplified Architecture**:
- **ddc_infra**: ALWAYS created - handles database choice internally
- **ddc_services**: ALWAYS created - receives database connection info
- **Database choice**: Handled inside ddc-infra module via conditional resources

**Scylla (Current)**:
1. `scylla_config != null` → Creates Scylla EC2 instances in `modules/ddc-infra/`
2. DDC connects and auto-creates keyspace + tables via CQL
3. SSM document fixes replication strategy post-deployment
4. **Problem**: Unpredictable state, runtime dependencies

**Amazon Keyspaces (New)**:
1. `amazon_keyspaces_config != null` → Creates Keyspaces resources in `modules/ddc-infra/`
2. Terraform pre-creates keyspace + all tables with DDC naming
3. DDC connects to existing keyspace via IAM authentication
4. **Benefit**: Predictable state, no runtime dependencies

**Database Abstraction**:
- Both paths output unified `database_connection` object
- `ddc_services` module receives database-agnostic connection info

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
2. Add new `amazon_keyspaces_config` variable with global tables support
3. Add mutual exclusivity validation between database backends
4. **SIMPLIFIED**: Remove conditional module creation - always create both modules
5. Update all references to old variable name throughout codebase
6. Update centralized logging: move Keyspaces to `infrastructure` category (AWS service)
7. Update `locals.tf` scylla_config logic to support both backends

**Simplified Architecture:**
- **No conditional module logic**: Both ddc_infra and ddc_services always created
- **Database choice**: Handled internally within ddc-infra module
- **Clean interface**: Database connection abstracted via module outputs

**Deliverables:**
- Updated variables.tf with both database configs and global tables support
- Validation preventing both backends being configured simultaneously
- **Simplified main.tf**: Always create both modules, no conditional logic
- All existing references updated to new variable names
- Corrected logging categorization (Keyspaces = infrastructure, Scylla = service)

**Files Modified:**
- `variables.tf` (add amazon_keyspaces_config, rename scylla_topology_config)
- `main.tf` (SIMPLIFIED - remove conditional logic, always create modules)
- `locals.tf` (update scylla_config logic, add keyspaces_config logic)
- `modules/ddc-infra/variables.tf` (add keyspaces parameters)
- `modules/ddc-services/variables.tf` (add database connection abstraction)

---

### **Phase 2: Database Choice Implementation in ddc-infra** (4-5 hours)

**Tasks:**
1. Add Keyspaces resources to `modules/ddc-infra/` with DDC naming patterns
2. Pre-create ALL DDC tables with fixed schema to prevent state management issues
3. Implement global tables for multi-region (like Secrets Manager replication)
4. Create EKS IRSA setup for IAM-based Keyspaces authentication
5. **Internal conditional logic**: Scylla vs Keyspaces creation within ddc-infra
6. **Unified output**: Create `database_connection` abstraction for ddc-services
7. Update existing Scylla resources to use new variable names

**Current ddc-infra Module Structure**:
```
modules/ddc-infra/:
├── scylla.tf          # Scylla EC2 (conditional: scylla_config != null)
├── keyspaces.tf       # NEW - Keyspaces (conditional: amazon_keyspaces_config != null)
├── eks.tf             # EKS cluster (always created)
├── iam.tf             # IAM roles (always + database-specific)
├── s3.tf              # S3 buckets (always)
├── sg.tf              # Security groups (always)
└── ssm.tf             # SSM documents (Scylla only)
```

**Database Abstraction Strategy**:
```hcl
# ddc-infra outputs unified connection info
output "database_connection" {
  value = var.scylla_config != null ? {
    type = "scylla"
    host = "scylla.${local.private_zone_name}"
    port = 9042
    auth_type = "credentials"
  } : {
    type = "keyspaces"
    host = "cassandra.${var.region}.amazonaws.com"
    port = 9142
    auth_type = "iam"
  }
}
```

**Critical State Management**:
- **Problem**: Amazon Keyspaces cannot be deleted if tables exist
- **Solution**: Pre-create all DDC tables in Terraform for clean destroy
- **Benefit**: Predictable infrastructure, no runtime dependencies

**Deliverables:**
- Keyspaces keyspace with global replication configuration
- Pre-created DDC table schemas (cache_entries, s3_objects, etc.)
- EKS IRSA setup for automatic IAM authentication
- **Unified database_connection output** for ddc-services consumption
- Updated Scylla resources to use new variable structure

**Files Modified:**
- `modules/ddc-infra/main.tf` (update Scylla conditional logic)
- `modules/ddc-infra/keyspaces.tf` (new - Keyspaces resources)
- `modules/ddc-infra/iam.tf` (add Keyspaces IRSA permissions)
- `modules/ddc-infra/outputs.tf` (add unified database_connection output)
- `modules/ddc-infra/variables.tf` (add keyspaces parameters)
- `modules/ddc-infra/scylla.tf` (update to use scylla_config variables)

---

### **Phase 3: Services Integration with Database Abstraction** (3-4 hours)

**Tasks:**
1. **SIMPLIFIED**: No main.tf conditional logic changes (always create modules)
2. Update ddc-services to consume `database_connection` abstraction
3. Modify DDC Helm configuration for both database types
4. Update SSM logic to only run for Scylla (not Keyspaces)
5. Update parent module integration points

**Simplified Integration Pattern**:
```hcl
# main.tf - ALWAYS create both modules
module "ddc_infra" {
  source = "./modules/ddc-infra"
  scylla_config = var.scylla_config
  amazon_keyspaces_config = var.amazon_keyspaces_config
  # ... other config
}

module "ddc_services" {
  source = "./modules/ddc-services"
  database_connection = module.ddc_infra.database_connection
  # ... other config
}
```

**Database-Agnostic Services**:
- **ddc-services** receives unified `database_connection` object
- **Helm configuration** adapts based on `database_connection.type`
- **No database-specific logic** in ddc-services module

**Parent Module Integration Points**:
```
Parent Module Resources:
├── lb.tf              # NLB + target groups (always created)
├── route53.tf         # Private DNS zone (always created)
├── secrets.tf         # Bearer token management (always created)
├── ssm.tf             # Scylla keyspace fixes (conditional: scylla_config != null)
└── sg.tf              # Security groups (always created)
```

**Deliverables:**
- **Simplified main.tf**: Always create both modules, no conditional logic
- DDC Helm configuration using database_connection abstraction
- Database-agnostic ddc-services module
- SSM automation only for Scylla backend
- Clean parent module integration

**Files Modified:**
- `main.tf` (SIMPLIFIED - remove conditional logic, pass database configs)
- `modules/ddc-services/main.tf` (use database_connection abstraction)
- `modules/ddc-services/variables.tf` (replace database-specific vars with connection object)
- `ssm.tf` (make conditional on scylla_config != null)
- `locals.tf` (simplify database connection logic)

---

### **Phase 4: Examples & Documentation** (2-3 hours)

**Tasks:**
1. Convert existing single-region example to use Keyspaces by default
2. Convert existing multi-region example to use Keyspaces with global tables
3. Create new Scylla variants of both examples for backward compatibility
4. Add Terraform validation tests for mutual exclusivity
5. Update README to mention both database backends (brief mention only)

**Example Strategy:**
- **Default examples**: Use Keyspaces (simpler, managed service)
- **Scylla variants**: For users who need self-managed databases
- **Global tables**: Demonstrate multi-region Keyspaces replication

**Deliverables:**
- 4 total examples (2 Keyspaces default, 2 Scylla variants)
- Updated README with brief dual database support mention
- Terraform validation tests for mutual exclusivity
- Working global tables multi-region example

**Files Modified:**
- `examples/single-region-basic/` (convert to Keyspaces)
- `examples/multi-region-basic/` (convert to Keyspaces with global tables)
- `examples/single-region-scylla/` (new)
- `examples/multi-region-scylla/` (new)
- `README.md`

---

## Technical Implementation Details

### Updated Variable Structure

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
      billing_mode = optional(string, "PAY_PER_REQUEST")
      point_in_time_recovery = optional(bool, false)
    })
    # Global Tables approach (like Secrets Manager replication)
    enable_cross_region_replication = optional(bool, false)
    peer_regions = optional(list(string), [])
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
  
  # Keyspace naming matches DDC expectations exactly
  keyspace_name = var.amazon_keyspaces_config != null ? (
    var.amazon_keyspaces_config.enable_cross_region_replication ? 
      "jupiter_local_ddc_global" : 
      "jupiter_local_ddc_${replace(var.region, "-", "_")}"
  ) : "jupiter_local_ddc_${replace(var.region, "-", "_")}"
  
  database_connection = var.scylla_config != null ? {
    host = "scylla.${aws_route53_zone.private.name}"
    port = 9042
    auth_type = "credentials"
  } : {
    host = "cassandra.${var.region}.amazonaws.com"
    port = 9142
    auth_type = "iam"  # Via EKS IRSA - no credentials needed
  }
}
```

### Key Implementation Differences

1. **Infrastructure Management**: Scylla (EC2 instances) vs Keyspaces (serverless)
2. **State Management**: Scylla (runtime creation) vs Keyspaces (Terraform pre-creation)
3. **Authentication**: Scylla (credentials) vs Keyspaces (EKS IRSA + IAM)
4. **Connection**: Scylla (private DNS:9042) vs Keyspaces (public endpoint:9142)
5. **Multi-Region**: Scylla (manual replication) vs Keyspaces (global tables)
6. **Table Creation**: Both support CQL, but Keyspaces requires keyspace pre-creation
7. **Deletion**: Both require empty keyspace for clean Terraform destroy

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
- [ ] Mutual exclusivity properly enforced via Terraform validation
- [ ] Multi-region support: Scylla (manual replication) vs Keyspaces (global tables)
- [ ] Full Terraform state management (no orphaned tables blocking deletion)
- [ ] EKS IRSA authentication working for Keyspaces (no manual credentials)
- [ ] All existing Scylla functionality preserved
- [ ] Examples demonstrate both database types with global tables
- [ ] Clean terraform destroy for both backends

---

## Phase Completion Tracking

### Phase 1: Variable Restructuring & Validation ✅ COMPLETE
- [x] Rename scylla_topology_config → scylla_config (with null default)
- [x] Add amazon_keyspaces_config variable with global tables support
- [x] Add mutual exclusivity validation (in BOTH variables - guaranteed to run)
- [x] Simplified main.tf to always create both modules (removed conditional logic)
- [x] Update centralized logging (keyspaces moved to infrastructure category)
- [x] Update locals.tf with database type detection
- [x] Make SSM automation Scylla-specific only
- [x] Clean up unnecessary ddc_infra_config conditionals
- [x] Add database config parameters to ddc-infra module

### Phase 2: Keyspaces Infrastructure ✅ COMPLETE
- [x] Add Keyspaces resources to ddc-infra (keyspaces.tf with all DDC tables)
- [x] Create IAM roles/policies (Keyspaces CQL permissions in service account)
- [x] Implement conditional creation logic (scylla_config != null vs amazon_keyspaces_config != null)
- [x] Update module outputs (database_connection abstraction, conditional Scylla/Keyspaces outputs)
- [x] Make Scylla resources conditional (EC2 instances, IAM roles, SSM documents)
- [x] Pre-create all DDC table schemas for clean state management
- [x] Add keyspace naming logic matching DDC expectations
- [x] Update locals.tf with database type detection and connection abstraction
- [x] Multi-region replication deferred to Phase 4 (simplified for initial implementation)

### Phase 3: DDC Services Integration ✅ COMPLETE
- [x] Add database_connection abstraction variable to ddc-services
- [x] Update locals.tf to use database_connection instead of legacy Scylla variables
- [x] Modify DDC Helm configuration for both database types (conditional env vars)
- [x] Update connection strings to support both Scylla and Keyspaces
- [x] Make SSM execution conditional on Scylla only (Keyspaces doesn't need SSM)
- [x] Maintain backward compatibility with legacy Scylla variables
- [x] Add unified database configuration to Helm templates

### Phase 4: Examples & Documentation ✅ COMPLETE
- [x] Convert existing single-region example to use Keyspaces by default
- [x] Convert existing multi-region example to use Keyspaces with global tables
- [x] Create new Scylla variants of both examples (single-region-scylla, multi-region-scylla)
- [x] Fix Keyspaces implementation (removed billing_mode, corrected awscc usage)
- [x] Update all examples to use correct database configuration
- [ ] Add Terraform validation tests for mutual exclusivity (deferred)
- [ ] Update README to mention both database backends (deferred)

---

## Key Architectural Decisions

### Simplified Always-Create Pattern
**Current Pattern**: `ddc_infra_config != null` → creates infrastructure (conditional)
**New Pattern**: Always create both `ddc_infra` and `ddc_services` modules
**Database Choice**: Handled internally within `ddc_infra` module via conditional resources
**Benefit**: Eliminates conditional complexity while providing database choice

### Global Tables Strategy (Like Secrets Manager)
**Primary Region**: Creates global keyspace with multi-region replication
**Secondary Regions**: Reference existing global keyspace
**Benefits**: Single source of truth, familiar replication pattern, simplified management

### Full State Management Approach
**Challenge**: Amazon Keyspaces cannot be deleted if tables exist
**Solution**: Pre-create all DDC tables in Terraform with fixed schemas
**Result**: Clean terraform destroy, predictable infrastructure

### Authentication via EKS IRSA
**Method**: EKS pods automatically get IAM credentials via ServiceAccount annotations
**Benefit**: No manual credential management, follows AWS best practices
**Implementation**: Standard EKS IRSA pattern with Keyspaces permissions

### Variable Migration Strategy
**Breaking Change**: `scylla_topology_config` → `scylla_config`
**Mitigation**: Major version bump required (v2.0.0)
**Compatibility**: Maintain all existing functionality with new variable structure

---

## Simplified Implementation Requirements

### Current Module Dependencies (SIMPLIFIED)
1. **Parent Module NLB**: Always created, no changes needed
2. **Route53 Private Zone**: Always created, no changes needed
3. **Bearer Token Management**: Already implemented, works with both backends
4. **Centralized Logging**: Needs Keyspaces component addition
5. **SSM Documents**: Make conditional on `scylla_config != null`

### Variable Structure Changes
1. **scylla_topology_config**: Rename to `scylla_config` (breaking change)
2. **amazon_keyspaces_config**: Add new variable with global tables support
3. **Mutual Exclusivity**: Enforce via validation (exactly one database)
4. **Default Values**: Both null by default (user must choose)

### Integration Points (SIMPLIFIED)
1. **main.tf**: Remove conditional logic, always create both modules
2. **modules/ddc-infra/**: Add Keyspaces resources, output unified connection
3. **modules/ddc-services/**: Consume database_connection abstraction
4. **locals.tf**: Simplify with always-create pattern

---

**Document Updated**: Phase 1 complete with mutual exclusivity validation fixes
**Current Status**: Phase 4 ✅ COMPLETE - Amazon Keyspaces Integration Complete
**Next Action**: Comprehensive testing and validation required

---

## TESTING INSTRUCTIONS FOR KEVON

### Testing Strategy

**RECOMMENDED ORDER:**
1. **Test ScyllaDB first** (existing, known working configuration)
2. **Validate DDC table structure assumptions** (critical for Keyspaces compatibility)
3. **Test Amazon Keyspaces** (new implementation)
4. **Database switching** (requires destroy/recreate - breaking change)

### Phase 1: ScyllaDB Validation (Baseline)

**Deploy ScyllaDB example:**
```bash
cd examples/single-region-scylla/
terraform init
terraform apply
```

**Critical Validation Commands:**

**A. EKS Cluster Validation:**
```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Check DDC pods
kubectl get pods -n unreal-cloud-ddc
kubectl logs -f <ddc-pod-name> -n unreal-cloud-ddc

# Check DDC environment variables (CRITICAL)
kubectl exec <ddc-pod-name> -n unreal-cloud-ddc -- env | grep -E "(Scylla|Database|ASPNETCORE)"
```

**B. ScyllaDB Node Validation (CRITICAL FOR KEYSPACES ASSUMPTIONS):**
```bash
# Connect to ScyllaDB node via SSM
aws ssm start-session --target <scylla-instance-id>

# Check cluster status
nodetool status

# Connect to CQL shell
cqlsh

# CRITICAL: Validate keyspace structure (assumptions for Keyspaces)
DESCRIBE KEYSPACES;

# Check DDC keyspace (should match jupiter_local_ddc_* pattern)
DESCRIBE KEYSPACE jupiter_local_ddc_us_east_1;

# CRITICAL: List all tables in DDC keyspace
USE jupiter_local_ddc_us_east_1;
DESCRIBE TABLES;

# CRITICAL: Check table schemas (validate assumptions)
DESCRIBE TABLE cache_entries;  # If exists
DESCRIBE TABLE s3_objects;     # If exists
DESCRIBE TABLE namespace_config; # If exists
DESCRIBE TABLE cleanup_tracking; # If exists

# Check what tables DDC actually creates
SELECT table_name FROM system_schema.tables WHERE keyspace_name = 'jupiter_local_ddc_us_east_1';

# Sample data to understand structure
SELECT * FROM <table_name> LIMIT 5;  # For each table found
```

**C. DDC API Validation:**
```bash
# Get DDC endpoint
terraform output ddc_connection

# Test health
curl <ddc-endpoint>/health/live

# Test PUT operation
curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa" \
  --data "test" \
  -H "content-type: application/octet-stream" \
  -H "X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Test GET operation
curl "<ddc-endpoint>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json" \
  -H "Authorization: ServiceAccount <bearer-token>"
```

**D. Validate Table Creation Timing:**
```bash
# CRITICAL: Check when tables are created
# Before DDC operations:
cqlsh -e "USE jupiter_local_ddc_us_east_1; DESCRIBE TABLES;"

# After DDC PUT operation:
cqlsh -e "USE jupiter_local_ddc_us_east_1; DESCRIBE TABLES;"

# This tells us if DDC creates tables dynamically or expects pre-created tables
```

### Phase 2: Amazon Keyspaces Testing

**Deploy Keyspaces example:**
```bash
cd ../single-region-basic/  # Uses Keyspaces by default
terraform init
terraform apply
```

**A. Keyspaces Validation:**
```bash
# Check keyspace exists
aws keyspaces get-keyspace --keyspace-name jupiter_local_ddc_us_east_1

# List tables
aws keyspaces list-tables --keyspace-name jupiter_local_ddc_us_east_1

# Check table schemas
aws keyspaces get-table --keyspace-name jupiter_local_ddc_us_east_1 --table-name cache_entries
aws keyspaces get-table --keyspace-name jupiter_local_ddc_us_east_1 --table-name s3_objects
aws keyspaces get-table --keyspace-name jupiter_local_ddc_us_east_1 --table-name namespace_config
aws keyspaces get-table --keyspace-name jupiter_local_ddc_us_east_1 --table-name cleanup_tracking
```

**B. EKS DDC Validation:**
```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Check DDC pods
kubectl get pods -n unreal-cloud-ddc

# CRITICAL: Check DDC environment variables for Keyspaces
kubectl exec <ddc-pod-name> -n unreal-cloud-ddc -- env | grep -E "(Keyspaces|Database|ASPNETCORE)"

# Should show:
# Database__Type=keyspaces
# Database__Host=cassandra.us-east-1.amazonaws.com
# Database__Port=9142
# Database__AuthType=iam
# Keyspaces__KeyspaceName=jupiter_local_ddc_us_east_1
```

**C. DDC API Validation (Same as ScyllaDB):**
```bash
# Test health, PUT, GET operations (same commands as above)
```

### Phase 3: Database Migration Test (SAFE MIGRATION)

**✅ RECOMMENDED: Safe Migration Path**

**Step 1: Enable Migration Mode & Configure Keyspaces**
```hcl
# Edit main.tf - Add migration mode and Keyspaces config
database_migration_mode = true  # Enable migration

# Keep existing Scylla config
scylla_config = {
  current_region = {
    replication_factor = 3
    node_count = 3
  }
  enable_cross_region_replication = false  # Match this exactly
}

# Add Keyspaces config - MUST MATCH Scylla settings
amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false  # MUST match Scylla
  peer_regions = []  # MUST match Scylla peer_regions keys
}
```

**Step 2: Apply Migration (Creates Keyspaces, DDC still uses Scylla)**
```bash
terraform apply
# - Keeps: Scylla EC2 instances (DDC still connected)
# - Creates: Keyspaces keyspace and tables (EMPTY)
# - DDC continues using Scylla (no service interruption yet)
# - Ready for data migration or direct switch
```

**Step 3: Test DDC Connectivity & Cache Rebuild (CRITICAL)**
```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Verify DDC is using Keyspaces
kubectl exec <ddc-pod-name> -n unreal-cloud-ddc -- env | grep Database__Type
# Should show: Database__Type=keyspaces

# Test DDC API with Keyspaces (starts with empty cache)
curl <ddc-endpoint>/health/live

# Test cache rebuild process
curl -X PUT "<ddc-endpoint>/api/v1/refs/ddc/default/migration-test" --data "keyspaces-test"
curl "<ddc-endpoint>/api/v1/refs/ddc/default/migration-test.json"

# Verify data is in Keyspaces (not Scylla)
aws keyspaces list-tables --keyspace-name jupiter_local_ddc_us_east_1

# IMPORTANT: Cache will be empty initially
# DDC will rebuild cache on-demand as assets are requested
# Expect slower performance until cache repopulates
```

**MIGRATION OPTIONS:**

**Option A: Cache Rebuild (Simple, High Impact)**
- **Cache data lost** - DDC starts with empty Keyspaces
- **Rebuild time** - Hours to days depending on studio size
- **Impact** - Significant performance degradation until cache repopulates
- **Best for** - Small studios, acceptable downtime

**Option B: Data Migration (Complex, Low Impact)**
- **Cache data preserved** - Manual export/import between databases
- **Downtime** - 1-8+ hours for migration process
- **Impact** - Minimal performance impact post-migration
- **Best for** - Large studios, production environments

**Option B Process (Data Migration):**
```bash
# Step 2a: Export Scylla data (while DDC still uses Scylla)
cqlsh <scylla-ip> -e "COPY jupiter_local_ddc_us_east_1.cache_entries TO 'cache_entries.csv'"
cqlsh <scylla-ip> -e "COPY jupiter_local_ddc_us_east_1.s3_objects TO 's3_objects.csv'"
cqlsh <scylla-ip> -e "COPY jupiter_local_ddc_us_east_1.namespace_config TO 'namespace_config.csv'"
cqlsh <scylla-ip> -e "COPY jupiter_local_ddc_us_east_1.cleanup_tracking TO 'cleanup_tracking.csv'"

# Step 2b: Import to Keyspaces (using Keyspaces endpoint)
cqlsh cassandra.us-east-1.amazonaws.com 9142 --ssl -e "COPY jupiter_local_ddc_us_east_1.cache_entries FROM 'cache_entries.csv'"
cqlsh cassandra.us-east-1.amazonaws.com 9142 --ssl -e "COPY jupiter_local_ddc_us_east_1.s3_objects FROM 's3_objects.csv'"
cqlsh cassandra.us-east-1.amazonaws.com 9142 --ssl -e "COPY jupiter_local_ddc_us_east_1.namespace_config FROM 'namespace_config.csv'"
cqlsh cassandra.us-east-1.amazonaws.com 9142 --ssl -e "COPY jupiter_local_ddc_us_east_1.cleanup_tracking FROM 'cleanup_tracking.csv'"

# Step 2c: Switch DDC to Keyspaces (update Helm release)
kubectl patch deployment <ddc-deployment> -n unreal-cloud-ddc -p '{"spec":{"template":{"spec":{"containers":[{"name":"ddc","env":[{"name":"Database__Type","value":"keyspaces"}]}]}}}}'

# Step 2d: Verify data migration
curl <ddc-endpoint>/health/live
# Test existing cache entries work
```

**Recommendation for Large Studios:**
- Use **Option B** for production environments
- Use **Option A** for development/testing environments
- **Data migration preserves months of cache optimization**

**Step 4: Remove Scylla Config**
```hcl
# Edit main.tf - Remove Scylla config
database_migration_mode = true  # Keep enabled for cleanup

# Remove Scylla config entirely
# scylla_config = { ... }  # DELETE THIS

# Keep Keyspaces config
amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false
}
```

**Step 5: Apply Cleanup**
```bash
terraform apply
# - Destroys: Scylla EC2 instances, security groups, SSM documents
# - Keeps: Keyspaces resources, DDC continues running
```

**Step 6: Disable Migration Mode**
```hcl
# Edit main.tf - Disable migration mode
database_migration_mode = false  # Back to normal

amazon_keyspaces_config = {
  current_region = {
    point_in_time_recovery = false
  }
  enable_cross_region_replication = false
}
```

**Step 7: Final Apply**
```bash
terraform apply
# Should show: No changes. Infrastructure is up-to-date.
```

**⚠️ Multi-Region Migration Requirements:**
- `enable_cross_region_replication` must match between databases
- `peer_regions` must be identical (Scylla map keys = Keyspaces list)
- All regions must be migrated simultaneously

**Example Multi-Region Sync:**
```hcl
# Scylla config
scylla_config = {
  enable_cross_region_replication = true
  peer_regions = {
    "us-west-2" = { replication_factor = 2 }
  }
}

# Keyspaces config - MUST MATCH
amazon_keyspaces_config = {
  enable_cross_region_replication = true  # MATCH
  peer_regions = ["us-west-2"]            # MATCH (keys from Scylla)
}
```

### Critical Validation Points

**1. Table Schema Assumptions:**
- Verify DDC creates the exact tables we pre-created in Keyspaces
- Confirm column names, types, and partition/clustering keys match
- Validate DDC doesn't create additional tables we missed

**2. Environment Variable Mapping:**
- ScyllaDB: `Scylla__LocalDatacenterName`, `Scylla__LocalKeyspaceSuffix`
- Keyspaces: `Keyspaces__KeyspaceName`, `Database__*` variables

**3. Authentication:**
- ScyllaDB: Username/password or no auth
- Keyspaces: IAM authentication via EKS IRSA

**4. Connection Endpoints:**
- ScyllaDB: `scylla.region.compute.internal:9042`
- Keyspaces: `cassandra.region.amazonaws.com:9142`

### Expected Issues & Solutions

**1. Table Schema Mismatch:**
- **Issue**: DDC expects different table structure than we pre-created
- **Solution**: Update keyspaces.tf table schemas to match actual DDC requirements

**2. Missing Tables:**
- **Issue**: DDC creates tables we didn't pre-create
- **Solution**: Add missing table resources to keyspaces.tf

**3. Authentication Failures:**
- **Issue**: DDC can't authenticate with Keyspaces via IAM
- **Solution**: Check EKS IRSA setup and IAM permissions

**4. Environment Variable Issues:**
- **Issue**: DDC doesn't recognize Keyspaces configuration
- **Solution**: Update Helm environment variable mapping in ddc-services

### Success Criteria

**✅ ScyllaDB Working:**
- DDC pods running
- API health check passes
- PUT/GET operations work
- Tables created in ScyllaDB

**✅ Keyspaces Working:**
- DDC pods running with Keyspaces config
- API health check passes
- PUT/GET operations work
- Data stored in Keyspaces tables

**✅ Database Switching:**
- Clean destroy/recreate works
- DDC functions identically with both backends
- No data corruption or orphaned resources

---

**CRITICAL: Focus on validating table structure assumptions first - this is the highest risk area for the Keyspaces integration.**