# Multi-Region Basic DDC Example

This example demonstrates a multi-region DDC deployment with cross-region replication for globally distributed teams.

## Overview

This example creates:
- Primary Region (us-east-1): Full DDC infrastructure with seed node
- Secondary Region (us-west-2): DDC infrastructure connecting to primary
- Cross-region replication for ScyllaDB and DDC data
- Regional DNS endpoints for optimal routing

## Architecture

### Multi-Region Resource Distribution

```
SHARED RESOURCES (Global - Created in Primary Region Only):
├── IAM Roles
│   ├── external-dns-role
│   ├── aws-load-balancer-controller-role  
│   ├── cert-manager-role
│   ├── fluent-bit-role
│   └── ddc-service-account-role
├── IAM Policies (attached to shared roles)
├── Bearer Token Secret (primary + cross-region replica)
└── DNS Domain Names (shared zones)

REGIONAL RESOURCES (Duplicated Per Region):
Region 1 (us-east-1):                Region 2 (us-west-2):
├── EKS Cluster                      ├── EKS Cluster
├── EKS Addons (use shared IAM)      ├── EKS Addons (use shared IAM)
├── Security Groups                   ├── Security Groups  
├── S3 Buckets                       ├── S3 Buckets
│   ├── CodeBuild assets             │   ├── CodeBuild assets
│   └── DDC storage                  │   └── DDC storage
├── CodeBuild Projects               ├── CodeBuild Projects
│   ├── cluster-setup                │   ├── cluster-setup
│   ├── ddc-deployer                 │   ├── ddc-deployer
│   └── ddc-tester                   │   └── ddc-tester
├── Terraform Actions               ├── Terraform Actions
├── ScyllaDB Cluster                 ├── ScyllaDB Cluster
├── Route53 Records                  ├── Route53 Records
└── CloudWatch Logs                  └── CloudWatch Logs
                ↑                                    ↑
                └─── Cross-region replication ──────┘
                     (ScyllaDB + Secrets)
```

### Service Flow Diagram

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
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.16.0, < 3.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc_primary"></a> [unreal\_cloud\_ddc\_primary](#module\_unreal\_cloud\_ddc\_primary) | ../../.. | n/a |
| <a name="module_unreal_cloud_ddc_secondary"></a> [unreal\_cloud\_ddc\_secondary](#module\_unreal\_cloud\_ddc\_secondary) | ../../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.ddc_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.ddc_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.ddc_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.ddc_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.primary_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_default_security_group.secondary_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.primary_nat_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip.secondary_nat_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.primary_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_internet_gateway.secondary_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.primary_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_nat_gateway.secondary_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.primary_private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.primary_to_secondary_peering](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.secondary_private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.secondary_to_primary_peering](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.ddc_cert_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ddc_cert_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.primary_ddc_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.secondary_ddc_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route_table.primary_private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.primary_public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.secondary_private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.secondary_public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.primary_private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.primary_public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.secondary_private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.secondary_public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.allow_my_ip_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.allow_my_ip_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_cross_region_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_cross_region_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.primary_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.primary_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.secondary_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.secondary_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_peering_connection.primary_to_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |
| [aws_vpc_peering_connection_accepter.secondary_accept](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_accepter) | resource |
| [aws_vpc_security_group_ingress_rule.allow_http_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_http_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_icmp_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_icmp_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_cql_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_cql_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_gossip_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_gossip_secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_availability_zones.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ghcr_credentials_secret_arn"></a> [ghcr\_credentials\_secret\_arn](#input\_ghcr\_credentials\_secret\_arn) | ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub | `string` | `"arn:aws:secretsmanager:us-east-1:644937705968:secret:ecr-pullthroughcache/UnrealCloudDDC-XLISDD"` | no |
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records. | `string` | `"novekm.people.aws.dev"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_us-east-1"></a> [us-east-1](#output\_us-east-1) | All outputs for us-east-1 region |
<!-- END_TF_DOCS -->