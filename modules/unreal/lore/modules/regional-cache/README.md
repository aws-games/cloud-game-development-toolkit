# Regional Cache Sub-Module

A Lore server in a second region, for a studio with offices in two places. It has an NVMe cache
and no storage of its own: the write region's S3 bucket and DynamoDB tables stay the single
source of truth.

## How it works

| | Write tier (root module) | Regional cache (this module) |
|---|---|---|
| Fragments (file content, trees) | S3 bucket + DynamoDB index, durable | **NVMe cache** over the write tier (`immutable_store.composite.durable.mode = "replicated"`) |
| New content arriving | stored, then pushed to every replication peer | **pushed into the cache by the write tier** as soon as it is stored |
| Uploads (commit) from this office | — | forwarded to the write tier; the commit returns once it is stored there |
| Cache miss | S3 | the write tier, over QUIC (41340) |
| Branch pointers and locks | DynamoDB | **the write region's DynamoDB tables**, used cross-region |

Fragments are immutable and content-addressed, so a cache can never hold a wrong version of one.
Branch pointers advance by compare-and-swap, which only works with one copy of the table, so they
stay in the write region; this module reads and writes them there.

## Usage

```hcl
module "regional_cache" {
  source    = "terraform-aws-lore//modules/regional-cache"
  providers = { aws = aws.replica }

  name_prefix           = "lore-dev-london"
  environment           = "dev"
  container_image       = var.replica_container_image   # this region's ECR
  allowed_ingress_cidrs = var.replica_office_cidrs
  vpc_cidr              = "10.20.0.0/16"                 # must not overlap the write region

  write_region                  = "us-east-2"
  write_region_vpc_cidr         = "10.10.0.0/16"
  write_tier_dns_name           = module.lore.write_tier_dns_name
  write_tier_ca_certificate_pem = module.lore.ca_certificate_pem
  mutable_store_table_name      = module.lore.mutable_store_table_name
  mutable_store_table_arn       = module.lore.mutable_store_table_arn
  locks_table_name              = module.lore.locks_table_name
  locks_table_arn               = module.lore.locks_table_arn
}
```

The root module needs the mirror of this: `replication_ingress_cidrs = ["10.20.0.0/16"]`,
`replication_peers = [{ address = module.regional_cache.cache_dns_name, locality = "OtherRegion" }]`
and `trusted_ca_pem = module.regional_cache.ca_certificate_pem`. The two VPCs must be peered, with
routes passed as `vpc_peering_routes` on both sides, and each side's Cloud Map hosted zone
associated with the other VPC. `examples/multi-region` wires all of it.

## Sizing

The cache keeps everything either office commits until it fills, then evicts least recently
used content. A cache at least as large as the working set the second office reads keeps nearly
every read local. 80 % of the instance store is used by default (94 GB on a c8gd.large).

## Choosing the write region

Put the write tier near the office that commits and pushes the most. From the other office,
commits upload to the write region, and `push`, `lore lock` and the branch-pointer part of
`status` each make DynamoDB calls in the write region. Reads of content that is in the cache
never leave the region.

## First apply and restarts

Both sides need the other's DNS record to exist, which it does not when both boot at once;
replication peers are re-resolved every `replication_peer_refresh_seconds` (default 300) on the
write tier. After the cache task is replaced it has a new IP; clients may see "Disconnected" for
up to the Cloud Map TTL (10 s).

## Branch pointers: DynamoDB or the write tier

