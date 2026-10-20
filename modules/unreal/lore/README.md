# Lore on AWS

Terraform module for deploying Lore — version control for large binary game assets — on AWS.

## What This Module Creates

- **Edge pods** — NVMe-cached nodes that clients connect to for push and clone
- **Durable backend** — S3 for fragments, DynamoDB for metadata (managed by the module)
- **Observability** — CloudWatch logs, optional X-Ray tracing

You provide: a container image and a list of allowed client CIDRs.

## Quick Start

```bash
cd examples/default
terraform init && terraform apply
```

Connect:

```bash
lore clone lores://<edge_pod_ip>:41337/my-repo
```

## Examples

| Example | What it adds |
|---------|--------------|
| [default](examples/default/) | 2 edge pods + durable backend |
| [cognito](examples/cognito/) | + Cognito auth, X-Ray tracing, deletion protection |
| [external-auth](examples/external-auth/) | + External IdP (Okta, Azure AD, etc.) |
| [minimal](examples/minimal/) | Backend only, no edge pods (dev/test) |
| [multi-region](examples/multi-region/) | Two offices: a regional tier with its own fragment store in a second region |

## Multi-region

For a studio with offices in two places, run the write tier in one region and a
[regional tier](modules/regional-tier/) in the other. Each office reads and uploads to its own
tier at local speed; fragments replicate between the two regions (Lore peer replication plus
S3 Cross-Region Replication as the backstop).

One rule: **branch pointers and locks live in exactly one region.** Fragments are immutable and
content-addressed, so copies never conflict. Advancing a branch pointer is a compare-and-swap,
which DynamoDB Global Tables cannot preserve (last writer wins), so a second write region would
silently lose pushes. The regional tier forwards push, lock and branch-pointer operations to the
write region, one round trip each; everything else stays local. Choose the write region by where
the push-heavy work happens.

Inputs involved on the write tier: `replication_ingress_cidrs`, `replication_peers`,
`trusted_ca_pem`, `fragment_replication`. See [examples/multi-region](examples/multi-region/).

## Documentation

