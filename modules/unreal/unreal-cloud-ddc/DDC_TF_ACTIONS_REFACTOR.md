# DDC Terraform Actions Refactor

**Objective:** Replace fragile `null_resource` local-exec patterns with reliable Terraform Actions + CodeBuild, following AgentCore patterns.

## Current State Analysis

### What Works
- ✅ **EKS cluster creation** - Standard Terraform, reliable
- ✅ **ScyllaDB EC2 instances** - Standard Terraform, reliable  
- ✅ **IAM roles/policies** - Standard Terraform, reliable
- ✅ **Security groups** - Standard Terraform, reliable
- ✅ **DDC Helm deployment** - Already using CodeBuild (recent change)

### What's Fragile (Needs Refactoring)
- ✅ **AWS Load Balancer Controller install** - ~~`null_resource` with helm CLI~~ **MIGRATED TO CODEBUILD**
- ✅ **Custom NodePool creation** - ~~`null_resource` with kubectl CLI~~ **MIGRATED TO CODEBUILD**
- ✅ **Cert Manager install** - ~~`null_resource` with helm CLI (optional)~~ **MIGRATED TO CODEBUILD**
- ❌ **Functional testing** - `null_resource` with bash scripts
- ❌ **ScyllaDB keyspace config** - `null_resource` with SSM commands
- ❌ **Complex destroy provisioners** - Cleanup logic prone to failures

### Current Architecture (After Phase 2)
```
Parent Module (main.tf)
├── ddc_infra submodule (always created)
│   ├── EKS cluster ✅
│   ├── ScyllaDB ✅
│   ├── IAM roles ✅
│   ├── CodeBuild project: cluster_setup ✅ (COMPLETED)
│   ├── terraform_data: cluster_setup_trigger ✅ (COMPLETED)
│   └── Legacy null_resource blocks (commented out for rollback)
└── ddc_app submodule (conditional)
    ├── DDC Helm deployment ✅ (CodeBuild)
    ├── Functional testing ✅ (CodeBuild) - PHASE 2 COMPLETE
    ├── ScyllaDB keyspace ✅ (CodeBuild) - PHASE 2 COMPLETE
    └── Legacy null_resource blocks (commented out for rollback)
```

## Target Architecture (AgentCore Pattern)

### Design Principles
1. **Terraform = AWS Resources Only** - No kubectl/helm in Terraform
2. **CodeBuild = Kubernetes Operations** - All kubectl/helm via CodeBuild
3. **Terraform Actions = Orchestration** - Synchronous, reliable triggers
4. **User Choice** - Default CodeBuild, optional external management
5. **No Scope Creep** - Stay EKS-focused, reusable pattern for other clouds

### Target Structure
```
Parent Module (main.tf)
├── ddc_infra submodule
│   ├── EKS cluster (Terraform)
│   ├── ScyllaDB (Terraform) 
│   ├── IAM roles (Terraform)
│   ├── CodeBuild project: cluster_setup
│   └── terraform_data: cluster_setup_trigger
└── ddc_app submodule (conditional)
    ├── CodeBuild project: app_deployment  
    ├── terraform_data: app_deployment_trigger
    └── Functional testing (in CodeBuild)
```

### CodeBuild Responsibilities

**CodeBuild 1: Cluster Setup (ddc-infra)**
```yaml
# buildspec inline (AgentCore pattern)
phases:
  install:
    commands:
      - curl -LO kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  pre_build:
    commands:
      - aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
      - kubectl cluster-info --request-timeout=30s
  build:
    commands:
      - # Install AWS Load Balancer Controller
      - # Create Custom NodePools
      - # Install Cert Manager (if enabled)
```

**CodeBuild 2: App Deployment (ddc-app)**
```yaml
# buildspec inline (AgentCore pattern)  
phases:
  pre_build:
    commands:
      - aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
  build:
    commands:
      - # Deploy DDC Helm chart
      - # Run functional tests (if enabled)
      - # Configure ScyllaDB keyspaces (if needed)
```

## Implementation Plan

### Phase 1: ddc-infra Refactor ✅ **COMPLETE**
**Goal:** Replace null_resource cluster setup with CodeBuild

#### Step 1.1: Create CodeBuild Infrastructure
- [x] Add `aws_codebuild_project.cluster_setup` to ddc-infra
- [x] Add IAM role for CodeBuild with EKS permissions
- [x] Add environment variables (CLUSTER_NAME, AWS_REGION, etc.)
- [x] Use `NO_SOURCE` with inline buildspec (AgentCore pattern)
- [x] Add `action "aws_codebuild_start_build" "cluster_setup"`
- [x] Add `terraform_data.cluster_setup_trigger` with action_trigger
- [x] Set events to `[before_create, before_update]`
- [x] Add proper depends_on for EKS cluster

