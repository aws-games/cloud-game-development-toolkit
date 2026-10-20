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
