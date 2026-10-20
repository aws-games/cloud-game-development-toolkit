# Regional Tier Sub-Module

A Lore server fleet in a second region, for a studio with offices in two places. The office
near this tier reads and uploads at local speed; only pushes, locks and branch-pointer reads
travel to the write region.

## What it is, and what it is not

| | Write tier (root module) | Regional tier (this module) |
|---|---|---|
| Fragments (file content, trees) | own S3 bucket + DynamoDB index | **own S3 bucket + DynamoDB index** in this region |
| Branch pointers (mutable store) | DynamoDB here | **forwarded to the write tier** (`mutable_store = remote`) |
| Locks | DynamoDB here | **the write region's locks table**, cross-region, so an exclusive checkout taken in one office is seen in the other |
| Replication endpoint (41340) | on | on |

Fragments can live in both regions because they are immutable and content-addressed: the same
hash is the same bytes, so copies never conflict. Branch pointers cannot, because advancing one
is a compare-and-swap and DynamoDB Global Tables resolve concurrent writes last-writer-wins. Two
write regions would both report a successful push and one would be lost silently. That is the
whole reason this module exists instead of "deploy the root module twice".

## Usage

```hcl
module "regional_tier" {
  source    = "terraform-aws-lore//modules/regional-tier"
  providers = { aws = aws.replica }

  name_prefix           = "lore-dev-replica"
  environment           = "dev"
  container_image       = var.replica_container_image   # this region's ECR
  allowed_ingress_cidrs = var.replica_office_cidrs
  vpc_cidr              = "10.20.0.0/16"                 # must not overlap the write region

  write_region                  = "us-east-2"
  write_region_vpc_cidr         = "10.10.0.0/16"
  write_tier_dns_name           = module.lore.write_tier_dns_name
  write_tier_ca_certificate_pem = module.lore.ca_certificate_pem
  locks_table_name              = module.lore.locks_table_name
  locks_table_arn               = module.lore.locks_table_arn

  # Forward every local put to the write tier; S3 copies anything that was missed.
  replication_peers                  = [{ address = module.lore.write_tier_dns_name, locality = "OtherRegion" }]
  replication_destination_bucket_arn = module.lore.fragment_bucket_arn
}
```

The root module needs the mirror of this: `replication_ingress_cidrs = ["10.20.0.0/16"]`,
`replication_peers` pointing at `module.regional_tier.tier_dns_name`, `trusted_ca_pem`, and
`fragment_replication.destination_bucket_arn = module.regional_tier.fragment_bucket_arn`.
The two VPCs must be peered and each tier's Cloud Map hosted zone associated with the other
VPC. `examples/multi-region` wires all of it.

## How fragments get to the other region

Two mechanisms run together; either alone works, with trade-offs.

- **Lore peer replication** (`replication_peers`, `OtherRegion`): the server that accepts a
  commit forwards every fragment to the other tier over QUIC, which writes it to its own S3 and
  DynamoDB as a normal put. Object and index rows arrive together, so the far region never sees
  a half-written fragment. It is best-effort: a put forwarded while the far tier is down is not
  retried.
- **S3 Cross-Region Replication** (`replication_destination_bucket_arn`): copies every object
  durably. Lore writes the DynamoDB rows when the fragment is next referenced. Use it as the
  backstop, with Replication Time Control if you want a 15-minute SLA.

Do not also make the immutable DynamoDB tables Global Tables unless you are measuring: rows
then arrive about a second after a commit while the S3 object can take minutes, and Lore reads
"row present, object missing" as lost content. `immutable_tables.mode = "global_table"` exists
for that experiment.

## Choosing the write region

Put the write tier near the office that pushes most often, or whose engineers run `status`
and `lock` most. Every one of those operations from the other office costs one round trip
(about 50 ms between US regions, 130–140 ms transatlantic); reads and uploads do not.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

