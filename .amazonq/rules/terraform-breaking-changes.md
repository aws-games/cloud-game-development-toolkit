# Terraform Breaking Changes Prevention

## CRITICAL: State-Breaking Changes

**ALWAYS check for these breaking changes before making ANY Terraform modifications:**

### 🔥 MOST SEVERE: Module Call Name Changes
```hcl
# ❌ BREAKING - Changes ALL resource paths in state
module "ddc_infra" {          # Old name
module "infrastructure" {     # New name - BREAKS EVERYTHING
```

**Impact:** Every resource path changes (`module.ddc_infra.*` → `module.infrastructure.*`)
**User Impact:** Manual state migration required for EVERY resource

### 🔥 SEVERE: Resource Logical Name Changes
```hcl
# ❌ BREAKING - Changes resource path in state
resource "aws_vpc" "this" {          # Old logical name
resource "aws_vpc" "main_vpc" {      # New logical name - BREAKS STATE
```

**Impact:** Single resource path changes
**User Impact:** Terraform tries to destroy + recreate → circular dependencies

### 🟡 MODERATE: Variable Name Changes
```hcl
# ❌ BREAKING - Interface change
variable "cidr" {          # Old variable name
variable "cidr_block" {    # New variable name - BREAKS USER CODE
```

**Impact:** Configuration interface change
**User Impact:** Must update all variable references

### 🟡 MODERATE: Output Name Changes
```hcl
# ❌ BREAKING - Interface change
output "vpc_id" {     # Old output name
output "id" {         # New output name - BREAKS DOWNSTREAM REFERENCES
```

**Impact:** Output interface change
**User Impact:** Must update all output references

## MANDATORY Requirements for Breaking Changes

### 1. Pre-Development Checklist
**BEFORE making any breaking changes:**

- [ ] **Destroy test infrastructure first**: Run `terraform destroy` on any test deployments
- [ ] **Check if this is truly necessary**: Can you achieve the goal without breaking changes?
- [ ] **Plan migration strategy**: How will existing users migrate?
- [ ] **Version bump planned**: This MUST be a major version (v2.0.0, v3.0.0, etc.)

### 2. Implementation Requirements
**MUST include ALL of the following:**

#### A. Add `moved` Blocks for Resource Changes
```hcl
# REQUIRED for any resource logical name changes
moved {
  from = aws_vpc.this
  to   = aws_vpc.main_vpc
}

moved {
  from = aws_security_group.app_sg
  to   = aws_security_group.application_sg
}

# Add moved block for EVERY renamed resource
```

#### B. Update Examples and Tests
```hcl
# Update ALL examples to use new names
# Update ALL tests to use new names
# Ensure examples work with new module version
```

#### C. Comprehensive Documentation
**REQUIRED in PR description:**
```markdown
## ⚠️ BREAKING CHANGES - MAJOR VERSION REQUIRED

### Changes Made:
- [ ] Module call names changed: `old_name` → `new_name`
- [ ] Resource logical names changed: `old_resource` → `new_resource`
- [ ] Variable names changed: `old_var` → `new_var`
- [ ] Output names changed: `old_output` → `new_output`

### Migration Required:
- [ ] Added `moved` blocks for all resource changes
- [ ] Updated all examples and tests
- [ ] Tested migration path with existing state
- [ ] Documented breaking changes in CHANGELOG.md

### User Impact:
- **Severity**: 🔥 High / 🟡 Medium / 🟢 Low
- **Migration effort**: [Describe what users must do]
- **Backward compatibility**: None (major version required)

### Testing Completed:
- [ ] `terraform destroy` completed before changes
- [ ] `terraform plan` shows no changes after `moved` blocks
- [ ] All examples deploy successfully
- [ ] Migration tested with real state file
```

### 3. Version Management
**REQUIRED versioning strategy:**

- **Major version bump**: v1.x.x → v2.0.0
- **Clear changelog**: Document ALL breaking changes
- **Migration guide**: Step-by-step user instructions
- **Deprecation notice**: Warn in previous minor version if possible

## Safe Change Patterns

### ✅ SAFE: Adding New Resources
```hcl
# Safe - doesn't change existing resource paths
resource "aws_s3_bucket" "new_bucket" {
  bucket = "${var.name_prefix}-new-bucket"
}
```

### ✅ SAFE: Adding New Variables (with defaults)
```hcl
# Safe - doesn't break existing configurations
variable "new_feature_enabled" {
  type        = bool
  description = "Enable new feature"
  default     = false  # REQUIRED default for backward compatibility
}
```

### ✅ SAFE: Adding New Outputs
```hcl
# Safe - doesn't break existing references
output "new_resource_id" {
  value = aws_s3_bucket.new_bucket.id
}
```

### ✅ SAFE: Resource Configuration Changes
```hcl
# Safe - same logical name, different configuration
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true  # Added configuration - safe
}
```

## Emergency Procedures

### If Breaking Changes Already Deployed
1. **Immediate rollback**: Revert to previous module version
2. **Create hotfix branch**: Fix with `moved` blocks
3. **Test migration thoroughly**: Ensure no data loss
4. **Communicate impact**: Notify all module users
5. **Document lessons learned**: Update this rule if needed

### If State Corruption Occurs
1. **Stop all operations**: Don't run more Terraform commands
2. **Backup current state**: `cp terraform.tfstate terraform.tfstate.backup`
3. **Manual state recovery**: Use `terraform state mv` commands
4. **Import missing resources**: Use `terraform import` if needed
5. **Verify with plan**: Ensure `terraform plan` shows expected changes

## Automation and Prevention

### Pre-commit Hook Integration
**RECOMMENDED**: Add to `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: terraform-breaking-changes
        name: Check for Terraform breaking changes
        entry: scripts/check-breaking-changes.sh
        language: script
        files: \.tf$
```

### GitHub Actions Integration
**RECOMMENDED**: Add PR check for breaking changes:
```yaml
name: Check Breaking Changes
on: [pull_request]
jobs:
  breaking-changes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history
      - name: Check for breaking changes
        run: scripts/detect-breaking-changes.sh
```

## Key Reminders

### For Module Developers
- **Think twice**: Is this change really necessary?
- **Major versions only**: Breaking changes require major version bumps
- **Test migration**: Always test with real state files
- **Document everything**: Users need clear migration paths

### For Code Reviewers
- **Block PRs**: Don't approve breaking changes without proper migration
- **Check moved blocks**: Ensure all renamed resources have moved blocks
- **Verify testing**: Confirm migration was tested with real state
- **Version validation**: Ensure major version bump is planned

### For CI/CD
- **Automated detection**: Use scripts to detect potential breaking changes
- **Block deployment**: Don't allow breaking changes in minor/patch versions
- **State backup**: Always backup state before applying changes
- **Rollback plan**: Have automated rollback procedures ready

## Remember: Public Module Responsibility

**CGD Toolkit modules are PUBLIC and used by external teams.**
- Breaking changes affect multiple organizations
- Poor migration experiences damage project reputation
- Always err on the side of caution
- When in doubt, create new resources instead of renaming existing ones

**"It's easier to add than to change, easier to change than to remove."**
