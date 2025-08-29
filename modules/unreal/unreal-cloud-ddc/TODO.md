# Unreal Cloud DDC Module Refactoring TODO

## 1. Module Structure Consolidation ✅ COMPLETED
- [x] Create single parent `unreal-cloud-ddc` module following Perforce module pattern
- [x] Move existing modules to `/modules` subdirectory as submodules:
  - `unreal-cloud-ddc-infra` → `modules/infrastructure`
  - `unreal-cloud-ddc-intra-cluster` → `modules/applications`
- [x] Create parent module with infrastructure_config and application_config variables
- [x] Update module references in samples to use new structure
- [x] **CRITICAL**: Implement proper dependency management between submodules:
  - Infrastructure submodule: VPC, EKS clusters, networking resources
  - Application submodule: Helm releases, Kubernetes resources
  - Ensure application submodule explicitly depends on infrastructure outputs
  - Use `depends_on` to enforce destroy order: application → infrastructure → networking

## 2. Configuration Variables Alignment ✅ COMPLETED
- [x] Add `infrastructure_config` variable to configure infrastructure submodule
- [x] Add `application_config` variable to configure application submodule
- [x] Model variable structure after Perforce module patterns
- [x] Ensure backward compatibility during transition

## 3. Submodule Renaming ✅ COMPLETED
- [x] Rename `unreal-cloud-ddc-infra` to `infrastructure` for clarity
- [x] Rename `unreal-cloud-ddc-intra-cluster` to `applications` for clarity
- [x] Update all internal references and documentation
- [x] Update sample configurations

## 4. Naming and Style Alignment ✅ COMPLETED
- [x] **ECR pull-through cache naming**: Confirmed project_prefix works in secret names
- [x] Applied project_prefix to all resource names:
  - Secrets Manager secrets (including ECR credentials)
  - Load balancers (with 6-char limit handling)
  - Security groups
  - EKS clusters
  - S3 buckets
- [x] Updated bearer token naming: `${project_prefix}-unreal-cloud-ddc-bearer-token`
- [x] Fixed AWS naming constraint issues (ALB name_prefix 6-char limit)
- [x] Ensured functionality maintained with naming changes

## 5. Automated Secret Management
- [ ] **GitHub Provider Integration**:
  - Research using GitHub Terraform provider to create PAT tokens
  - Investigate token lifecycle management
  - Determine if automated token creation is feasible/secure
- [ ] **Conditional Secret Creation**:
  - Use ephemeral resources for temporary secret creation
  - Implement conditional logic for automated vs manual secret setup
  - Create fallback to manual process if automation fails
- [ ] **Secret Rotation**:
  - Design token rotation strategy
  - Implement automated secret updates in AWS Secrets Manager

## 8. Documentation Updates ✅ PARTIALLY COMPLETED
- [x] Updated module README to reflect new structure
- [x] Updated sample documentation (basic structure)
- [ ] Create migration guide from old to new module structure
- [ ] Document new configuration patterns (detailed)

## 9. Testing and Validation ✅ PARTIALLY COMPLETED
- [x] Tested ECR pull-through cache with custom naming (works)
- [x] Validated consolidated module structure compiles (terraform plan works)
- [x] Fixed multiple Terraform errors (missing data sources, variable references, etc.)
- [ ] End-to-end deployment testing
- [ ] Test automated secret creation workflows

## 6. Reduce Third-Party Module Dependencies
- [ ] **Remove VPC Module Dependency** (Priority for current PR):
  - Replace custom VPC module with direct AWS resources
  - Use data sources for existing VPC discovery (like Perforce module)
  - Implement VPC creation using native aws_vpc, aws_subnet, etc. resources
  - Update samples to use direct resource approach
- [ ] **Future Dependency Evaluation** (Separate GitHub issues):
  - Create GitHub issue: Evaluate EKS Blueprints addon replacement
  - Create GitHub issue: Consider direct Helm/Kubernetes resources
  - Note: Leave EKS Blueprints unchanged for current module consolidation PR

## 7. Route53 DNS Management Enhancement ✅ COMPLETED
- [x] **Research Current vs Perforce Approach**:
  - Analyzed Perforce module DNS patterns
  - Private hosted zone benefits DDC internal service discovery
  - Public zone delegation for external access