For full Lore documentation including getting started guides, scaling, authentication modes, and security, visit [lore.org](https://lore.org).

## Need Help?

Open an issue with your Terraform version, error output, and what you've already tried.

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
| <a name="module_auth"></a> [auth](#module\_auth) | ./modules/auth | n/a |
| <a name="module_compute"></a> [compute](#module\_compute) | ./modules/compute | n/a |
| <a name="module_data"></a> [data](#module\_data) | ./modules/storage | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_security_group.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_private_dns_namespace.lore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.write_tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_vpc_endpoint.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.replication_cidr_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.replication_cidr_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.replication_cidr_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.replication_cidr_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.replication_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.replication_cidr_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.replication_cidr_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.replication_cidr_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.replication_cidr_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.replication_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | CIDR blocks allowed to access Lore server ports. No default — must be explicitly provided. | `list(string)` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Loreserver container image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/loreserver:latest) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — controls resource sizing defaults via locals.tf ternary chains. Only dev/staging/prod are supported because environment-aware defaults depend on these exact values. | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID override. If null, uses latest ECS-optimized AL2023. Pin in production for stability. | `string` | `null` | no |
| <a name="input_asg_desired_size"></a> [asg\_desired\_size](#input\_asg\_desired\_size) | ASG desired capacity. Null = environment-aware default (dev:0, staging:1, prod:1) | `number` | `null` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | ASG maximum size. Null = environment-aware default (dev:1, staging:1, prod:3) | `number` | `null` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | ASG minimum size. Null = environment-aware default (dev:0, staging:0, prod:1) | `number` | `null` | no |
| <a name="input_auth_jwk_endpoint"></a> [auth\_jwk\_endpoint](#input\_auth\_jwk\_endpoint) | JWK endpoint URL (required when auth\_mode = 'external') | `string` | `null` | no |
| <a name="input_auth_jwt_audience"></a> [auth\_jwt\_audience](#input\_auth\_jwt\_audience) | JWT audience values the server accepts | `list(string)` | `[]` | no |
| <a name="input_auth_jwt_issuer"></a> [auth\_jwt\_issuer](#input\_auth\_jwt\_issuer) | JWT issuer string (required when auth\_mode = 'external') | `string` | `null` | no |
| <a name="input_auth_mode"></a> [auth\_mode](#input\_auth\_mode) | Authentication mode: 'none' (open access), 'cognito' (AWS-native M2M), 'external' (bring your own IdP) | `string` | `"none"` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones (only used when vpc\_id is null). If null, uses first 2 AZs in the current region. | `list(string)` | `null` | no |
| <a name="input_cache_max_size_bytes"></a> [cache\_max\_size\_bytes](#input\_cache\_max\_size\_bytes) | NVMe cache maximum size in bytes. 0 = auto-size to 80% of instance store capacity based on instance\_type. | `number` | `0` | no |
| <a name="input_container_memory_reservation"></a> [container\_memory\_reservation](#input\_container\_memory\_reservation) | Soft memory reservation (MiB) for the loreserver container. If null, auto-sizes based on instance\_type. | `number` | `null` | no |
| <a name="input_container_user"></a> [container\_user](#input\_container\_user) | User/group for the container process (e.g., '65534', '1000:1000'). Default 65534 (nobody) for non-root. | `string` | `"65534"` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Upper limit on running tasks during deployment (% of desired\_count). | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Lower limit on running tasks during deployment (% of desired\_count). Default 66 allows single-task services to deploy without ENI deadlock on small instances. | `number` | `66` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection on DynamoDB tables. Disable for test environments. | `bool` | `true` | no |
| <a name="input_enable_force_destroy"></a> [enable\_force\_destroy](#input\_enable\_force\_destroy) | Allow S3 buckets to be destroyed even when non-empty. Use only in test environments. | `bool` | `false` | no |
| <a name="input_enable_otel_sidecar"></a> [enable\_otel\_sidecar](#input\_enable\_otel\_sidecar) | Deploy ADOT sidecar for OpenTelemetry collection (CloudWatch + X-Ray) | `bool` | `true` | no |
| <a name="input_enable_same_region_write"></a> [enable\_same\_region\_write](#input\_enable\_same\_region\_write) | Whether SameRegion replication peers also receive writes (Lore default). false turns them into read-only replicas. | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable VPC flow logs to CloudWatch. Adds IAM role and log group. | `bool` | `false` | no |
| <a name="input_enable_xray_smoke_test"></a> [enable\_xray\_smoke\_test](#input\_enable\_xray\_smoke\_test) | Deploy X-Ray pipeline smoke test Lambda (validates trace delivery + IAM permissions) | `bool` | `true` | no |
| <a name="input_fragment_replication"></a> [fragment\_replication](#input\_fragment\_replication) | Replicate the fragments bucket to a second region with S3 Cross-Region Replication. Only<br/>fragments (immutable, content-addressed) are ever replicated; the branch-pointer and lock<br/>tables stay in this region because their compare-and-swap writes do not survive<br/>multi-region replication. global\_tables\_region additionally makes the two immutable<br/>DynamoDB tables Global Tables; it exists for measurement and is off by default because rows<br/>can arrive before their S3 objects, which Lore reports as lost data (see README).<br/>destination\_ready takes the other region's fragment\_bucket\_versioning\_id so the rule is<br/>created after the destination bucket is versioned. | <pre>object({<br/>    destination_bucket_arn   = string<br/>    destination_ready        = optional(string)<br/>    replication_time_control = optional(bool, false)<br/>    global_tables_region     = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_hmac_key_secret_arn"></a> [hmac\_key\_secret\_arn](#input\_hmac\_key\_secret\_arn) | Secrets Manager ARN for HMAC signing key. If null, a random key is generated. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for ECS capacity provider | `string` | `"i4i.xlarge"` | no |
| <a name="input_intelligent_tiering_archive_days"></a> [intelligent\_tiering\_archive\_days](#input\_intelligent\_tiering\_archive\_days) | Days before fragments move to Archive Access tier. 0 disables Intelligent-Tiering entirely. | `number` | `90` | no |
| <a name="input_intelligent_tiering_deep_archive_days"></a> [intelligent\_tiering\_deep\_archive\_days](#input\_intelligent\_tiering\_deep\_archive\_days) | Days before fragments move to Deep Archive Access tier. Must be > archive\_days when both are enabled. | `number` | `180` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log group retention in days. | `number` | `30` | no |
| <a name="input_otel_collector_image"></a> [otel\_collector\_image](#input\_otel\_collector\_image) | ADOT collector image URI. Override to use a private ECR mirror. Pin to a specific tag in production. | `string` | `"public.ecr.aws/aws-observability/aws-otel-collector:latest"` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Existing private subnet IDs. Required when vpc\_id is set. | `list(string)` | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | Prefix for all resource names (e.g., 'lore', 'mystudio-lore'). Max 12 chars to fit AWS resource name limits. | `string` | `"lore"` | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Existing public subnet IDs. Required when vpc\_id is set. | `list(string)` | `null` | no |
| <a name="input_replication_ingress_cidrs"></a> [replication\_ingress\_cidrs](#input\_replication\_ingress\_cidrs) | CIDR blocks of Lore tiers in other VPCs or regions allowed to reach the write tier on 41337 (gRPC/QUIC) and 41340 (replication). Needed across inter-region VPC peering, where security-group references do not work. Give the peered VPC's CIDR, never 0.0.0.0/0. | `list(string)` | `[]` | no |
| <a name="input_replication_peer_refresh_seconds"></a> [replication\_peer\_refresh\_seconds](#input\_replication\_peer\_refresh\_seconds) | How often replication peers are re-created and their DNS names re-resolved. Lets a peer tier that was not up yet, or that has moved to a new task IP, be picked up without a restart. | `number` | `300` | no |
| <a name="input_replication_peers"></a> [replication\_peers](#input\_replication\_peers) | Other Lore servers this write tier replicates fragments to (Lore fixed topology). A tier in another region is locality = "OtherRegion": every put is forwarded to it so its region is warm before anyone asks. Address is a DNS name or IP reachable from the write tier's VPC. | <pre>list(object({<br/>    address  = string<br/>    port     = optional(number, 41340)<br/>    locality = string<br/>  }))</pre> | `[]` | no |
| <a name="input_require_instance_store"></a> [require\_instance\_store](#input\_require\_instance\_store) | Validate that instance\_type has NVMe instance store. Set false for dev/test on cheaper instances. | `bool` | `true` | no |
| <a name="input_tls_certificate_secret_arn"></a> [tls\_certificate\_secret\_arn](#input\_tls\_certificate\_secret\_arn) | Secrets Manager ARN for server TLS certificate. If null, a self-signed cert is generated. | `string` | `null` | no |
| <a name="input_tls_private_key_secret_arn"></a> [tls\_private\_key\_secret\_arn](#input\_tls\_private\_key\_secret\_arn) | Secrets Manager ARN for server TLS private key. If null, generated with self-signed cert. | `string` | `null` | no |
| <a name="input_tls_san_dns_names"></a> [tls\_san\_dns\_names](#input\_tls\_san\_dns\_names) | Additional DNS SANs for the self-signed TLS certificate | `list(string)` | `[]` | no |
| <a name="input_trusted_ca_pem"></a> [trusted\_ca\_pem](#input\_trusted\_ca\_pem) | CA certificate (PEM) of a regional tier in another region, so this write tier can replicate to it over TLS. Null for single-region deployments. | `string` | `null` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC (only used when vpc\_id is null) | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID. If null, a new VPC is created. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ca_certificate_pem"></a> [ca\_certificate\_pem](#output\_ca\_certificate\_pem) | CA certificate PEM — add to client SSL\_CERT\_FILE bundle for TLS trust |
| <a name="output_cloud_map_namespace_id"></a> [cloud\_map\_namespace\_id](#output\_cloud\_map\_namespace\_id) | Cloud Map namespace ID for edge pod service discovery |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | Cognito app client ID (null when auth\_mode != 'cognito') |
| <a name="output_cognito_client_secret"></a> [cognito\_client\_secret](#output\_cognito\_client\_secret) | Cognito app client secret (null when auth\_mode != 'cognito') |
| <a name="output_cognito_token_endpoint"></a> [cognito\_token\_endpoint](#output\_cognito\_token\_endpoint) | Cognito OAuth2 token endpoint (null when auth\_mode != 'cognito') |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | Cognito User Pool ID (null when auth\_mode != 'cognito') |
| <a name="output_dynamodb_table_arns"></a> [dynamodb\_table\_arns](#output\_dynamodb\_table\_arns) | Map of DynamoDB table ARNs |
| <a name="output_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#output\_ecs\_cluster\_arn) | ECS cluster ARN |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECS cluster name |
| <a name="output_effective_config"></a> [effective\_config](#output\_effective\_config) | Resolved configuration after environment-aware defaults |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ECS execution IAM role ARN |
| <a name="output_fragment_bucket_arn"></a> [fragment\_bucket\_arn](#output\_fragment\_bucket\_arn) | S3 bucket ARN for fragment storage |
| <a name="output_fragment_bucket_name"></a> [fragment\_bucket\_name](#output\_fragment\_bucket\_name) | S3 bucket name for fragment storage |
| <a name="output_fragment_bucket_versioning_id"></a> [fragment\_bucket\_versioning\_id](#output\_fragment\_bucket\_versioning\_id) | Known once the fragments bucket is versioned; give it to a regional tier as replication\_destination\_ready |
| <a name="output_fragment_metadata_table_name"></a> [fragment\_metadata\_table\_name](#output\_fragment\_metadata\_table\_name) | DynamoDB fragment-metadata table name |
| <a name="output_fragment_replication_role_arn"></a> [fragment\_replication\_role\_arn](#output\_fragment\_replication\_role\_arn) | IAM role S3 uses for fragment replication (null when fragment\_replication is not set) |
| <a name="output_fragments_table_name"></a> [fragments\_table\_name](#output\_fragments\_table\_name) | DynamoDB fragments table name (a regional tier reads its Global Table replica by this name) |
| <a name="output_locks_table_arn"></a> [locks\_table\_arn](#output\_locks\_table\_arn) | DynamoDB locks table ARN, for a regional tier's IAM policy |
| <a name="output_locks_table_name"></a> [locks\_table\_name](#output\_locks\_table\_name) | DynamoDB locks table name. A regional tier uses this table so exclusive checkouts are shared across offices. |
| <a name="output_mutable_store_table_arn"></a> [mutable\_store\_table\_arn](#output\_mutable\_store\_table\_arn) | DynamoDB mutable-store table ARN, for a regional tier's IAM policy |
| <a name="output_mutable_store_table_name"></a> [mutable\_store\_table\_name](#output\_mutable\_store\_table\_name) | DynamoDB mutable-store table (branch pointers). A regional tier uses this table cross-region. |
| <a name="output_private_route_table_id"></a> [private\_route\_table\_id](#output\_private\_route\_table\_id) | Private route table of the module-created VPC, for peering routes (null when an existing VPC is supplied) |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs for placing edge pods |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs |
| <a name="output_server_security_group_id"></a> [server\_security\_group\_id](#output\_server\_security\_group\_id) | Security group ID — edge pods need ingress to this group |
| <a name="output_service_discovery_hosted_zone_id"></a> [service\_discovery\_hosted\_zone\_id](#output\_service\_discovery\_hosted\_zone\_id) | Route 53 private hosted zone behind the Cloud Map namespace. Associate it with a peered VPC (aws\_route53\_zone\_association) so the write tier name resolves there. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ECS task IAM role ARN |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | CIDR of the VPC the write tier runs in (null when an existing VPC is supplied) |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID for placing edge pods |
| <a name="output_write_tier_discovery_dns"></a> [write\_tier\_discovery\_dns](#output\_write\_tier\_discovery\_dns) | Cloud Map DNS for edge pod → write tier (gRPC:41337 + QUIC:41340) |
| <a name="output_write_tier_dns_name"></a> [write\_tier\_dns\_name](#output\_write\_tier\_dns\_name) | Cloud Map DNS name of the write tier, for a regional tier's mutable\_store\_remote\_url and replication peers |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->