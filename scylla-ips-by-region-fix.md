# ScyllaDB Regional Monitoring Fix

## Issue

The current monitoring module groups all ScyllaDB nodes under a single region label, preventing accurate per-region metrics in dashboards when deploying across multiple regions.

**Current behavior:**
```yaml
# All nodes get same region label
- targets:
    - 10.0.1.100  # Region A node
    - 10.0.2.100  # Region B node  
    - 10.0.3.100  # Region C node
  labels:
    cluster: "unreal-cloud-ddc"
    dc: us-west-2
    region: us-west-2
```

## Fix Options

### Option 1: Multi-Region Input (Recommended)

Modify monitoring module to accept region-grouped node IPs:

**variables.tf:**
```hcl
variable "scylla_nodes_by_region" {
  type = map(object({
    region = string
    ips    = list(string)
  }))
  default = {}
  description = "ScyllaDB nodes grouped by region"
}
```

**locals.tf:**
```hcl
scylla_monitoring_user_data = <<MONITORING_EOF
# Create scylla_servers.yml with regional separation
cat << EOF | sudo tee prometheus/scylla_servers.yml
%{for region_key, region_data in var.scylla_nodes_by_region~}
- targets:
%{for ip in region_data.ips~}
    - ${ip}
%{endfor~}
  labels:
    cluster: "unreal-cloud-ddc"
    dc: ${region_data.region}
    region: ${region_data.region}
%{endfor~}
EOF
MONITORING_EOF
```

**main.tf usage:**
```hcl
module "ddc_monitoring" {
  source = "./modules/ddc-monitoring"
  
  scylla_nodes_by_region = {
    us-west-2 = {
      region = "us-west-2"
      ips    = module.ddc_infra_west.scylla_ips
    }
    us-east-1 = {
      region = "us-east-1" 
      ips    = module.ddc_infra_east.scylla_ips
    }
  }
}
```

### Option 2: Per-Region Monitoring Stacks

Deploy separate monitoring per region:

```hcl
# West region monitoring
module "ddc_monitoring_west" {
  source = "./modules/ddc-monitoring"
  region = "us-west-2"
  scylla_node_ips = module.ddc_infra_west.scylla_ips
}

# East region monitoring  
module "ddc_monitoring_east" {
  source = "./modules/ddc-monitoring"
  region = "us-east-1"
  scylla_node_ips = module.ddc_infra_east.scylla_ips
}
```

### Option 3: Prometheus Federation (Best Solution)

Implement hierarchical monitoring to solve the duplication issue:

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

**How it works:**
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
      - targets: ['10.0.1.1:9180', '10.0.1.2:9180', '10.0.1.3:9180']
        labels:
          region: 'us-east-1'
          cluster: 'unreal-cloud-ddc'
  
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
          federated_from: 'us-east-2'
```

**Benefits:**
- ✅ Single consolidated Grafana dashboard
- ✅ All regions' ScyllaDB metrics in one place
- ✅ Proper region separation and labeling
- ✅ No duplicate nodes in monitoring
- ✅ Clean regional filtering in Grafana
- ✅ Scales to multiple regions

**Implementation Requirements:**
1. Deploy monitoring stack in each region
2. Configure federation in primary region
3. Set up cross-region networking (VPC peering/transit gateway)
4. Update Grafana dashboards to use region labels

## Deployment Architecture Considerations

### Current Implementation: EC2-based

**Current Setup:**
- Prometheus runs on EC2 instance via Docker containers
- Configuration via `user_data` script in `/modules/ddc-monitoring/locals.tf`
- ScyllaDB monitoring stack downloaded and started with `start-all.sh`

**EC2 Limitations:**
- ❌ **Config changes require instance replacement** (user_data changes)
- ❌ **Downtime during updates**
- ❌ **No rolling deployments**
- ❌ **Manual scaling**
- ✅ **Simple setup**
- ✅ **Persistent local storage**
- ✅ **Pre-built monitoring stack**

### Alternative: ECS Fargate

**ECS Fargate Benefits:**
- ✅ **Rolling updates** - Zero downtime config changes
- ✅ **Dynamic configuration** - Environment variables, Parameter Store
- ✅ **Auto-scaling** - Scale Prometheus if needed
- ✅ **Health checks** - Built-in service discovery
- ✅ **No EC2 management**
- ❌ **More complex setup**
- ❌ **Requires EFS for persistent storage**
- ❌ **Need to containerize monitoring stack**

**ECS Implementation Example:**
```hcl
resource "aws_ecs_service" "prometheus" {
  name = "prometheus"
  
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100  # Zero downtime
  }
  
  task_definition = aws_ecs_task_definition.prometheus.arn
}

