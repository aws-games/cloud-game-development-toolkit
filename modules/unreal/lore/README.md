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
| [multi-region](examples/multi-region/) | **Experimental, not production-ready.** Two offices: a regional cache in a second region; the write tier tries to prefill it, and missed fragments load on demand |

## Multi-region

> [!WARNING]
> **Experimental. Not production-ready.** The multi-region inputs, the
> [regional-cache](modules/regional-cache/) sub-module and the
> [multi-region example](examples/multi-region/) have been exercised in test deployments only.
> Inputs may change without a migration path. There is no Region failover: losing the whole write
> Region blocks durable writes, locks, branch reads and cache misses. A write-tier task outage is
> narrower. See [Failure behavior](modules/regional-cache/README.md#failure-behavior) before relying
> on this design.

For a studio with offices in two places, run the write tier in one region and a
[regional cache](modules/regional-cache/) in the other. The write region stays the single source
of truth: one S3 bucket, one set of DynamoDB tables. The regional cache is a Lore server with an
NVMe cache and no storage of its own. The write tier attempts to push each stored fragment into
it. A missed push is filled from the write tier when the cache first needs that fragment.

One rule: **branch pointers and locks live in exactly one region.** Fragments are immutable and
content-addressed, so a cache copy can never be wrong. An MRSC Global Table preserved
compare-and-swap across 40 tested races, but added cross-region latency. Lore's transactional
lock calls cannot use MRSC Global Tables. MREC Global Tables allowed acknowledged concurrent
pushes to vanish in the same test sweep. This example therefore keeps both tables in the write
region. The public multi-region example creates a DynamoDB interface endpoint in the write VPC.
The cache sets Lore's mutable-store and lock-store DynamoDB endpoint URLs, so branch-pointer
and lock calls use private endpoint ENIs over VPC peering instead of the cache VPC's NAT. Private
DNS stays off: the write tier keeps using its free same-Region DynamoDB gateway endpoint. Reads of
cached content stay local. Choose the write region by where most commits and pushes happen.

Inputs involved on the write tier: `replication_ingress_cidrs`, `replication_peers`,
`dynamodb_endpoint_client_cidrs`, `dynamodb_endpoint_subnet_ids`, `trusted_ca_pem`,
`vpc_peering_routes`. Pass `dynamodb_interface_endpoint_url` to the regional cache as
`dynamodb_endpoint_url`. See [examples/multi-region](examples/multi-region/).

The interface endpoint is optional for compatibility. Null `dynamodb_endpoint_client_cidrs`
disables it, and a cache without `dynamodb_endpoint_url` uses DynamoDB's public regional endpoint.
For an existing VPC, give one `dynamodb_endpoint_subnet_ids` value per Availability Zone and
manage both peering directions yourself. To disable a live endpoint safely, first clear the cache
URL and deploy the replacement task. Remove the endpoint CIDRs in a second apply.

**The published multi-region example requires external JWT authentication on client port
41337.** Port 41340 is network-protected, not JWT-protected. JWT validation (`auth_mode`) applies
to the client port only. The replication port checks neither JWTs nor client certificates (there
is no mTLS), so anything that can reach it can read and write fragments. Its security-group
rules are its only access control: set `replication_ingress_cidrs` to the regional cache's private
subnet CIDRs (regional-cache output `private_subnet_cidrs`), not the whole peered VPC, and never
to office or public ranges.

Before applying any change to an existing VPC created by this module, read the
[route ownership note](modules/vpc/README.md#route-ownership): the private route table manages
its full route set, and a plan that removes a route you did not declare must not be applied.

## Documentation

For full Lore documentation including getting started guides, scaling, authentication modes, and security, visit [lore.org](https://lore.org).

## Need Help?

Open an issue with your Terraform version, error output, and what you've already tried.
