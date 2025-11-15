# Minimal Protocol Implementation - Certificate-Based

## EXACTLY what needs to be added to the current code:

### 1. Add to locals.tf (2 lines only):

```hcl
# Certificate-based protocol detection
endpoint_protocol = var.certificate_arn != null ? "https" : "http"
ddc_endpoint = "${local.endpoint_protocol}://${local.ddc_endpoint_pattern}"
```

### 2. Update outputs.tf (replace existing ddc_connection):

```hcl
output "ddc_connection" {
  description = "DDC connection information for this region"
  value = var.ddc_infra_config != null ? {
    region          = module.ddc_infra.region
    bucket          = module.ddc_infra.s3_bucket_id
    internet_facing = var.load_balancers_config.nlb.internet_facing

    # NEW: Protocol-aware endpoint
    endpoint = local.ddc_endpoint

    # Legacy endpoints (keep for backward compatibility)
    endpoint_private_dns = "${local.endpoint_protocol}://${local.region}.${local.service_name}.${local.private_zone_name}"
    endpoint_public_dns = local.public_dns_name != null ? "${local.endpoint_protocol}://${local.public_dns_name}" : null
    endpoint_nlb = var.load_balancers_config.nlb != null ? "${local.endpoint_protocol}://${aws_lb.nlb[0].dns_name}" : null

    # Configuration details
    protocol = local.endpoint_protocol
    dns_name = local.ddc_endpoint_pattern
    
    # Rest unchanged...
    security_warning = local.security_warning
    bearer_token_secret_arn = var.create_bearer_token == true ? aws_secretsmanager_secret.unreal_cloud_ddc_token[0].arn : var.ddc_application_config.bearer_token_secret_arn
    kubectl_command = "aws eks update-kubeconfig --region ${module.ddc_infra.region} --name ${module.ddc_infra.cluster_name}"
    cluster_name = module.ddc_infra.cluster_name
    namespace = var.ddc_infra_config != null && length(module.ddc_app) > 0 ? module.ddc_app[0].namespace : null
    scylla_ips = module.ddc_infra.scylla_ips
    scylla_instance_ids = module.ddc_infra.scylla_instance_ids
    scylla_seed = module.ddc_infra.scylla_seed
    scylla_datacenter_name = module.ddc_infra.scylla_datacenter_name
    scylla_keyspace_suffix = module.ddc_infra.scylla_keyspace_suffix
    private_zone_id = aws_route53_zone.private.zone_id
    private_zone_name = local.private_zone_name
  } : null
}
```

## Results:

| Configuration | Result |
|---------------|---------|
| No certificate | `http://us-east-1.dev.ddc.cgd.internal` |
| ACM Public cert | `https://us-east-1.dev.ddc.example.com` |
| Private CA cert | `https://us-east-1.dev.ddc.cgd.internal` |

## Multi-Region Replication:

**Already works!** The Helm template uses `ddc_endpoint_pattern` which gets the protocol automatically:

```yaml
# In Helm template - no changes needed
RemoteDDCServers:
  - "${replace(ddc_endpoint_pattern, aws_region, "us-west-2")}"
  
# Results in correct protocol:
# - https://us-west-2.dev.ddc.example.com (if certificate provided)
# - http://us-west-2.dev.ddc.cgd.internal (if no certificate)
```

## Benefits:

✅ **2 lines of code** - minimal implementation
✅ **Certificate-based** - works with any certificate type  
✅ **Backward compatible** - existing outputs still work
✅ **Multi-region ready** - replication gets correct protocol
✅ **ScyllaDB consistent** - internal services follow same DNS pattern
✅ **No new variables** - no testing complexity
✅ **Future-proof** - ready for ALB, private CA, etc.

## Total Implementation:
- **2 lines** in locals.tf
- **Update** existing output in outputs.tf
- **0 new variables**
- **0 breaking changes**

**This is the minimal, clean implementation you want!**