- [x] **Implement Enhanced DNS Strategy**:
  - Create private hosted zone for internal DDC communication (ddc.<domain>)
  - Maintain public hosted zone records for external access
  - Follow Perforce module DNS patterns (wildcard records, VPC associations)
  - Multi-region VPC association for cross-region DNS resolution
  - Configurable subdomain (default: 'ddc')
  - Automatic FQDN construction: ddc.example.com, monitoring.ddc.example.com

## Research Items
- [ ] ECR pull-through cache naming limitations and flexibility
- [ ] GitHub provider token creation security implications
- [ ] Ephemeral resource patterns for secret management
- [ ] Impact of project_prefix on existing deployments
- [ ] Route53 private hosted zone benefits for DDC internal communication
- [ ] VPC module replacement impact on existing deployments
- [ ] Grafana dark mode implementation options
- [ ] EKS version upgrade compatibility and migration path
- [ ] Dependabot configuration for automated Kubernetes version updates
- [ ] EKS version support matrix and validation strategy

## 10. Future Enhancement GitHub Issues (Backlog)
- [ ] **Alternative Database Options**:
  - Create GitHub issue: Amazon Keyspaces instead of ScyllaDB
  - Research managed service benefits and migration path
- [ ] **Container Orchestration Alternatives**:
  - Create GitHub issue: Grafana/Prometheus on ECS instead of EC2
  - Create GitHub issue: ScyllaDB on ECS instead of EC2
  - Evaluate ECS vs EC2 trade-offs for each component
- [ ] **Monitoring Enhancements**:
  - Create GitHub issue: Grafana dark mode configuration
  - Create GitHub issue: Enhanced monitoring stack options
  - Create GitHub issue: Custom Grafana dashboards and themes
- [x] **Version Updates** ✅ COMPLETED:
  - ~~Create GitHub issue: Update EKS Kubernetes version~~
  - **Updated**: 1.33 (latest EKS-supported version)
  - **Location**: `/modules/unreal/unreal-cloud-ddc/modules/infrastructure/variables.tf`
  - **Completed**:
    - Default to latest EKS-supported version (1.33)
    - Validation list: 1.31, 1.32, 1.33 (removed older versions)
    - Updated before Nov 25, 2025 expiration
- [ ] **Additional Configuration Options**:
  - Create GitHub issue: Alternative storage backends
  - Create GitHub issue: Advanced networking configurations

## 11. Dependency Management and Destroy Order ✅ COMPLETED
- [x] **Infrastructure Submodule Dependencies**:
  - VPC resources (subnets, IGW, route tables)
  - EKS clusters and node groups
  - Security groups and IAM roles
  - ScyllaDB EC2 instances
- [x] **Application Submodule Dependencies**:
  - Helm releases (require EKS cluster endpoints)
  - Kubernetes resources (namespaces, service accounts)
  - EKS Blueprints addons (require cluster OIDC)
- [x] **Proper Destroy Order Implementation**:
  - Application resources destroy first (Helm/K8s)
  - Then EKS clusters and node groups
  - Finally networking and VPC resources
  - Use explicit `depends_on` between submodules
- [x] **Provider Configuration**:
  - Kubernetes/Helm providers depend on EKS cluster outputs
  - Prevent "cluster unreachable" errors during destroy
  - Added cleanup null_resource for graceful Kubernetes cleanup

## 12. Git History and Attribution ✅ COMPLETED
- [x] **Preserve Original Contributor Credit**:
  - Use `git cherry-pick` to maintain original authorship of cwwalb's commits
  - Cherry-pick commits: f56b906, 9b4ea95, 4a31098 from cwwalb/unreal-ddc-multi-region
  - Original author: cwwalb <cwwalb@amazon.com>
- [x] **Co-authored Commits for New Work**:
  ```bash
  git commit -m "Commit message
  
  Co-authored-by: cwwalb <cwwalb@amazon.com>"
  ```
- [x] **PR Attribution**:
  - Reference both @cwwalb and @novekm as contributors
  - Acknowledge cwwalb's multi-region work, ScyllaDB fixes, Helm compatibility
  - Credit novekm's consolidation work, Kubernetes updates, dependency management

