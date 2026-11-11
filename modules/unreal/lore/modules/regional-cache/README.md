# Regional Cache Sub-Module

> [!WARNING]
> **Experimental. Not production-ready.** Exercised in test deployments only. Inputs may change
> without a migration path. There is no Region failover. Losing the whole write Region blocks
> durable writes, locks, branch reads and cache misses. A write-tier task outage is narrower.
> See [Failure behavior](#failure-behavior).

A Lore server in a second region, for a studio with offices in two places. It has an NVMe cache
and no storage of its own: the write region's S3 bucket and DynamoDB tables stay the single
source of truth.

## How it works

| | Write tier (root module) | Regional cache (this module) |
|---|---|---|
| Fragments (file content, trees) | S3 bucket + DynamoDB index, durable | **NVMe cache** over the write tier (`immutable_store.composite.durable.mode = "replicated"`) |
| New content arriving | stored, then an immediate push to every replication peer is attempted | receives successful pushes; a missed fragment loads from the write tier on the first cache miss |
| Uploads (commit) from this office | — | forwarded to the write tier; the commit returns once it is stored there |
| Cache miss | S3 | the write tier, over QUIC (41340) |
| Branch pointers and locks | DynamoDB | **the write region's DynamoDB tables**, through its interface endpoint over VPC peering when `dynamodb_endpoint_url` is set |

Fragments are immutable and content-addressed, so a cache cannot hold a wrong version. An MRSC
Global Table preserved compare-and-swap across 40 tested races, but added cross-region latency.
Lore's transactional lock calls cannot use MRSC Global Tables. MREC Global Tables allowed
acknowledged concurrent pushes to vanish in the same test sweep. This module therefore keeps
branch pointers and locks in the write region.

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
  write_tier_replication_cidrs  = module.lore.private_subnet_cidrs  # 41340 access, see below
  write_tier_dns_name           = module.lore.write_tier_dns_name
  write_tier_ca_certificate_pem = module.lore.ca_certificate_pem
  dynamodb_endpoint_url          = module.lore.dynamodb_interface_endpoint_url
  mutable_store_table_name      = module.lore.mutable_store_table_name
  mutable_store_table_arn       = module.lore.mutable_store_table_arn
  locks_table_name              = module.lore.locks_table_name
  locks_table_arn               = module.lore.locks_table_arn
}
```

The root module needs the mirror of this:
`replication_ingress_cidrs = module.regional_cache.private_subnet_cidrs`,
`dynamodb_endpoint_client_cidrs = module.regional_cache.private_subnet_cidrs`,
`replication_peers = [{ address = module.regional_cache.cache_dns_name, locality = "OtherRegion" }]`
and `trusted_ca_pem = module.regional_cache.ca_certificate_pem`. The two VPCs must be peered, with
routes passed as `vpc_peering_routes` on both sides, and each side's Cloud Map hosted zone
associated with the other VPC. `examples/multi-region` wires all of it. The CA outputs contain
generated CAs and are null with custom TLS; custom-certificate deployments pass their CA bundles
directly instead.

## Access control

| Port | Who reaches it | Protected by |
|---|---|---|
| 41337 (gRPC/QUIC, clients) | this office's clients; the write tier | security group; external JWT validation when configured. The published example requires it |
| 41339 (HTTP) | this office's clients | security group; HMAC on presigned URLs |
| 41340/UDP (internal QUIC replication) | the write tier; other cache tasks | **mutual TLS and security group** |

Port 41340 has no JWT layer because it uses mutual TLS. Every active listener verifies client
certificates, and every replicated-store or topology client uses `lores://` so it validates the
server certificate. Generated deployments use separate `serverAuth` and `clientAuth`
certificates per tier. `write_tier_ca_certificate_pem` trusts the write tier; the root module's
`trusted_ca_pem` trusts this cache. Lore refuses to start the internal listener without its
certificate triple, and Terraform rejects cross-region wiring without peer CA material.

Keep the security-group path narrow as defense in depth:

- `write_tier_replication_cidrs`: the write tier's private subnet CIDRs (root output
  `private_subnet_cidrs`). Null falls back to the whole `write_region_vpc_cidr`.
- On the root module, `replication_ingress_cidrs`: this cache's private subnet CIDRs (output
  `private_subnet_cidrs`), not its VPC CIDR.
- Never put office, VPN or public ranges on 41340. The module opens UDP only; internal gRPC/TCP
  stays disabled.