resource "aws_ecs_task_definition" "prometheus" {
  family = "prometheus"
  
  container_definitions = jsonencode([{
    name = "prometheus"
    environment = [
      { name = "FEDERATION_ENABLED", value = tostring(var.enable_federation) },
      { name = "FEDERATION_TARGETS", value = join(",", var.federation_targets) }
    ]
    mountPoints = [{
      sourceVolume = "prometheus-data"
      containerPath = "/prometheus"
    }]
  }])
  
  volume {
    name = "prometheus-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus.id
    }
  }
}
```

## Cross-Region Connectivity Requirements

### Network Connectivity

**For Federation to work:**
1. **VPC Peering** or **Transit Gateway** between regions
2. **Security group rules** allowing Prometheus federation port (9090)
3. **Route table updates** for cross-region traffic
4. **DNS resolution** or static IPs for federation targets

**Security Group Rules:**
```hcl
# Primary region Prometheus needs outbound to secondary
resource "aws_vpc_security_group_egress_rule" "prometheus_federation_outbound" {
  security_group_id = aws_security_group.prometheus_primary.id
  description       = "Federation to secondary region Prometheus"
  ip_protocol       = "tcp"
  from_port         = 9090
  to_port           = 9090
  cidr_ipv4         = var.secondary_region_vpc_cidr
}

# Secondary region Prometheus needs inbound from primary
resource "aws_vpc_security_group_ingress_rule" "prometheus_federation_inbound" {
  security_group_id = aws_security_group.prometheus_secondary.id
  description       = "Federation from primary region Prometheus"
  ip_protocol       = "tcp"
  from_port         = 9090
  to_port           = 9090
  cidr_ipv4         = var.primary_region_vpc_cidr
}
```

### ScyllaDB Connectivity

**Each region's Prometheus must reach local ScyllaDB nodes:**
- **Port 9180** - ScyllaDB metrics endpoint
- **Private subnet access** - Prometheus in same VPC as ScyllaDB
- **Security group rules** - Allow monitoring → ScyllaDB communication

## Configuration Variables

### New Variables Needed

```hcl
variable "ddc_monitoring_config" {
  type = object({
    # ... existing fields ...
    
    # Federation Configuration
    enable_prometheus_federation = optional(bool, false)
    federation_targets = optional(list(object({
      endpoint = string  # "https://region2-prometheus:9090"
      region   = string  # "us-east-2"
    })), [])
    
    # Deployment Method
    deployment_method = optional(string, "ec2")  # "ec2" or "ecs"
    
    # ECS-specific (when deployment_method = "ecs")
    ecs_cluster_arn = optional(string, null)
    efs_file_system_id = optional(string, null)
  })
}
```

### Usage Examples

**Primary Region (Federation + ALB):**
```hcl
ddc_monitoring_config = {
  create_scylla_monitoring_stack = true
  create_application_load_balancer = true
  
  # Federation configuration
  enable_prometheus_federation = true
  federation_targets = [{
    endpoint = "https://10.1.1.100:9090"  # Secondary region Prometheus IP
    region   = "us-east-2"
  }]
  
  deployment_method = "ec2"  # or "ecs" for rolling updates
}
```

**Secondary Region (Prometheus only):**
```hcl
ddc_monitoring_config = {
  create_scylla_monitoring_stack = true
  create_application_load_balancer = false  # No Grafana UI
  
  # No federation - just local monitoring
  enable_prometheus_federation = false
  
  deployment_method = "ec2"
}
```

## Implementation Strategy

### Phase 1: EC2 with SSM Updates
1. **Keep current EC2 deployment**
2. **Add federation variables**
3. **Use SSM documents** for config updates without instance replacement
4. **Template Prometheus config** based on federation settings

### Phase 2: Migrate to ECS (Optional)
1. **Containerize monitoring stack**
2. **Set up EFS for persistent storage**
3. **Implement ECS service with rolling deployments**
4. **Dynamic configuration via environment variables**

## Implementation

**Recommended Approach:**
1. **Start with Option 3 (Prometheus Federation) on EC2** with SSM-based config updates
2. **Consider ECS migration** for production environments requiring zero-downtime updates
3. **Ensure proper cross-region networking** before enabling federation
4. **Test federation** in development environment first