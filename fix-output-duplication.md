# Fix Output Duplication in Multi-Region DDC

## Issue

The multi-region example outputs contain redundant information that clutters the terminal output and duplicates data already available in the consolidated `ddc_connection` output.

**Current problematic outputs:**
```hcl
# Redundant - NLB DNS already in ddc_connection.primary/secondary.endpoint_nlb
+ ddc_primary_nlb_dns   = (known after apply)
+ ddc_secondary_nlb_dns = (known after apply)

# Redundant - ScyllaDB IPs already in ddc_connection.primary/secondary.scylla_ips
+ scylla_ips_by_region  = {
    + primary   = [...]
    + secondary = [...]
  }

# Redundant - Seed IP already in ddc_connection.primary.scylla_seed
+ scylla_seed_ip        = (known after apply)
```

## Fix

Remove redundant outputs from `examples/multi-region/outputs.tf`:

```hcl
# Multi-region DDC deployment outputs

# Keep only the consolidated connection info
output "ddc_connection" {
  description = "Complete DDC connection information for both regions"
  value = {
    primary = merge(module.unreal_cloud_ddc_primary.ddc_connection, {
      endpoint = "http://${aws_route53_record.primary_ddc_service.name}"
    })
    secondary = merge(module.unreal_cloud_ddc_secondary.ddc_connection, {
      endpoint = "http://${aws_route53_record.secondary_ddc_service.name}"
    })
  }
}

# Remove these redundant outputs:
# - ddc_primary_nlb_dns
# - ddc_secondary_nlb_dns  
# - scylla_ips_by_region
# - scylla_seed_ip
```

## Benefits

1. **Cleaner terminal output** - Less clutter during terraform apply
2. **Single source of truth** - All connection info in `ddc_connection`
3. **Consistent structure** - Matches single-region example pattern
4. **Easier consumption** - Scripts/tools only need to parse one output

## ScyllaDB Monitoring Issue

**Problem:** With centralized monitoring (single region monitoring all ScyllaDB nodes), Grafana shows **duplicated nodes** because it can't properly distinguish between regions.

**Current Issue:**
- Primary monitoring stack tries to monitor nodes in both regions
- ScyllaDB nodes appear multiple times in Grafana dashboard
- No clean way to separate nodes by region in the UI
- All nodes are mixed together with duplicates

**Solution: Prometheus Federation**

Implement a hierarchical monitoring setup:

```
┌─────────────────┐    ┌─────────────────┐
│ Primary Region  │    │Secondary Region │
│                 │    │                 │
│ Prometheus A ───┼────┼──→ ScyllaDB     │
│ (Federating)    │    │    Nodes        │
│                 │    │                 │
│ Grafana ────────┼────┼──→ Prometheus B │
│ (Single UI)     │    │    (Federated)  │
└─────────────────┘    └─────────────────┘
```

**Implementation:**
1. **Each region** gets its own Prometheus instance monitoring local ScyllaDB nodes
2. **Primary region** Prometheus federates metrics from secondary region Prometheus
3. **Single Grafana** dashboard in primary region shows all nodes with proper region labels
4. **No duplication** - each node monitored once, properly labeled by region

**Federation Configuration:**
```yaml
# Primary Prometheus config
scrape_configs:
  # Local ScyllaDB nodes
  - job_name: 'local-scylla'
    static_configs:
      - targets: ['10.0.1.1:9180', '10.0.1.2:9180']
        labels:
          region: 'us-east-1'
  
  # Federate from secondary region
  - job_name: 'federate-secondary'
    scrape_interval: 15s
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="scylla"}'
    static_configs:
      - targets: ['secondary-prometheus:9090']
        labels:
          region: 'us-east-2'
```

**Result:**
- ✅ Single consolidated Grafana dashboard
- ✅ All regions' ScyllaDB metrics in one place
- ✅ Proper region separation and labeling
- ✅ No duplicate nodes
- ✅ Clean regional filtering in Grafana

## Access Pattern

Users can still access all information through the consolidated output:
```bash
# NLB DNS names
terraform output -json ddc_connection | jq '.primary.endpoint_nlb'
terraform output -json ddc_connection | jq '.secondary.endpoint_nlb'

# ScyllaDB IPs
terraform output -json ddc_connection | jq '.primary.scylla_ips'
terraform output -json ddc_connection | jq '.secondary.scylla_ips'

# Seed IP
terraform output -json ddc_connection | jq '.primary.scylla_seed'
```