For custom TLS, supply all five certificate inputs: server certificate, server key, a dedicated
Lore CA bundle with the complete issuer chain and trust anchors, dedicated replication-client
certificate, and client key. The server certificate needs `serverAuth` plus SANs for the cache's
Cloud Map name and `loreserver.internal` for IP-addressed peers; the client certificate needs
`clientAuth`. Any client certificate chaining to a configured CA receives blanket internal-storage
access, so do not use a shared enterprise CA. If custom secrets use a customer-managed KMS key,
attach a scoped `kms:Decrypt` grant to this module's `execution_role_arn` output; generated secrets
use the Secrets Manager service key. Generated certificates become renewable 30 days before expiry
and automatically change the ECS task definition. For custom secrets, change
`tls_material_version` whenever their contents rotate.

When upgrading an existing deployment that did not use mTLS, deploy this regional cache first. Its
new client can still connect to and validate the old server-only TLS listener, while old write-tier
pushes to the new cache may fail temporarily. Deploy the write tier second so both directions then
require mTLS. Use targeted, reviewed applies when route-table drift is present.

DynamoDB access:

- Set `dynamodb_endpoint_url` to the root module's `dynamodb_interface_endpoint_url` output. The
  compute task gives it to Lore's mutable-store and lock-store DynamoDB clients through their
  native `dynamodb_endpoint_url` settings.
- The root endpoint has private DNS off and an endpoint-specific TLS name. Its security group
  admits HTTPS only from this cache's private subnet CIDRs, and its policy names only the mutable
  store, lock table and lock index.
- Null keeps the legacy public regional endpoint through this VPC's NAT. The published example
  does not use that fallback.

Authentication:

- `auth_mode` accepts `"none"` or `"external"`. For a Cognito write region use `"external"` with
  the root module's `auth_jwk_endpoint` and `auth_jwt_issuer` outputs.
- With `"external"`, the plan fails unless `auth_jwk_endpoint` and `auth_jwt_issuer` are
  `https://` URLs and `auth_jwt_audience` has at least one nonempty value.
- `branch_pointer_access = "write_tier"` is rejected with authentication enabled. The cache does
  not forward client tokens to the write tier, so an authenticated write tier would refuse the
  forwarded branch-pointer calls. Use the default `"dynamodb"`.

## Failure behavior

Measured in test deployments (Lore v0.10.1 unless noted):

| Event | Observed |
|---|---|
| Cache task replaced | New task IP; clients saw "Disconnected" for up to the Cloud Map TTL (10 s) |
| Both tiers boot together | The cache's DNS name did not exist when the write tier started. With a plain fixed topology the peer was lost until restart; the module now re-resolves peers every `replication_peer_refresh_seconds` (default 300 s) |
| Write-tier ECS task stopped for about 10 minutes, while S3 and DynamoDB stayed healthy (v0.12.0; legacy NAT/public DynamoDB path) | London `status`, `sync`, history, lock status and a cached 2.5 GB clone worked. Two London content-write commands did not finish within the 120 s harness limit |
| `branch_pointer_access = "write_tier"` | `lore repository list` fails (`RemoteMutableStore::list` is not implemented); push 0.98 s vs 0.87 s at 55 ms RTT, 2.29 s vs 1.94 s at 136 ms |
| MRSC Global Table for branch pointers (locks stayed single-Region) | Compare-and-swap held across 40 race rounds, but each office paid cross-Region latency. Lore lock calls use `TransactWriteItems`, which MRSC Global Tables reject |
| Earlier design, storage-layer replication (removed) | ~22 s window where far reads failed and content was logged as lost; the reason this module has no storage of its own |

Not measured; expected from the design, and to be verified before production use:

- **Peering link down, write Region healthy:** fragment uploads, cache misses and peer pushes over
  ports 41337/41340 fail. With `dynamodb_endpoint_url` set, branch-pointer and lock calls fail too
  because endpoint ENIs sit in the write VPC. The null fallback can still use the public DynamoDB
  endpoint through NAT, but the published example does not use that path.
- **Whole write Region lost:** normal clone, sync, status, commit, push and lock operations cannot
  finish. Cached fragment bytes may remain on NVMe, but branch pointers and cache misses are
  unavailable. There is no automatic failover.
- **Cache instance store lost (instance replaced):** the cache starts empty and refills from the
  write tier on demand, so first reads cross Regions.
- **Write-tier push to this cache fails, or happens before the cache name resolves:** the commit
  still succeeds in the write region; the fragment is fetched from the write tier on the first
  cache miss here.

## Sizing

The cache keeps everything either office commits until it fills, then evicts least recently
used content. A cache at least as large as the working set the second office reads keeps nearly
every read local. 80 % of the instance store is used by default (94 GB on a c8gd.large).

## Choosing the write region

