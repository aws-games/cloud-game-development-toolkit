# Multi-Region Basic DDC Example

This example demonstrates a multi-region DDC deployment with cross-region replication for globally distributed teams.

## Overview

This example creates:
- Primary Region (us-east-1): Full DDC infrastructure with seed node
- Secondary Region (us-west-2): DDC infrastructure connecting to primary
- Cross-region replication for ScyllaDB and DDC data
- Regional DNS endpoints for optimal routing

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US East       │───▶│us-east-1.ddc... │───▶│ EKS us-east-1   │
│  Game Devs      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US West       │───▶│us-west-2.ddc... │───▶│ EKS us-west-2   │◀─┐
│  Game Devs      │    │                  │    │                 │  │
└─────────────────┘    └──────────────────┘    └─────────────────┘  │
                                                         │           │
                                               ┌─────────────────┐  │
                                               │   ScyllaDB      │  │
                                               │  Multi-Region   │──┘
                                               └─────────────────┘
```

## When to Use Multi-Region

**Ideal for:**
- Distributed teams (US + Europe + Asia)
- Large studios (50+ developers)
- Performance-critical workflows
- Disaster recovery requirements

**Benefits:**
- Reduced latency for global teams
- Built-in disaster recovery
- Regional data compliance

## Configuration

### Primary Region Setup

```hcl
# Primary Region (us-east-1)
module "unreal_cloud_ddc_primary" {
  source = "../../"
  
  region = "us-east-1"
  
  # Bearer Token - Primary creates and replicates
  bearer_token_replica_regions = ["us-west-2"]
  
  # ScyllaDB - Creates seed node
  ddc_infra_config = {
    create_seed_node = true
    scylla_replication_factor = 3
  }
}
```

### Secondary Region Setup

```hcl
# Secondary Region (us-west-2)
module "unreal_cloud_ddc_secondary" {
  source = "../../"
  
  region = "us-west-2"
  
  # Bearer Token - Uses replicated token from primary
  create_bearer_token = false
  ddc_application_config = {
    bearer_token_secret_arn = module.unreal_cloud_ddc_primary.bearer_token_secret_arn
  }
  
  # ScyllaDB - Connects to primary seed
  ddc_infra_config = {
    create_seed_node = false
    existing_scylla_seed = module.unreal_cloud_ddc_primary.ddc_infra.scylla_seed
    scylla_replication_factor = 2  # Lower for secondary
  }
  
  # DDC Services - Replicates from primary
  ddc_services_config = {
    ddc_replication_region_url = module.unreal_cloud_ddc_primary.ddc_connection.endpoint_nlb
  }
  
  # DNS - Avoid conflicts
  create_private_dns_records = false
}
```

## Multi-Region Considerations

### DNS Strategy

**Regional Endpoints (Recommended):**

- Primary: `us-east-1.ddc.example.com`
- Secondary: `us-west-2.ddc.example.com`
- Internal: `us-east-1.ddc.internal`, `us-west-2.ddc.internal`

**Benefits:**
- Explicit control - developers choose region
- Easy debugging - clear which region
- Simple DNS - no complex routing
- UE configuration - set specific endpoint

### ScyllaDB Replication Strategy

**Balanced Approach:**

```hcl
# Primary region (us-east-1)
scylla_topology_config = {
  current_region = {
    replication_factor = 3  # Higher for primary
    node_count = 3
  }
  peer_regions = {
    "us-west-2" = {
      replication_factor = 2  # Lower for secondary
    }
  }
}