`branch_pointer_access` selects how the cache reaches the write region's branch pointers.
The default, `"dynamodb"`, uses the write region's DynamoDB table directly. `"write_tier"` uses
Lore's `remote` mutable store (what the edge pod uses) to forward each operation to the write
tier. Measured from a far-region client with Lore v0.10.1, forwarding was slightly slower
(small push 0.98 s vs 0.87 s at 55 ms RTT, 2.29 s vs 1.94 s at 136 ms), and
`lore repository list` fails through it because the remote store does not implement `list`.
Clone, commit, push and sync work in both modes.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_compute"></a> [compute](#module\_compute) | ../compute | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../vpc | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_security_group.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_private_dns_namespace.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.peers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_replication_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.peer_replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.peer_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_replication_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | CIDR blocks of this office's clients allowed to reach the cache on 41337 and 41339 | `list(string)` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | loreserver image URI in THIS region's ECR (pull locally; replicate the repository) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod), passed to the compute submodule for sizing defaults | `string` | n/a | yes |
| <a name="input_locks_table_arn"></a> [locks\_table\_arn](#input\_locks\_table\_arn) | Write region's DynamoDB locks table ARN, for this tier's IAM policy | `string` | n/a | yes |
| <a name="input_locks_table_name"></a> [locks\_table\_name](#input\_locks\_table\_name) | Write region's DynamoDB locks table name (root output). Shared so exclusive checkouts taken in one office are seen in the other. | `string` | n/a | yes |
| <a name="input_mutable_store_table_arn"></a> [mutable\_store\_table\_arn](#input\_mutable\_store\_table\_arn) | Write region's mutable-store table ARN, for this tier's IAM policy | `string` | n/a | yes |
| <a name="input_mutable_store_table_name"></a> [mutable\_store\_table\_name](#input\_mutable\_store\_table\_name) | Write region's DynamoDB mutable-store table (branch pointers), used cross-region when branch\_pointer\_access = "dynamodb". | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names in this region (e.g. 'lore-dev-london'). Must differ from the write region's prefix. | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for this region's VPC. Must not overlap the write region's VPC (peering). | `string` | n/a | yes |
| <a name="input_write_region"></a> [write\_region](#input\_write\_region) | AWS region of the write tier (e.g. us-east-2). Used to reach its DynamoDB locks table. | `string` | n/a | yes |
| <a name="input_write_region_vpc_cidr"></a> [write\_region\_vpc\_cidr](#input\_write\_region\_vpc\_cidr) | CIDR of the write region's VPC. Allowed to reach this tier on 41337/41340 so the write tier can replicate to it; this tier is allowed out to it on the same ports. | `string` | n/a | yes |
| <a name="input_write_tier_ca_certificate_pem"></a> [write\_tier\_ca\_certificate\_pem](#input\_write\_tier\_ca\_certificate\_pem) | Write tier CA certificate (root module output ca\_certificate\_pem) so this cache trusts it over TLS | `string` | n/a | yes |
| <a name="input_write_tier_dns_name"></a> [write\_tier\_dns\_name](#input\_write\_tier\_dns\_name) | Write tier Cloud Map name (root module output write\_tier\_dns\_name). Must resolve in this VPC: associate the write region's hosted zone (output service\_discovery\_hosted\_zone\_id) with this VPC. Used for uploads, cache misses (41340) and nothing else. | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID override. Null uses the latest ECS-optimized AL2023. | `string` | `null` | no |
| <a name="input_asg_desired_size"></a> [asg\_desired\_size](#input\_asg\_desired\_size) | n/a | `number` | `null` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | n/a | `number` | `null` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | n/a | `number` | `null` | no |
| <a name="input_auth_jwk_endpoint"></a> [auth\_jwk\_endpoint](#input\_auth\_jwk\_endpoint) | n/a | `string` | `null` | no |
| <a name="input_auth_jwt_audience"></a> [auth\_jwt\_audience](#input\_auth\_jwt\_audience) | n/a | `list(string)` | `[]` | no |
| <a name="input_auth_jwt_issuer"></a> [auth\_jwt\_issuer](#input\_auth\_jwt\_issuer) | n/a | `string` | `null` | no |
| <a name="input_auth_mode"></a> [auth\_mode](#input\_auth\_mode) | Must match the write region: none, cognito, or external | `string` | `"none"` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability zones for the VPC. Null uses the first two in the region. | `list(string)` | `null` | no |
| <a name="input_branch_pointer_access"></a> [branch\_pointer\_access](#input\_branch\_pointer\_access) | How this cache reaches the write region's branch pointers. "dynamodb" (default): the write<br/>region's DynamoDB table used directly. "write\_tier": Lore's remote mutable store, each<br/>operation forwarded to the write tier over QUIC; measured slightly slower for push and<br/>status, and `lore repository list` fails through it at Lore v0.10.1. Locks always use the<br/>write region's DynamoDB table, since Lore has no remote lock store. | `string` | `"dynamodb"` | no |
| <a name="input_cache_max_size_bytes"></a> [cache\_max\_size\_bytes](#input\_cache\_max\_size\_bytes) | n/a | `number` | `0` | no |
| <a name="input_container_memory_reservation"></a> [container\_memory\_reservation](#input\_container\_memory\_reservation) | n/a | `number` | `null` | no |
| <a name="input_container_user"></a> [container\_user](#input\_container\_user) | User/group for the container process | `string` | `"65534"` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | n/a | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | n/a | `number` | `66` | no |
| <a name="input_enable_otel_sidecar"></a> [enable\_otel\_sidecar](#input\_enable\_otel\_sidecar) | n/a | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable VPC flow logs to CloudWatch | `bool` | `false` | no |
| <a name="input_enable_xray_smoke_test"></a> [enable\_xray\_smoke\_test](#input\_enable\_xray\_smoke\_test) | n/a | `bool` | `false` | no |
| <a name="input_hmac_key_secret_arn"></a> [hmac\_key\_secret\_arn](#input\_hmac\_key\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type with NVMe instance store | `string` | `"c8gd.large"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | n/a | `number` | `30` | no |
| <a name="input_otel_collector_image"></a> [otel\_collector\_image](#input\_otel\_collector\_image) | n/a | `string` | `"public.ecr.aws/aws-observability/aws-otel-collector:latest"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource | `map(string)` | `{}` | no |
| <a name="input_tls_certificate_secret_arn"></a> [tls\_certificate\_secret\_arn](#input\_tls\_certificate\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_tls_private_key_secret_arn"></a> [tls\_private\_key\_secret\_arn](#input\_tls\_private\_key\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_tls_san_dns_names"></a> [tls\_san\_dns\_names](#input\_tls\_san\_dns\_names) | n/a | `list(string)` | `[]` | no |
| <a name="input_vpc_peering_routes"></a> [vpc\_peering\_routes](#input\_vpc\_peering\_routes) | Routes to peered VPCs (the write region) for this cache's private route table. Use this rather than aws\_route resources, which the route table's inline routes remove on the next apply. | <pre>list(object({<br/>    cidr_block                = string<br/>    vpc_peering_connection_id = string<br/>  }))</pre> | `[]` | no |
| <a name="input_write_region_rtt_ms"></a> [write\_region\_rtt\_ms](#input\_write\_region\_rtt\_ms) | Measured round-trip time to the write region in ms, used to size the QUIC congestion window for uploads and cache misses (Lore default 100). Null keeps Lore's default. | `number` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ca_certificate_pem"></a> [ca\_certificate\_pem](#output\_ca\_certificate\_pem) | This cache's CA certificate. Give it to the write region as trusted\_ca\_pem so it can push fragments here over TLS. |
| <a name="output_cache_dns_name"></a> [cache\_dns\_name](#output\_cache\_dns\_name) | Cloud Map DNS name of this cache. Give it to the write region as a replication peer (OtherRegion) and to this office's clients. |
| <a name="output_cache_security_group_id"></a> [cache\_security\_group\_id](#output\_cache\_security\_group\_id) | Security group of the cache tasks |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECS cluster name |
| <a name="output_private_route_table_id"></a> [private\_route\_table\_id](#output\_private\_route\_table\_id) | Private route table, for the peering route to the write region |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs |
| <a name="output_service_discovery_hosted_zone_id"></a> [service\_discovery\_hosted\_zone\_id](#output\_service\_discovery\_hosted\_zone\_id) | Route 53 private hosted zone behind this tier's Cloud Map namespace. Associate it with the write region's VPC so the write tier can resolve cache\_dns\_name. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ECS task role ARN |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | VPC CIDR, for the write region's replication\_ingress\_cidrs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID of the regional cache |
<!-- END_TF_DOCS -->