<!-- markdownlint-disable -->
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
| <a name="module_data"></a> [data](#module\_data) | ../storage | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../vpc | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_security_group.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_private_dns_namespace.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_vpc_endpoint.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.peers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_replication_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.peer_replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.peer_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_replication_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_dynamodb_table.fragment_metadata_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/dynamodb_table) | data source |
| [aws_dynamodb_table.fragments_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/dynamodb_table) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | CIDR blocks of this office's clients allowed to reach the tier on 41337 and 41339 | `list(string)` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | loreserver image URI in THIS region's ECR (pull locally; replicate the repository) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod), passed to the compute submodule for sizing defaults | `string` | n/a | yes |
| <a name="input_locks_table_arn"></a> [locks\_table\_arn](#input\_locks\_table\_arn) | Write region's DynamoDB locks table ARN, for this tier's IAM policy | `string` | n/a | yes |
| <a name="input_locks_table_name"></a> [locks\_table\_name](#input\_locks\_table\_name) | Write region's DynamoDB locks table name (root output). Shared so exclusive checkouts taken in one office are seen in the other. | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names in this region (e.g. 'lore-dev-west'). Must differ from the write region's prefix. | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for this region's VPC. Must not overlap the write region's VPC (peering). | `string` | n/a | yes |
| <a name="input_write_region"></a> [write\_region](#input\_write\_region) | AWS region of the write tier (e.g. us-east-2). Used to reach its DynamoDB locks table. | `string` | n/a | yes |
| <a name="input_write_region_vpc_cidr"></a> [write\_region\_vpc\_cidr](#input\_write\_region\_vpc\_cidr) | CIDR of the write region's VPC. Allowed to reach this tier on 41337/41340 so the write tier can replicate to it; this tier is allowed out to it on the same ports. | `string` | n/a | yes |
| <a name="input_write_tier_ca_certificate_pem"></a> [write\_tier\_ca\_certificate\_pem](#input\_write\_tier\_ca\_certificate\_pem) | Write tier CA certificate (root module output ca\_certificate\_pem) so this tier trusts it over TLS | `string` | n/a | yes |
| <a name="input_write_tier_dns_name"></a> [write\_tier\_dns\_name](#input\_write\_tier\_dns\_name) | Write tier Cloud Map name (root module output write\_tier\_dns\_name). Must resolve in this VPC: associate the write region's hosted zone (output service\_discovery\_hosted\_zone\_id) with this VPC. | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID override. Null uses the latest ECS-optimized AL2023. | `string` | `null` | no |
| <a name="input_asg_desired_size"></a> [asg\_desired\_size](#input\_asg\_desired\_size) | n/a | `number` | `null` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | n/a | `number` | `null` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | n/a | `number` | `null` | no |
| <a name="input_auth_jwk_endpoint"></a> [auth\_jwk\_endpoint](#input\_auth\_jwk\_endpoint) | n/a | `string` | `null` | no |
| <a name="input_auth_jwt_audience"></a> [auth\_jwt\_audience](#input\_auth\_jwt\_audience) | n/a | `list(string)` | `[]` | no |
| <a name="input_auth_jwt_issuer"></a> [auth\_jwt\_issuer](#input\_auth\_jwt\_issuer) | n/a | `string` | `null` | no |
| <a name="input_auth_mode"></a> [auth\_mode](#input\_auth\_mode) | Must match the write region: none, cognito, or external | `string` | `"none"` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability zones for the VPC. Null uses the first two in the region. | `list(string)` | `null` | no |
| <a name="input_cache_max_size_bytes"></a> [cache\_max\_size\_bytes](#input\_cache\_max\_size\_bytes) | n/a | `number` | `0` | no |
| <a name="input_container_memory_reservation"></a> [container\_memory\_reservation](#input\_container\_memory\_reservation) | n/a | `number` | `null` | no |
| <a name="input_container_user"></a> [container\_user](#input\_container\_user) | User/group for the container process | `string` | `"65534"` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | n/a | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | n/a | `number` | `66` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | n/a | `bool` | `true` | no |
| <a name="input_enable_force_destroy"></a> [enable\_force\_destroy](#input\_enable\_force\_destroy) | n/a | `bool` | `false` | no |
| <a name="input_enable_otel_sidecar"></a> [enable\_otel\_sidecar](#input\_enable\_otel\_sidecar) | n/a | `bool` | `true` | no |
| <a name="input_enable_same_region_write"></a> [enable\_same\_region\_write](#input\_enable\_same\_region\_write) | Whether SameRegion peers also receive writes (Lore default true) | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable VPC flow logs to CloudWatch | `bool` | `false` | no |
| <a name="input_enable_xray_smoke_test"></a> [enable\_xray\_smoke\_test](#input\_enable\_xray\_smoke\_test) | n/a | `bool` | `false` | no |
| <a name="input_hmac_key_secret_arn"></a> [hmac\_key\_secret\_arn](#input\_hmac\_key\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_immutable_tables"></a> [immutable\_tables](#input\_immutable\_tables) | How this region gets its two immutable DynamoDB tables (fragments, fragment-metadata).<br/>"create" makes its own (Lore writes the rows when fragments arrive by replication or local<br/>commit). "global\_table" expects them to already exist in this region as replicas created by<br/>the write region's fragment\_replication.global\_tables\_region, and looks them up by the names<br/>given. | <pre>object({<br/>    mode                         = optional(string, "create")<br/>    fragments_table_name         = optional(string)<br/>    fragment_metadata_table_name = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type with NVMe instance store | `string` | `"c8gd.large"` | no |
| <a name="input_intelligent_tiering_archive_days"></a> [intelligent\_tiering\_archive\_days](#input\_intelligent\_tiering\_archive\_days) | n/a | `number` | `90` | no |
| <a name="input_intelligent_tiering_deep_archive_days"></a> [intelligent\_tiering\_deep\_archive\_days](#input\_intelligent\_tiering\_deep\_archive\_days) | n/a | `number` | `180` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | n/a | `number` | `30` | no |
| <a name="input_otel_collector_image"></a> [otel\_collector\_image](#input\_otel\_collector\_image) | n/a | `string` | `"public.ecr.aws/aws-observability/aws-otel-collector:latest"` | no |
| <a name="input_replication_destination_bucket_arn"></a> [replication\_destination\_bucket\_arn](#input\_replication\_destination\_bucket\_arn) | Write region's fragments bucket ARN. When set, this region's commits replicate back to it (S3 Cross-Region Replication). Null for one-way replication. | `string` | `null` | no |
| <a name="input_replication_peers"></a> [replication\_peers](#input\_replication\_peers) | Lore servers this tier forwards every put to. Normally the write tier as locality = "OtherRegion". Use SameRegion with enable\_same\_region\_write = false to use the write tier as a read-only fallback for content that has not replicated yet. | <pre>list(object({<br/>    address  = string<br/>    port     = optional(number, 41340)<br/>    locality = string<br/>  }))</pre> | `[]` | no |
| <a name="input_replication_time_control"></a> [replication\_time\_control](#input\_replication\_time\_control) | Enable S3 Replication Time Control on the reverse replication rule | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource | `map(string)` | `{}` | no |
| <a name="input_tls_certificate_secret_arn"></a> [tls\_certificate\_secret\_arn](#input\_tls\_certificate\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_tls_private_key_secret_arn"></a> [tls\_private\_key\_secret\_arn](#input\_tls\_private\_key\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_tls_san_dns_names"></a> [tls\_san\_dns\_names](#input\_tls\_san\_dns\_names) | n/a | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ca_certificate_pem"></a> [ca\_certificate\_pem](#output\_ca\_certificate\_pem) | This tier's CA certificate. Give it to the write region as trusted\_ca\_pem so it can replicate here over TLS. |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECS cluster name |
| <a name="output_fragment_bucket_arn"></a> [fragment\_bucket\_arn](#output\_fragment\_bucket\_arn) | This region's fragments bucket ARN, for the write region's fragment\_replication.destination\_bucket\_arn |
| <a name="output_fragment_bucket_name"></a> [fragment\_bucket\_name](#output\_fragment\_bucket\_name) | This region's fragments bucket |
| <a name="output_private_route_table_id"></a> [private\_route\_table\_id](#output\_private\_route\_table\_id) | Private route table, for the peering route to the write region |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs |
| <a name="output_service_discovery_hosted_zone_id"></a> [service\_discovery\_hosted\_zone\_id](#output\_service\_discovery\_hosted\_zone\_id) | Route 53 private hosted zone behind this tier's Cloud Map namespace. Associate it with the write region's VPC so the write tier can resolve tier\_dns\_name. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ECS task role ARN |
| <a name="output_tier_dns_name"></a> [tier\_dns\_name](#output\_tier\_dns\_name) | Cloud Map DNS name of this tier. Give it to the write region as a replication peer, and to this office's clients and edge pods. |
| <a name="output_tier_security_group_id"></a> [tier\_security\_group\_id](#output\_tier\_security\_group\_id) | Security group of the tier tasks (attach edge pods to it with server\_security\_group\_id) |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | VPC CIDR, for the write region's replication\_ingress\_cidrs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID of the regional tier |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->