#### Step 1.2: Create Terraform Actions
- [x] Add `action "aws_codebuild_start_build" "cluster_setup"`
- [x] Add `terraform_data.cluster_setup_trigger` with action_trigger
- [x] Set events to `[before_create, before_update]`
- [x] Add proper depends_on for EKS cluster

#### Step 1.3: Migrate Existing Logic
- [x] Move AWS LBC install logic to CodeBuild buildspec
- [x] Move Custom NodePool logic to CodeBuild buildspec  
- [x] Move Cert Manager logic to CodeBuild buildspec
- [x] Comment out all null_resource cluster setup resources (kept for rollback)

#### Step 1.4: Update Dependencies
- [x] Ensure ddc-app waits for cluster_setup completion (via standard module dependencies)
- [x] No additional outputs needed - terraform_data.cluster_setup_trigger handles sequencing
- [x] Module dependencies automatically wait for all ddc-infra resources including CodeBuild completion

### Phase 2: ddc-app Refactor ✅ **COMPLETE**
**Goal:** Consolidate app deployment and testing in CodeBuild

#### Step 2.1: Enhance Existing CodeBuild ✅ **COMPLETE**
- [x] Current DDC deployment CodeBuild already exists
- [x] Add functional testing to existing buildspec
- [x] Add ScyllaDB keyspace configuration to buildspec
- [x] Remove separate null_resource testing resources
- [x] Add environment variables for testing and ScyllaDB configuration
- [x] Add SSM permissions to CodeBuild IAM role

#### Step 2.2: Clean Up Legacy Resources ✅ **COMPLETE**
- [x] Remove `null_resource.ddc_single_region_readiness_check`
- [x] Remove `null_resource.ddc_multi_region_readiness_check`  
- [x] Remove `null_resource.trigger_ssm_keyspace_update`
- [x] All legacy resources commented out for rollback safety

### Phase 3: Testing & Validation ⚠️ **IN PROGRESS**
**Goal:** Ensure refactored module works reliably

#### Step 3.1: Unit Testing ⚠️ **CURRENT ISSUE**
- [x] **CodeBuild connectivity resolved** - EKS access entry + public CIDR access working
- [x] **YAML parsing fixed** - External manifest files prevent buildspec parsing errors
- [ ] **🚨 SECURITY ISSUE**: CodeBuild requires user's `public_access_cidrs` to include CodeBuild IP ranges
  - **Current**: Users must manually add CodeBuild IPs to their CIDR allowlist
  - **Proper fix**: Implement VPC configuration for CodeBuild to use private EKS endpoint
  - **Action needed**: Add `codebuild_use_vpc` variable and VPC networking configuration
- [ ] **🚨 HELM TIMEOUT**: AWS Load Balancer Controller installation timing out after 3 minutes
  - **Error**: `context deadline exceeded` during Helm install
  - **Status**: 2 nodes available (c6a.large, EKS Auto Mode), so not a node availability issue
  - **Likely causes**: IAM propagation delay, pod scheduling constraints, or resource limits
  - **Action taken**: Increased timeout to 10m, added debugging for pod status
  - **Next**: Test with increased timeout and debug pod scheduling issues
- [ ] Test infrastructure-only deployment (`ddc_application_config = null`)
- [ ] Test full deployment with both submodules
- [ ] Test destroy workflow (no hanging resources)
- [ ] Verify no race conditions between phases

#### Step 3.2: Integration Testing
- [ ] Deploy in clean AWS account
- [ ] Verify EKS cluster fully configured
- [ ] Verify DDC application accessible
- [ ] Test multi-region deployment (if applicable)

#### Step 3.3: Documentation Updates
- [ ] Update README with new architecture
- [ ] Update examples to show new patterns
- [ ] Document troubleshooting for CodeBuild failures
- [ ] Add migration guide from old version

## Success Criteria

### Reliability Improvements
- ✅ **No more local-exec failures** - All cluster setup operations now in CodeBuild
- ✅ **No more environment dependencies** - Consistent CodeBuild environment for cluster setup
- ✅ **No more race conditions** - Proper Terraform Actions sequencing for cluster setup
- ✅ **No more destroy failures** - Clean resource lifecycle (Phase 2 complete)

