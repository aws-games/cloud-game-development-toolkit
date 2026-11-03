# Multi-Region Example

> [!WARNING]
> **Experimental. Not production-ready.** For evaluation in a non-production account only. It
> sets `force_destroy` on and deletion protection off, has no failover, and its inputs may change
> without a migration path. Read [Failure behavior](#failure-behavior) first.

Two offices, one repository. The write region holds the only durable copy. The other region
runs a regional cache. The write tier tries to prefill it, and cache misses load on demand.

## What it creates

| Region | Resources |
|---|---|
| `write_region` (default us-east-2) | Lore write tier (c8gd.large), the S3 fragments bucket and all four DynamoDB tables, Cloud Map |
| `replica_region` (default us-west-2) | Lore regional cache (c8gd.large, NVMe cache only), Cloud Map |
| both | VPC peering with routes; each side's private DNS zone associated with the other VPC |

The regional cache has no bucket and no tables. Its cache sits over the write tier, and the
write tier lists it as a replication peer. The write tier attempts to push each stored fragment
into the cache. A missed push is filled from the write tier on the first cache miss.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Set both image URIs, both offices' CIDRs, and your IdP values.
# The example requires HTTPS JWT authentication on both tiers.

terraform init
terraform apply
```

For an existing deployment, inspect the route-table diff. Do not apply a plan that removes
GuardDuty Runtime Monitoring or other service-managed routes; there is no safe in-place
migration. Follow the [route ownership](../../modules/vpc/README.md#route-ownership)
prerequisites first.

The `loreserver` image (`v0.12.0` in `terraform.tfvars.example`) must exist in **both** regions'
ECR. Replicate the repository (`aws ecr put-replication-configuration`) rather than pulling
across regions. The failure measurements below were taken with v0.10.1; re-check them on the
version you deploy.

## Authentication

Both tiers validate JWTs from one HTTPS identity provider on client port 41337. Set
`auth_jwk_endpoint`, `auth_jwt_issuer`, and at least one `auth_jwt_audience` value. The example
has no unauthenticated mode: configure the Lore CLI with a token from that provider before
connecting. Keep the office CIDRs narrow as a second access boundary.

Replication port 41340 is **not** JWT-protected and has no mTLS. Only security-group rules
protect it, so the example limits it to each tier's private subnet CIDRs
(`private_subnet_cidrs` outputs), not the whole VPCs. Do not widen those rules.

## Connect

Each office connects to the server in its own region:

```bash
# write-region office
lore clone lores://write-tier.lore-dev.internal:41337/my-repo
# replica-region office
lore clone lores://regional-cache.lore-dev-replica.internal:41337/my-repo
```

Both names resolve only inside the VPCs (private hosted zones), so clients reach them over VPN,
Direct Connect, or from instances in the VPC.

## What crosses the regions

| Operation from the replica-region office | Crosses? |
|---|---|
| read, clone, sync of content already cached | no: served by the regional cache |
| read after a missed push, eviction or cache replacement | yes: fetched from the write tier, then cached |
| commit (fragment upload) | yes: stored in the write region before the commit returns |
| push, `lore lock`, branch-pointer reads in `status` | yes: the write region's DynamoDB tables |

## Failure behavior

Measured in test deployments: a replaced cache task showed "Disconnected" for up to 10 s
(Cloud Map TTL). A cache booting with the write tier was not yet resolvable when the write tier
started, so the module now re-resolves peers every `replication_peer_refresh_seconds` (default
300 s). With Lore v0.12.0, the write-tier ECS task was stopped for about 10 minutes while S3 and
DynamoDB stayed healthy. London `status`, `sync`, history, lock status and a cached 2.5 GB clone
worked. Two London content-write commands did not finish within the 120 s harness limit.

Not measured; expected from the design:

- If only the peering link fails, fragment uploads, cache misses and peer pushes fail. With the
  default DynamoDB mode, pointer and lock calls should still reach DynamoDB through NAT.
- If the whole write Region fails, normal clone, sync, status, commit, push and lock operations
  cannot finish. Cached bytes may remain, but branch pointers and cache misses are unavailable.

There is no automatic Region failover. See the
[regional cache failure table](../../modules/regional-cache/README.md#failure-behavior).

## Tear down

```bash
terraform destroy
```

The bucket has `force_destroy` on and deletion protection off in this example. Do not copy
those settings to production.
