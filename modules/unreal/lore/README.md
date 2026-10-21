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
| [multi-region](examples/multi-region/) | Two offices: a regional cache in a second region, kept warm by the write tier |

## Multi-region

For a studio with offices in two places, run the write tier in one region and a
[regional cache](modules/regional-cache/) in the other. The write region stays the single source
of truth: one S3 bucket, one set of DynamoDB tables. The regional cache is a Lore server with an
NVMe cache and no storage of its own; the write tier pushes every fragment it stores into it, so
the second office reads new work locally.

One rule: **branch pointers and locks live in exactly one region.** Fragments are immutable and
content-addressed, so a cache copy can never be wrong. Advancing a branch pointer is a
compare-and-swap, which only works with a single copy of the table. From the second office,
commits upload to the write region, and push, lock and `status` make DynamoDB calls there; reads
of content in the cache stay local. Choose the write region by where most commits and pushes
happen.

Inputs involved on the write tier: `replication_ingress_cidrs`, `replication_peers`,
`trusted_ca_pem`, `vpc_peering_routes`. See [examples/multi-region](examples/multi-region/).

## Documentation

For full Lore documentation including getting started guides, scaling, authentication modes, and security, visit [lore.org](https://lore.org).

## Need Help?

Open an issue with your Terraform version, error output, and what you've already tried.