Put the write tier near the office that commits and pushes the most. From the other office,
commits upload to the write region, and `push`, `lore lock` and the branch-pointer part of
`status` each make DynamoDB calls in the write region. With `dynamodb_endpoint_url`, those calls
reach private endpoint ENIs over VPC peering. Reads of content that is in the cache never leave
the region.

## First apply and restarts

Both sides need the other's DNS record to exist, which it does not when both boot at once;
replication peers are re-resolved every `replication_peer_refresh_seconds` (default 300) on the
write tier. After the cache task is replaced it has a new IP; clients may see "Disconnected" for
up to the Cloud Map TTL (10 s).

## Branch pointers: DynamoDB or the write tier

`branch_pointer_access` selects how the cache reaches the write region's branch pointers.
The default, `"dynamodb"`, uses the write region's DynamoDB table directly. When
`dynamodb_endpoint_url` is set, the AWS SDK reaches that table through the write VPC's interface
endpoint over peering. `"write_tier"` uses Lore's `remote` mutable store (what the edge pod uses)
to forward each operation to the write tier. Measured from a far-region client with Lore v0.10.1, forwarding was slightly slower
(small push 0.98 s vs 0.87 s at 55 ms RTT, 2.29 s vs 1.94 s at 136 ms), and
`lore repository list` fails through it because the remote store does not implement `list`.
Clone, commit, push and sync worked in both modes without authentication. `"write_tier"` is
rejected when `auth_mode = "external"` until token forwarding is implemented.

