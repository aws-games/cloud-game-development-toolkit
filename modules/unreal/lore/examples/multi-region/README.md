# Multi-Region Example

Two offices, one repository. The write region holds the only copy of the data; the other region
runs a regional cache that the write tier keeps warm.

## What it creates

| Region | Resources |
|---|---|
| `write_region` (default us-east-2) | Lore write tier (c8gd.large), the S3 fragments bucket and all four DynamoDB tables, Cloud Map |
| `replica_region` (default us-west-2) | Lore regional cache (c8gd.large, NVMe cache only), Cloud Map |
| both | VPC peering with routes; each side's private DNS zone associated with the other VPC |

The regional cache has no bucket and no tables. Its cache sits over the write tier, and the
write tier lists it as a replication peer, so every fragment either office commits is pushed into
the second office's cache as soon as it is stored.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Set both image URIs, both offices' CIDRs, and your IdP values.
# The example requires HTTPS JWT authentication on both tiers.

terraform init
terraform apply
```

The `loreserver` image must exist in **both** regions' ECR. Replicate the repository
(`aws ecr put-replication-configuration`) rather than pulling across regions.

## Authentication

Both tiers validate JWTs from one HTTPS identity provider. Set `auth_jwk_endpoint`,
`auth_jwt_issuer`, and at least one `auth_jwt_audience` value. The example has no unauthenticated
mode: configure the Lore CLI with a token from that provider before connecting. Keep the office
CIDRs narrow as a second access boundary.

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
| read, clone, sync of content either office committed | no: served from the regional cache, which the write tier fills as content is stored |
| read of content no longer in the cache (evicted, cache replaced) | yes: fetched from the write tier, then cached |
| commit (fragment upload) | yes: stored in the write region before the commit returns |
| push, `lore lock`, branch-pointer reads in `status` | yes: the write region's DynamoDB tables |

## Tear down

```bash
terraform destroy
```

The bucket has `force_destroy` on and deletion protection off in this example. Do not copy
those settings to production.
