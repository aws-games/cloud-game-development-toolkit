# Unreal Cloud DDC Module Refactoring TODO

## 1. Module Structure Consolidation
- [ ] Create single parent `unreal-cloud-ddc` module following Perforce module pattern
- [ ] Move existing modules to `/modules` subdirectory as submodules:
  - `unreal-cloud-ddc-infra` → `modules/infrastructure`
  - `unreal-cloud-ddc-intra-cluster` → `modules/application`
- [ ] Create parent module with infrastructure_config and application_config variables
- [ ] Update module references in samples to use new structure
- [ ] **CRITICAL**: Implement proper dependency management between submodules:
  - Infrastructure submodule: VPC, EKS clusters, networking resources
  - Application submodule: Helm releases, Kubernetes resources
  - Ensure application submodule explicitly depends on infrastructure outputs
  - Use `depends_on` to enforce destroy order: application → infrastructure → networking

## 2. Configuration Variables Alignment
- [ ] Add `infrastructure_config` variable to configure infrastructure submodule
- [ ] Add `application_config` variable to configure application submodule
- [ ] Model variable structure after Perforce module patterns
- [ ] Ensure backward compatibility during transition

## 3. Submodule Renaming
- [ ] Rename `unreal-cloud-ddc-infra` to `infrastructure` for clarity
- [ ] Rename `unreal-cloud-ddc-intra-cluster` to `application` for clarity
- [ ] Update all internal references and documentation
- [ ] Update sample configurations

## 4. Naming and Style Alignment
- [ ] **CRITICAL RESEARCH**: Investigate ECR pull-through cache naming constraints
  - Determine if `ecr-pullthroughcache/` prefix can include project_prefix
  - Test: `ecr-pullthroughcache/${project_prefix}-github-credentials`
  - Verify AWS ECR compatibility with custom prefixes
- [ ] Apply project_prefix to all resource names where safe:
  - Secrets Manager secrets (except ECR if constrained)
  - Load balancers
  - Security groups
  - EKS clusters
  - S3 buckets
- [ ] Update bearer token naming: `${project_prefix}-unreal-cloud-ddc-bearer-token`
- [ ] Ensure no functionality breaks with naming changes

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

## 8. Documentation Updates
- [ ] Update module README to reflect new structure
- [ ] Update sample documentation
- [ ] Create migration guide from old to new module structure
- [ ] Document new configuration patterns

## 9. Testing and Validation
- [ ] Test ECR pull-through cache with custom naming
- [ ] Validate all samples work with new module structure
- [ ] Ensure backward compatibility where possible
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

## 7. Route53 DNS Management Enhancement
- [ ] **Research Current vs Perforce Approach**:
  - Analyze impact of private hosted zone creation for DDC
  - Determine if private DNS benefits DDC internal communication
  - Evaluate public zone delegation patterns
- [ ] **Implement Enhanced DNS Strategy**:
  - Create private hosted zone for internal DDC communication
  - Maintain public hosted zone records for external access
  - Follow Perforce module DNS patterns where applicable
  - Consider multi-region DNS failover implications

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
- [ ] **Version Updates** (Target: October 2025):
  - Create GitHub issue: Update EKS Kubernetes version
  - **Current**: 1.31 (expires Nov 25, 2025)
  - **Target**: 1.33 or latest EKS-supported version
  - **Location**: `/modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra/variables.tf`
  - **Requirements**:
    - Default to latest EKS-supported version
    - Validation list: latest + 3 previous minor versions
    - Research Dependabot integration for automated version updates
    - **Deadline**: Complete by October 2025 (before Nov 25 expiration)
- [ ] **Additional Configuration Options**:
  - Create GitHub issue: Alternative storage backends
  - Create GitHub issue: Advanced networking configurations

## 11. Dependency Management and Destroy Order
- [ ] **Infrastructure Submodule Dependencies**:
  - VPC resources (subnets, IGW, route tables)
  - EKS clusters and node groups
  - Security groups and IAM roles
  - ScyllaDB EC2 instances
- [ ] **Application Submodule Dependencies**:
  - Helm releases (require EKS cluster endpoints)
  - Kubernetes resources (namespaces, service accounts)
  - EKS Blueprints addons (require cluster OIDC)
- [ ] **Proper Destroy Order Implementation**:
  - Application resources destroy first (Helm/K8s)
  - Then EKS clusters and node groups
  - Finally networking and VPC resources
  - Use explicit `depends_on` between submodules
- [ ] **Provider Configuration**:
  - Kubernetes/Helm providers depend on EKS cluster outputs
  - Prevent "cluster unreachable" errors during destroy
  - Consider using `ignore_changes` for provider configurations

## 12. Git History and Attribution
- [ ] **Preserve Original Contributor Credit**:
  - Use `git cherry-pick` to maintain original authorship of cwwalb's commits
  - Cherry-pick commits: f56b906, 9b4ea95, 4a31098 from cwwalb/unreal-ddc-multi-region
  - Original author: cwwalb <cwwalb@amazon.com>
- [ ] **Co-authored Commits for New Work**:
  ```bash
  git commit -m "Commit message
  
  Co-authored-by: cwwalb <cwwalb@amazon.com>"
  ```
- [ ] **PR Attribution**:
  - Reference both @cwwalb and @novekm as contributors
  - Acknowledge cwwalb's multi-region work, ScyllaDB fixes, Helm compatibility
  - Credit novekm's consolidation work, Kubernetes updates, dependency management

## 13. Migration Strategy
- [ ] Plan phased rollout approach
- [ ] Create compatibility layer for existing deployments
- [ ] Document breaking changes and migration steps
- [ ] Provide automated migration scripts where possible
- [ ] **Focus**: Prioritize module consolidation over feature additions