To disable a live interface endpoint, first set this module's `dynamodb_endpoint_url` to null and
deploy the replacement cache task. In a second apply, set the root module's
`dynamodb_endpoint_client_cidrs` to null. This keeps old tasks from using a deleted endpoint.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.71.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute"></a> [compute](#module\_compute) | ../compute | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_private_dns_namespace.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.tier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.peers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.write_region_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.peer_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_grpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_region_replication_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | Specific CIDR blocks of this office's clients allowed to reach the cache on 41337 and 41339. Public catch-all ranges are rejected. | `list(string)` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID override. Null uses the latest ECS-optimized AL2023. | `string` | `null` | no |
| <a name="input_asg_desired_size"></a> [asg\_desired\_size](#input\_asg\_desired\_size) | n/a | `number` | `null` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | n/a | `number` | `null` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | n/a | `number` | `null` | no |
| <a name="input_auth_jwk_endpoint"></a> [auth\_jwk\_endpoint](#input\_auth\_jwk\_endpoint) | HTTPS JWKS endpoint. Required when auth\_mode = "external". | `string` | `null` | no |
| <a name="input_auth_jwt_audience"></a> [auth\_jwt\_audience](#input\_auth\_jwt\_audience) | JWT audience values accepted. Must contain at least one nonempty value when auth\_mode = "external". | `list(string)` | `[]` | no |
| <a name="input_auth_jwt_issuer"></a> [auth\_jwt\_issuer](#input\_auth\_jwt\_issuer) | HTTPS JWT issuer. Required when auth\_mode = "external". | `string` | `null` | no |
| <a name="input_auth_mode"></a> [auth\_mode](#input\_auth\_mode) | "none" or "external". JWT validation applies to client port 41337. Internal replication<br/>port 41340 does not use JWT; it always requires mutual TLS. "external" requires an HTTPS<br/>auth\_jwk\_endpoint, an HTTPS auth\_jwt\_issuer and a nonempty auth\_jwt\_audience. If the write<br/>region uses Cognito, pass "external" with the root module's auth outputs. | `string` | `"none"` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability zones for the VPC. Null uses the first two in the region. | `list(string)` | `null` | no |
| <a name="input_branch_pointer_access"></a> [branch\_pointer\_access](#input\_branch\_pointer\_access) | How this cache reaches the write region's branch pointers. "dynamodb" (default): the write<br/>region's DynamoDB table used directly. "write\_tier": Lore's remote mutable store, each<br/>operation forwarded to the write tier over QUIC; measured slightly slower for push and<br/>status, and `lore repository list` fails through it at Lore v0.10.1. Locks always use the<br/>write region's DynamoDB table, since Lore has no remote lock store.<br/>"write\_tier" is rejected when auth\_mode is not "none": this module does not forward client<br/>tokens to the write tier, so an authenticated write tier would refuse the forwarded calls. | `string` | `"dynamodb"` | no |
| <a name="input_cache_max_size_bytes"></a> [cache\_max\_size\_bytes](#input\_cache\_max\_size\_bytes) | n/a | `number` | `0` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | loreserver image URI in THIS region's ECR (pull locally; replicate the repository) | `string` | n/a | yes |
| <a name="input_container_memory_reservation"></a> [container\_memory\_reservation](#input\_container\_memory\_reservation) | n/a | `number` | `null` | no |
| <a name="input_container_user"></a> [container\_user](#input\_container\_user) | User/group for the container process | `string` | `"65534"` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | n/a | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | n/a | `number` | `66` | no |
| <a name="input_dynamodb_endpoint_url"></a> [dynamodb\_endpoint\_url](#input\_dynamodb\_endpoint\_url) | Write Region DynamoDB interface endpoint URL (root output dynamodb\_interface\_endpoint\_url). Sets Lore's native endpoint URL for branch-pointer and lock clients, so calls cross VPC peering instead of the cache VPC's NAT. Null keeps the public regional endpoint. | `string` | `null` | no |
| <a name="input_enable_otel_sidecar"></a> [enable\_otel\_sidecar](#input\_enable\_otel\_sidecar) | n/a | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable VPC flow logs to CloudWatch | `bool` | `false` | no |
| <a name="input_enable_xray_smoke_test"></a> [enable\_xray\_smoke\_test](#input\_enable\_xray\_smoke\_test) | n/a | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod), passed to the compute submodule for sizing defaults | `string` | n/a | yes |
| <a name="input_hmac_key_secret_arn"></a> [hmac\_key\_secret\_arn](#input\_hmac\_key\_secret\_arn) | n/a | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type with NVMe instance store | `string` | `"c8gd.large"` | no |
| <a name="input_locks_table_arn"></a> [locks\_table\_arn](#input\_locks\_table\_arn) | Write region's DynamoDB locks table ARN, for this tier's IAM policy | `string` | n/a | yes |
| <a name="input_locks_table_name"></a> [locks\_table\_name](#input\_locks\_table\_name) | Write region's DynamoDB locks table name (root output). Shared so exclusive checkouts taken in one office are seen in the other. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | n/a | `number` | `30` | no |
| <a name="input_mutable_store_table_arn"></a> [mutable\_store\_table\_arn](#input\_mutable\_store\_table\_arn) | Write region's mutable-store table ARN, for this tier's IAM policy | `string` | n/a | yes |
| <a name="input_mutable_store_table_name"></a> [mutable\_store\_table\_name](#input\_mutable\_store\_table\_name) | Write region's DynamoDB mutable-store table (branch pointers), used cross-region when branch\_pointer\_access = "dynamodb". | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names in this region (e.g. 'lore-dev-london'). Must differ from the write region's prefix. | `string` | n/a | yes |
| <a name="input_otel_collector_image"></a> [otel\_collector\_image](#input\_otel\_collector\_image) | n/a | `string` | `"public.ecr.aws/aws-observability/aws-otel-collector:latest"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource | `map(string)` | `{}` | no |
| <a name="input_tls_ca_certificate_secret_arn"></a> [tls\_ca\_certificate\_secret\_arn](#input\_tls\_ca\_certificate\_secret\_arn) | Secrets Manager ARN for a dedicated Lore CA bundle containing the complete issuer chain and trust anchors for the custom cache server and replication-client certificates. Do not use a shared enterprise CA. | `string` | `null` | no |
| <a name="input_tls_certificate_secret_arn"></a> [tls\_certificate\_secret\_arn](#input\_tls\_certificate\_secret\_arn) | Secrets Manager ARN for the cache server TLS leaf certificate. Null generates a private CA and server certificate. Custom TLS requires all five server, CA, and replication-client secret ARNs. | `string` | `null` | no |
| <a name="input_tls_client_certificate_secret_arn"></a> [tls\_client\_certificate\_secret\_arn](#input\_tls\_client\_certificate\_secret\_arn) | Secrets Manager ARN for the cache's dedicated port 41340 mTLS client certificate. | `string` | `null` | no |
| <a name="input_tls_client_private_key_secret_arn"></a> [tls\_client\_private\_key\_secret\_arn](#input\_tls\_client\_private\_key\_secret\_arn) | Secrets Manager ARN for the cache's dedicated port 41340 mTLS client private key. | `string` | `null` | no |
| <a name="input_tls_material_version"></a> [tls\_material\_version](#input\_tls\_material\_version) | Rollout token for custom TLS secrets. Change it whenever certificate, key, or CA contents rotate under unchanged secret ARNs. Generated TLS updates the task definition automatically. | `string` | `"1"` | no |
| <a name="input_tls_private_key_secret_arn"></a> [tls\_private\_key\_secret\_arn](#input\_tls\_private\_key\_secret\_arn) | Secrets Manager ARN for the cache server TLS private key. | `string` | `null` | no |
| <a name="input_tls_san_dns_names"></a> [tls\_san\_dns\_names](#input\_tls\_san\_dns\_names) | n/a | `list(string)` | `[]` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for this region's VPC. Must not overlap the write region's VPC (peering). | `string` | n/a | yes |
| <a name="input_vpc_peering_routes"></a> [vpc\_peering\_routes](#input\_vpc\_peering\_routes) | Routes to peered VPCs (the write region) for this cache's private route table. Use this rather than aws\_route resources, which the route table's inline routes remove on the next apply. | <pre>list(object({<br/>    cidr_block                = string<br/>    vpc_peering_connection_id = string<br/>  }))</pre> | `[]` | no |
| <a name="input_write_region"></a> [write\_region](#input\_write\_region) | AWS region of the write tier (e.g. us-east-2). Used to reach its DynamoDB locks table. | `string` | n/a | yes |
| <a name="input_write_region_rtt_ms"></a> [write\_region\_rtt\_ms](#input\_write\_region\_rtt\_ms) | Measured round-trip time to the write region in ms, used to size the QUIC congestion window for uploads and cache misses (Lore default 100). Null keeps Lore's default. | `number` | `null` | no |
| <a name="input_write_region_vpc_cidr"></a> [write\_region\_vpc\_cidr](#input\_write\_region\_vpc\_cidr) | CIDR of the write region's VPC. Allowed to and from this tier on 41337. Also used for 41340 when write\_tier\_replication\_cidrs is null; set that to the write tier's private subnet CIDRs instead. | `string` | n/a | yes |
| <a name="input_write_tier_ca_certificate_pem"></a> [write\_tier\_ca\_certificate\_pem](#input\_write\_tier\_ca\_certificate\_pem) | PEM bundle of the write tier's dedicated Lore CA chain. It validates the 41340 server certificate and authenticates write-tier replication clients. Any accepted clientAuth certificate gets blanket storage access; do not use a shared enterprise CA or include a private key. | `string` | n/a | yes |
| <a name="input_write_tier_dns_name"></a> [write\_tier\_dns\_name](#input\_write\_tier\_dns\_name) | Write tier Cloud Map name (root module output write\_tier\_dns\_name). Must resolve in this VPC: associate the write region's hosted zone (output service\_discovery\_hosted\_zone\_id) with this VPC. Used for uploads, cache misses (41340) and nothing else. | `string` | n/a | yes |
| <a name="input_write_tier_replication_cidrs"></a> [write\_tier\_replication\_cidrs](#input\_write\_tier\_replication\_cidrs) | Private CIDRs allowed to and from this cache on mTLS replication port 41340/UDP. Give the<br/>write tier's private subnet CIDRs (root output private\_subnet\_cidrs). Null falls back to<br/>write\_region\_vpc\_cidr, which is broader than needed. mTLS authenticates each peer; these<br/>CIDR rules remain network defense in depth. | `list(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ca_certificate_pem"></a> [ca\_certificate\_pem](#output\_ca\_certificate\_pem) | Generated CA certificate for this cache's server and replication-client identities. Give it to the write region as trusted\_ca\_pem for mutual authentication. Null when custom TLS secrets are used. |
| <a name="output_cache_dns_name"></a> [cache\_dns\_name](#output\_cache\_dns\_name) | Cloud Map DNS name of this cache. Give it to the write region as a replication peer (OtherRegion) and to this office's clients. |
| <a name="output_cache_security_group_id"></a> [cache\_security\_group\_id](#output\_cache\_security\_group\_id) | Security group of the cache tasks |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECS cluster name |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ECS task execution role ARN. Attach scoped kms:Decrypt permission here when custom TLS secrets use a customer-managed KMS key. |
| <a name="output_private_route_table_id"></a> [private\_route\_table\_id](#output\_private\_route\_table\_id) | Private route table, for the peering route to the write region |
| <a name="output_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#output\_private\_subnet\_cidrs) | CIDRs of the private subnets the cache runs in. Give these to the write region as replication\_ingress\_cidrs; mTLS authenticates port 41340 peers and these CIDRs provide network defense in depth. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs |
| <a name="output_service_discovery_hosted_zone_id"></a> [service\_discovery\_hosted\_zone\_id](#output\_service\_discovery\_hosted\_zone\_id) | Route 53 private hosted zone behind this tier's Cloud Map namespace. Associate it with the write region's VPC so the write tier can resolve cache\_dns\_name. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ECS task role ARN |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | VPC CIDR, for peering routes. Use private\_subnet\_cidrs, not this, for replication\_ingress\_cidrs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID of the regional cache |
<!-- END_TF_DOCS -->
