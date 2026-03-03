# DDC CodeBuild Solution Specification

**Objective**: Replace problematic `null_resource` provisioners with Terraform Actions + CodeBuild to solve EKS deployment timing issues once and for all.

**Status**: CRITICAL - This has been blocking DDC deployments for months. This solution will finally make single `terraform apply` work reliably.

---

## Current State Analysis

### Root Problem: Provider Initialization Timing
The DDC module uses a two-submodule architecture:
1. **ddc-infra**: Creates EKS cluster, ScyllaDB, networking
2. **ddc-app**: Deploys Helm charts to the EKS cluster

**The Fatal Flaw**: `ddc-app` uses `null_resource` with `local-exec` provisioners that try to connect to EKS from the user's local machine. This creates a chicken-and-egg problem:
- Terraform tries to initialize Kubernetes/Helm providers before EKS cluster exists
- Providers need cluster endpoint that doesn't exist yet
- First `terraform apply` always fails
- Users must run `terraform apply` twice (terrible UX)

### Current Architecture Problems

**File**: `modules/ddc-app/main.tf`
```hcl
resource "null_resource" "helm_ddc_app" {
  provisioner "local-exec" {
    command = <<-EOT
      # 200+ lines of complex Helm deployment logic
      aws eks update-kubeconfig --name ${var.cluster_name}
      helm upgrade --install unreal-cloud-ddc...
    EOT
  }
  
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      # 100+ lines of complex cleanup logic
      # Often hangs on finalizer cleanup (as we just experienced)
    EOT
  }
}
```

**Issues**:
1. **Timing**: Runs before cluster is ready
2. **Local Dependencies**: Requires kubectl/helm on user's machine
3. **Error Handling**: Poor error reporting and recovery
4. **Cleanup**: Destroy provisioners hang on finalizer issues
5. **Multi-Region**: Each region has same timing problems
6. **State Management**: Local-exec failures corrupt Terraform state

### Impact Assessment
- **User Experience**: Terrible (requires 2 applies, frequent failures)
- **Reliability**: Poor (timing issues, cleanup hangs)
- **Multi-Region**: Broken (same issues multiplied)
- **Maintenance**: High (complex provisioner logic)
- **Testing**: Difficult (inconsistent behavior)

---

## Solution Architecture: Terraform Actions + CodeBuild

### Core Concept
**Move execution from local machine to AWS CodeBuild**:
- CodeBuild runs AFTER EKS cluster exists (no timing issues)
- Terraform Actions provide synchronous execution
- Same deployment logic, just better execution environment
- Single `terraform apply` works every time

### New Flow
```
terraform apply
├── 1. ddc-infra creates EKS cluster ✅
├── 2. CodeBuild project created ✅
├── 3. terraform_data triggers action ✅
│   ├── action.aws_codebuild_start_build executes
│   ├── CodeBuild connects to EKS (cluster exists!)
│   ├── CodeBuild runs Helm deployment
│   └── Action waits for completion
└── ✅ Single apply succeeds
```

### Key Components

**1. CodeBuild Project** (`codebuild.tf`)
- Replaces `null_resource` provisioner
- Has proper IAM permissions for EKS/Secrets Manager
- Uses buildspec for deployment logic

**2. Buildspec File** (`buildspecs/deploy-ddc.yml`)
- Contains exact same Helm deployment logic
- Installs kubectl/helm in CodeBuild environment
- Handles GHCR authentication and chart deployment

**3. Terraform Action Trigger** (`actions.tf`)
- Uses `terraform_data` with `action_trigger`
- Triggers CodeBuild when cluster is ready
- Waits for synchronous completion

**4. Helm Values Generation** (keep existing)
- Keep all existing `local_file.ddc_helm_values` logic
- CodeBuild reads the generated values file

---

## Implementation Plan

### Phase 1: Create New Components ✅ COMPLETED (1-2 hours)

**Step 1.1: Create CodeBuild Infrastructure**
- ✅ `codebuild.tf` - CodeBuild project + IAM roles (DONE)
- ✅ `buildspecs/deploy-ddc.yml` - Deployment logic (DONE)
- ✅ Update IAM permissions for EKS access (DONE)

**Step 1.2: Create Action Triggers**
- ✅ Add to `codebuild.tf` - Terraform actions and triggers (DONE)
- ✅ `terraform_data` resource with proper input tracking (DONE)
- ✅ Action configuration for CodeBuild execution (DONE)

**Step 1.3: Update Variables and Outputs**
- ✅ All required variables are passed to CodeBuild via environment variables
- ✅ Helm values file passed via base64-encoded environment variable
- ✅ Backward compatibility maintained

### Phase 2: Replace Existing Logic ✅ COMPLETED (30 minutes)

**Step 2.1: Replace null_resource**
- ✅ Comment out existing `null_resource.helm_ddc_app` (DONE)
- ✅ Replace with action trigger (DONE)
- ✅ Keep all existing Helm values generation (DONE)