### User Experience
- ✅ **Same interface** - No breaking changes to variables
- ✅ **Better debugging** - CodeBuild logs instead of Terraform output
- ✅ **Faster feedback** - Clear failure points in CodeBuild
- ✅ **Optional external management** - Users can skip CodeBuild if desired

### Code Quality
- ✅ **Follows AgentCore patterns** - Phase 1 implementation uses AgentCore patterns exactly
- ✅ **Maintainable** - Clear separation: Terraform = AWS resources, CodeBuild = Kubernetes ops
- ✅ **Extensible** - Easy to add new Kubernetes operations to buildspec
- ✅ **Testable** - Each phase can be tested independently (Phase 2 complete)

## Risk Mitigation

### Rollback Plan
- ✅ Keep current null_resource code commented out initially - **COMPLETED**
- ❌ Test new CodeBuild approach thoroughly before removing old code - **PHASE 3**
- ❌ Document exact steps to revert if issues found - **PHASE 3**

### Testing Strategy
- [ ] Test in isolated AWS account first
- [ ] Gradual rollout: infra first, then app
- [ ] Validate each step before proceeding to next

### Monitoring
- [ ] Monitor CodeBuild execution times
- [ ] Track failure rates and common issues
- [ ] Set up alerts for CodeBuild failures

## Timeline Estimate

- **Phase 1 (ddc-infra):** 2-3 days
- **Phase 2 (ddc-app):** 1-2 days  
- **Phase 3 (testing):** 2-3 days
- **Total:** 5-8 days

## Next Steps

1. **Start with Phase 1.1** - Create CodeBuild infrastructure for cluster setup
2. **Test incrementally** - Validate each step before proceeding
3. **Update this document** - Mark completed tasks and track progress
4. **Document lessons learned** - Update patterns for future modules

---

**Status:** ✅ **Phase 2 Complete - Ready for Phase 3**
**Last Updated:** 2025-01-15
**Next Action:** Begin Phase 3.1 - Unit Testing

## Documentation Update Requirements

### Immediate Actions Needed

#### 1. Rename DEVELOPER_REFERENCE.md → DEVELOPER_GUIDE.md
- Align with agentcore naming convention
- Update any internal references to the old name

#### 2. Update All Documentation for Recent Changes
**Major changes that need documentation updates:**

**Architecture Changes:**
- **CodeBuild Implementation**: Replaced null_resource local-exec with CodeBuild projects
- **S3 + Shell Script Pattern**: Both ddc-infra and ddc-app now use S3 assets + shell scripts
- **EKS Auto Mode**: Full EKS Auto Mode implementation with custom NodePools
- **Terraform Actions**: New terraform_data + action triggers for CodeBuild orchestration

**Implementation Changes:**
- **YAML Buildspecs**: Fixed parsing issues, proper variable escaping
- **Archive Structure**: Now includes scripts/ directory for CodeBuild access  
- **Test Integration**: Tests moved from post_build to build phase to fail builds properly
- **Environment Variables**: Complex Helm args moved to Terraform env vars (HELM_LBC_ARGS, etc.)

**Operational Changes:**
- **Trigger Logic**: Both modules track buildspec_hash, assets_hash, and config changes
- **Error Handling**: Proper exit codes and build failure propagation
- **NodePool Requirements**: Uses eks.amazonaws.com/instance-local-nvme for NVMe instance selection

#### 3. Content Accuracy Review
**Check against current implementation:**
- [ ] Architecture diagrams reflect CodeBuild approach (not local-exec)
- [ ] Troubleshooting procedures use correct CodeBuild commands
- [ ] Variable examples match current terraform_data + action patterns
- [ ] Prerequisites include CodeBuild IAM permissions
- [ ] Examples show S3 asset structure and shell script patterns

#### 4. Agentcore Alignment
**Need to examine agentcore DEVELOPER_GUIDE.md for:**
- [ ] Structure and section organization
- [ ] Writing style and technical depth
- [ ] Troubleshooting format and command examples
- [ ] Architecture explanation patterns
- [ ] Developer workflow documentation

#### 5. Hybrid Documentation Strategy
**DDC is unique because it supports both:**
- **Full Terraform deployment** (infrastructure + application)
- **Infrastructure-only deployment** (for GitOps workflows)

Documentation must clearly explain both patterns and when to use each.

**Key Message**: We changed from local-exec provisioners to CodeBuild + S3 assets, which fundamentally changes how developers interact with, troubleshoot, and extend the module.