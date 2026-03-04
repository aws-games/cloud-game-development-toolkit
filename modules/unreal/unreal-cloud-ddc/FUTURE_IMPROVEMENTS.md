# Future Improvements - Unreal Cloud DDC Module

## Asset Management Optimization

### Current Behavior
Deploy and test triggers share the same `assets_hash`, causing efficient but sometimes unnecessary builds:

- Test script change → App redeploys (ensures consistency)
- Deploy script change → Tests rerun (validates deployment)

### Potential Optimization (v2.0)
Separate asset dependencies for more granular control:

```hcl
# Deploy trigger - deployment-specific files only
deploy_trigger.input = {
  deploy_script_hash = md5(file("scripts/codebuild-deploy-ddc.sh"))
  buildspec_hash     = md5(local.deploy_buildspec)
  config_hash        = local.ddc_config_hash
}

# Test trigger - test-specific files only  
test_trigger.input = {
  test_script_hash    = md5(file("scripts/codebuild-test-ddc-single-region.sh"))
  test_buildspec_hash = md5(local.test_buildspec)
}
```

**Trade-off**: More complex asset management vs. more targeted builds

---

## Terraform Actions Sequential Execution

### Current Implementation
Uses AWS CLI workaround for sequential execution due to Terraform Actions limitation with `depends_on`.

### Future Options
- Wait for Terraform Actions fix
- Consider CodePipeline for complex workflows
- Evaluate Step Functions for advanced orchestration

**Current solution works reliably and is well-documented.**