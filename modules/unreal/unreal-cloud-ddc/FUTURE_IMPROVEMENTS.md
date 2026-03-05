# Future Improvements - Unreal Cloud DDC Module

## Split-Horizon DNS for VPC Clients

### Current Implementation
Uses public zone only with Google DNS fallback for VPC clients (CodeBuild):

- **External clients**: Resolve via public zone → NLB public IPs
- **VPC clients**: DNS fails → Fall back to Google DNS → Public zone → NLB public IPs

### Challenge
VPC clients accessing internet-facing NLBs via public IPs can have routing inefficiencies.

### Future Enhancement: True Split-Horizon DNS
Deploy dual External-DNS instances for different IP resolution:

```hcl
# Public External-DNS (EKS Addon)
aws_eks_addon "external_dns" {
  configuration_values = jsonencode({
    txtOwnerId = "${local.name_prefix}-public"
    # Targets public zones only
  })
}

# Private External-DNS (Helm Chart)
helm_release "external_dns_private" {
  values = [yamlencode({
    annotationPrefix = "internal-dns.alpha.kubernetes.io"
    aws.zoneType = "private"
    txtOwnerId = "${local.name_prefix}-private"
  })]
}
```

**Service annotations**:
```hcl
# Public zone → NLB public IPs
"external-dns.alpha.kubernetes.io/hostname" = "ddc.example.com"
"external-dns.alpha.kubernetes.io/zone-id" = var.public_zone_id

# Private zone → NLB private IPs
"internal-dns.alpha.kubernetes.io/hostname" = "ddc.example.com"
"internal-dns.alpha.kubernetes.io/internal-hostname" = "ddc.example.com"
"internal-dns.alpha.kubernetes.io/zone-id" = var.private_zone_id
```

### Implementation Challenges
1. **EKS Addon limitations**: Cannot configure `aws-zone-type` parameter
2. **Helm provider setup**: Requires Kubernetes configuration complexity
3. **IAM trust policy**: Must allow both service accounts
4. **Operational overhead**: Two External-DNS instances to manage

### Alternative: Internal NLB
Simpler solution for VPC-only access:

```hcl
load_balancers_config = {
  nlb = {
    internet_facing = false  # Creates internal NLB
  }
}
```

**Benefits**:
- Single External-DNS instance
- Private IPs only → No VPC routing issues
- Simpler architecture

**Trade-off**: External developer access requires VPN/bastion

### Recommendation
- **Current approach**: Works reliably with Google DNS fallback
- **Internal NLB**: Best for VPC-only environments
- **Split-horizon DNS**: Future enhancement when EKS addon supports zone-type configuration

---

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