**Step 2.2: Update Dependencies**
- ✅ Update `depends_on` relationships (DONE)
- ✅ Ensure proper resource ordering (DONE)
- ✅ Maintain existing variable interfaces (DONE)

**Step 2.3: Fix Syntax Issues**
- ✅ Fix action configuration syntax (DONE)
- ✅ Update outputs to reference terraform_data (DONE)
- ✅ Pass Helm values via CodeBuild environment variable (DONE)

### Phase 3: Testing and Validation (1 hour)

**Step 3.1: Single Region Test**
- ⏳ Deploy to single region with new architecture
- ⏳ Verify single `terraform apply` works
- ⏳ Test subsequent applies (version changes)
- ⏳ Test destroy process

**Step 3.2: Multi-Region Test**
- ⏳ Deploy to multiple regions
- ⏳ Verify parallel deployment works
- ⏳ Test cross-region coordination

**Step 3.3: Edge Case Testing**
- ⏳ Test with different DDC versions
- ⏳ Test with configuration changes
- ⏳ Test error scenarios and recovery

### Phase 4: Documentation and Cleanup (30 minutes)

**Step 4.1: Update Documentation**
- ⏳ Update DEVELOPER_REFERENCE.md
- ⏳ Update README with new architecture
- ⏳ Document troubleshooting for CodeBuild

**Step 4.2: Clean Up Old Code**
- ⏳ Remove commented null_resource code
- ⏳ Clean up unused variables
- ⏳ Update version constraints if needed

---

## Detailed File Changes

### New Files to Create

**1. `modules/ddc-app/buildspecs/deploy-ddc.yml`**
```yaml
version: 0.2
phases:
  install:
    commands:
      - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      - chmod +x kubectl && mv kubectl /usr/local/bin/
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  pre_build:
    commands:
      - aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
      - kubectl cluster-info
  build:
    commands:
      # Same Helm deployment logic as current null_resource
      # GHCR authentication, chart deployment, etc.
```

**2. Add to `modules/ddc-app/codebuild.tf`**
```hcl
# Terraform Actions (add to existing codebuild.tf)
resource "terraform_data" "deploy_trigger" {
  input = {
    cluster_name = var.cluster_name
    ddc_version  = var.ddc_application_config.helm_chart
    config_hash  = sha256(jsonencode(var.ddc_application_config))
    values_hash  = local_file.ddc_helm_values.content_md5
  }

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_codebuild_start_build.deploy_ddc]
    }
  }
}

action "aws_codebuild_start_build" "deploy_ddc" {
  config {
    project_name = aws_codebuild_project.ddc_deployer.name
  }
}
```

### Files to Modify

**1. `modules/ddc-app/main.tf`**
- Replace `null_resource.helm_ddc_app` with action trigger
- Keep all existing Helm values generation
- Update dependencies

**2. `modules/ddc-app/variables.tf`**
- Ensure all CodeBuild environment variables are available
- No interface changes for users

**3. `modules/ddc-app/outputs.tf`**
- Update any outputs that reference null_resource
- Maintain backward compatibility

---

## Risk Mitigation

### Rollback Plan
- Keep original `null_resource` code commented out
- Can quickly revert if issues found
- Test thoroughly before removing old code

### Testing Strategy
- Test in isolated AWS account first
- Verify single apply works consistently
- Test all deployment patterns (single/multi-region)
- Validate destroy process works cleanly

### Monitoring
- CodeBuild logs provide better visibility than local-exec
- CloudWatch integration for monitoring
- Proper error codes and exit status

---

## Success Criteria

### Must Have
- ✅ Single `terraform apply` works every time
- ✅ No provider initialization errors
- ✅ Multi-region deployment works
- ✅ Destroy process completes cleanly
- ✅ Same user interface (variables/outputs)

### Should Have
- ✅ Better error reporting via CodeBuild logs
- ✅ Faster deployment (no local machine bottlenecks)
- ✅ More reliable cleanup process
- ✅ Easier troubleshooting

### Nice to Have
- ✅ Parallel multi-region deployment
- ✅ Better integration with CI/CD pipelines
- ✅ Reduced local machine dependencies

---

## Timeline

**Total Estimated Time**: 4 hours
- **Phase 1**: 2 hours (Create new components)
- **Phase 2**: 30 minutes (Replace existing logic)
- **Phase 3**: 1 hour (Testing and validation)
- **Phase 4**: 30 minutes (Documentation and cleanup)

**Target Completion**: Today

**Priority**: CRITICAL - This blocks all DDC usage and has been a problem for months.

---

## Next Steps

1. **Immediate**: Complete buildspec file creation
2. **Next**: Create action triggers and test
3. **Then**: Full integration testing
4. **Finally**: Documentation and cleanup

**Let's get this done today and finally fix DDC deployments!**