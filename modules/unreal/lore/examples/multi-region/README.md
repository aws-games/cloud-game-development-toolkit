# Multi-Region Example

Two offices, one repository. A write tier in one region, a regional tier with its own
fragment store in another, peered VPCs, and fragment replication both ways.

## What it creates

| Region | Resources |
|---|---|
| `write_region` (default us-east-2) | Lore write tier (c8gd.large), S3 fragments bucket, all four DynamoDB tables, Cloud Map |
| `replica_region` (default us-west-2) | Lore regional tier (c8gd.large), S3 fragments bucket, the two immutable DynamoDB tables, Cloud Map |
| both | VPC peering with routes, each tier's private DNS zone associated with the other VPC, S3 replication rules in both directions, Lore peer replication in both directions |

Not created: a second mutable store or locks table. Branch pointers and locks exist only in
the write region. Edge pods are not needed for an office below roughly 30 simultaneous
syncers; add them in front of either tier with `modules/edge-pod` if you outgrow that.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# set both image URIs (one per region's ECR) and both offices' CIDRs

terraform init
terraform apply
```

The `loreserver` image must exist in **both** regions' ECR. Replicate the repository
(`aws ecr put-replication-configuration`) rather than pulling across regions.

## Connect

Each office connects to its own tier:

```bash
# write-region office
lore clone lores://write-tier.lore-dev.internal:41337/my-repo
# replica-region office
lore clone lores://regional-tier.lore-dev-replica.internal:41337/my-repo
```

Both names resolve only inside the VPCs (private hosted zones), so clients reach them over
VPN, Direct Connect, or from instances in the VPC.

## What crosses the regions

| Operation from the replica-region office | Crosses? |
|---|---|
| read, clone, sync | no (local NVMe → local S3; replicated content) |
| commit (fragment upload) | no (local S3), then replicated to the write region |
| push, branch create, `lore lock`, `status` branch-pointer read | yes, one round trip each |

## Tear down

```bash
terraform destroy
```

Both buckets have `force_destroy` on and deletion protection off in this example. Do not
copy those settings to production.