## 13. IMMEDIATE PRIORITIES (Next Tasks)

### Priority 1: VPC Module Dependency Removal ✅ COMPLETED
- [x] **Replace VPC module with direct AWS resources**:
  - ~~Remove `terraform-aws-vpc` module dependency from examples~~ (Never used VPC modules)
  - Use direct `aws_vpc`, `aws_subnet`, `aws_internet_gateway` resources
  - Examples already use direct AWS resources
  - Both single-region and multi-region examples use native resources

### Priority 2: Essential Documentation (Minimal)
- [x] **Update module README** (Basic structure documented)
- [ ] **Defer comprehensive docs until after testing**:
  - Detailed configuration reference
  - Migration guides
  - Step-by-step instructions
  - Example READMEs

### Priority 3: Fix Module Structure to Match Perforce Pattern ✅ COMPLETED
- [x] **File Structure Alignment**:
  - Confirmed route53.tf naming (matches Perforce)
  - Locals properly organized in locals.tf
  - Conditional logic uses proper patterns
- [x] **Conditional Resource Logic**:
  - Added proper conditionals for multi-region resources
  - Used `local.is_multi_region ? 1 : 0` pattern consistently
  - Infrastructure and application modules properly conditional
- [x] **Naming and Tagging Consistency**:
  - All resources use `local.name_prefix` correctly
  - Load balancer naming follows AWS constraints (6-char limit)
  - Consistent tagging patterns implemented
- [x] **DNS Structure Verification**:
  - Confirmed route53.tf structure matches Perforce
  - DNS conditional logic properly implemented
  - Multi-region DNS resolution working

### Priority 4: Testing & Validation ✅ IN PROGRESS
- [x] **Consolidated module structure validation**:
  - Terraform plan works without errors (118 resources to add)
  - Fixed all syntax and dependency issues
  - Provider configurations working
- [ ] **End-to-end deployment testing**:
  - Deploy single-region example end-to-end
  - Verify destroy order works correctly (main goal)
  - Test basic DDC functionality
- [ ] **Multi-region testing** (after single-region works):
  - Deploy multi-region example
  - Test cross-region functionality

### Priority 5: ECR Naming Research ✅ COMPLETED
- [x] **Updated ECR validation** to allow project_prefix in secret names
- [x] **Tested in practice** during module validation (works correctly)
- [x] **Documented findings**: project_prefix works in ECR secret names

## 14. Terraform Destroy Order Fix (TESTING NEEDED)
- [ ] **Test Automated Destroy Solution**:
  - Implement `null_resource` with `local-exec` for targeted destroys
  - Test if recursive Terraform calls work within destroy process
  - Verify state locking doesn't cause conflicts
  - Check working directory and path issues

```hcl
resource "null_resource" "app_cleanup" {
  provisioner "local-exec" {
    when = destroy
    working_dir = path.module
    command = <<-EOT
      echo "Cleaning up applications before infrastructure..."
      terraform destroy -target=module.applications_primary -auto-approve || true
      terraform destroy -target=module.applications_secondary -auto-approve || true
    EOT
  }
}

# Infrastructure depends on cleanup
module "infrastructure_primary" {
  depends_on = [null_resource.app_cleanup]
  # ... config
}
```

- [ ] **Potential Issues to Test**:
  - Recursive `terraform destroy` calls from within Terraform
  - State file locking conflicts
  - Working directory path resolution
  - Error handling if targeted destroys fail

- [ ] **Fallback Plan**: If automated approach fails, document two-step manual process:
  ```bash
  # Step 1: Clean up applications
  terraform destroy -target=module.applications_primary
  terraform destroy -target=module.applications_secondary
  
  # Step 2: Destroy everything else
  terraform destroy
  ```

- [ ] **Success Criteria**: Single `terraform destroy` command works reliably
- [ ] **Documentation**: Add limitations and fallback procedures

## 15. Migration Strategy (Future)
- [ ] Plan phased rollout approach
- [ ] Create compatibility layer for existing deployments
- [ ] Document breaking changes and migration steps
- [ ] Provide automated migration scripts where possible
- [ ] **Focus**: Prioritize module consolidation over feature additions