# Secondary region (us-west-2)
scylla_topology_config = {
  current_region = {
    replication_factor = 2  # Lower for secondary
    node_count = 2
  }
  peer_regions = {
    "us-east-1" = {
      replication_factor = 3  # Reference to primary
    }
  }
}
```

### Bearer Token Management

**Primary Region:**
- Creates bearer token secret
- Replicates to secondary regions
- Manages token lifecycle

**Secondary Regions:**
- Use replicated token from primary
- Set `create_bearer_token = false`
- Reference primary token ARN

## Deployment

**Single Apply**: The example uses proper Terraform dependencies, so you can deploy both regions simultaneously:

```bash
# Deploy both regions in single apply
terraform init
terraform plan
terraform apply
```

**How Dependencies Work:**
- `depends_on = [module.unreal_cloud_ddc_primary]` ensures proper order
- Secondary automatically waits for primary's ScyllaDB seed IP
- Bearer token replication handled by Terraform dependency graph

## Verification

### Multi-Region Health Check

```bash
# Test both regions
curl https://us-east-1.ddc.yourcompany.com/health/live
curl https://us-west-2.ddc.yourcompany.com/health/live
```

### ScyllaDB Cluster Status

```bash
# Connect to any ScyllaDB node
aws ssm start-session --target i-1234567890abcdef0

# Check cluster status
nodetool status
# Should show nodes from both regions
```

### Cross-Region Replication

```bash
# Write to primary region
curl -X PUT "https://us-east-1.ddc.yourcompany.com/api/v1/refs/ddc/default/test-key" \
  --data "test-data" \
  -H "Authorization: ServiceAccount <bearer-token>"

# Read from secondary region (should replicate)
curl "https://us-west-2.ddc.yourcompany.com/api/v1/refs/ddc/default/test-key.json" \
  -H "Authorization: ServiceAccount <bearer-token>"
```

## Unreal Engine Configuration

> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

### Hierarchical Setup for Global Teams

```ini
[DDC]
; Primary region (closest to most developers)
Primary=(Type=HTTPDerivedDataBackend, Host="https://us-east-1.ddc.yourcompany.com")

; Secondary region (backup/regional)
Secondary=(Type=HTTPDerivedDataBackend, Host="https://us-west-2.ddc.yourcompany.com")

; Local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)

; Try primary first, then secondary, then local
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

### Regional Configuration

**US East Coast Teams:**
```ini
[DDC]
Cloud=(Type=HTTPDerivedDataBackend, Host="https://us-east-1.ddc.yourcompany.com")
```

**US West Coast Teams:**
```ini
[DDC]
Cloud=(Type=HTTPDerivedDataBackend, Host="https://us-west-2.ddc.yourcompany.com")
```

## Troubleshooting

### Common Multi-Region Issues

1. **Secondary Region Connection Fails**
   - Verify primary region is fully deployed
   - Check ScyllaDB seed IP connectivity
   - Confirm bearer token replication

2. **Cross-Region Replication Delays**
   - Normal: 1-5 seconds for metadata
   - Check network latency between regions
   - Monitor ScyllaDB replication status

3. **DNS Resolution Issues**
   - Verify Route53 records in both regions
   - Check certificate validation for both domains
   - Test regional endpoint connectivity

### Debug Commands

```bash
# Check outputs from both regions
terraform output -json | jq '.endpoints.value'

# Test ScyllaDB connectivity
nodetool describecluster

# Check bearer token replication
aws secretsmanager describe-secret --secret-id <bearer-token-arn> --region us-west-2
```

## Cost Optimization

### Regional Sizing Strategy

**Primary Region (Higher Load):**
```hcl
ddc_infra_config = {
  scylla_instance_type = "i4i.2xlarge"
  scylla_replication_factor = 3
  nvme_managed_node_desired_size = 3
}
```

**Secondary Region (Lower Load):**
```hcl
ddc_infra_config = {
  scylla_instance_type = "i4i.large"
  scylla_replication_factor = 2
  nvme_managed_node_desired_size = 2
}
```

### Data Transfer Costs

- **Cross-region replication**: ~$0.02/GB between US regions
- **Client access**: Use regional endpoints to minimize transfer
- **S3 replication**: Consider Cross-Region Replication for disaster recovery

## Best Practices

### Deployment
- Always deploy primary region first
- Test primary region before deploying secondary
- Use sequential deployment, not parallel

### Operations
- Monitor both regions independently
- Set up cross-region alerting
- Test failover procedures regularly
- Document regional responsibilities

### Performance
- Route users to nearest region
- Monitor cross-region latency
- Consider additional regions for global teams