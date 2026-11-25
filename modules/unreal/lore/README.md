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

Inputs involved on the write tier: `enable_internal_replication` (same-VPC edge pods),
`replication_ingress_cidrs`, `replication_peers`, `dynamodb_endpoint_client_cidrs`,
`dynamodb_endpoint_subnet_ids`, `trusted_ca_pem`, and `vpc_peering_routes`. Cross-region
replication inputs enable the internal listener automatically. Pass
`dynamodb_interface_endpoint_url` to the regional cache as `dynamodb_endpoint_url`. See
[examples/multi-region](examples/multi-region/).

The interface endpoint is optional for compatibility. Null `dynamodb_endpoint_client_cidrs`
disables it, and a cache without `dynamodb_endpoint_url` uses DynamoDB's public regional endpoint.
For an existing VPC, give one `dynamodb_endpoint_subnet_ids` value per Availability Zone and
manage both peering directions yourself. To disable a live endpoint safely, first clear the cache
URL and deploy the replacement task. Remove the endpoint CIDRs in a second apply.

**The published multi-region example requires external JWT authentication on client port
41337.** JWT validation (`auth_mode`) applies to the client port only. Internal replication port
41340 has no JWT layer because it uses mutual TLS instead. Every active 41340 listener requires a
client certificate, and every client uses a `lores://` URL so it validates the server certificate.
The module generates separate `serverAuth` and `clientAuth` identities for each tier. Each edge pod
generates its own dedicated client CA and identity; the write tier trusts those CA outputs without
sharing its private key with client-facing nodes. It combines its local CA with `trusted_ca_pem` so
regional tiers and approved edge pods authenticate one another. A plan with explicit edge support,
cross-VPC ingress, or an `OtherRegion` peer fails when the required trust bundle is absent.

Security groups remain defense in depth. Set `replication_ingress_cidrs` to the regional cache's
private subnet CIDRs (regional-cache output `private_subnet_cidrs`), not the whole peered VPC, and
never to office or public ranges. Only UDP 41340 is opened; the unused internal gRPC/TCP listener
stays disabled. By itself, a single-region root module neither starts port 41340 nor adds its
same-tier rule unless `enable_internal_replication = true`. An edge module can add its own
security-group reference, but without that root flag no process listens and replication fails
closed. Add every edge pod's `replication_client_ca_certificate_pem` output to `trusted_ca_pem`.

For custom TLS, provide all server certificate, server key and CA-chain secret ARNs. If this tier
connects to replication peers, also provide a dedicated client certificate and key. The server
certificate must carry `serverAuth` and SANs for every Cloud Map name peers use, plus
`loreserver.internal` for IP-addressed peers. The client certificate must carry `clientAuth`.
Certificate secrets should contain the leaf; CA inputs must contain the complete issuer chain and
trust anchors Lore needs. Use CAs dedicated to Lore replication. Port 41340 grants blanket storage
access to any certificate chaining to a configured CA, so do not trust a shared enterprise CA.
Missing custom material fails Terraform validation rather than starting an unauthenticated listener.
`ca_certificate_pem` is null for custom TLS, so pass the public CA PEM directly to edge pods and
peer-tier trust inputs. Secrets encrypted with a customer-managed KMS key also need a scoped
`kms:Decrypt` grant on the root `execution_role_arn`; the generated secrets use the Secrets Manager
service key. Terraform-generated CA and leaf private keys remain in Terraform state. Store state in
an encrypted, access-controlled backend, keep local state owner-only, and rotate the PKI after any
state disclosure. Generated certificates become renewable 30 days before expiry and their
certificate hash forces a new ECS task definition. When custom secret contents rotate under the
same ARNs, change `tls_material_version` to force that rollout. CA changes alter peer trust; stage
those rotations with an overlap plan rather than allowing both sides to update in an arbitrary
order.

**Upgrade an existing unauthenticated 41340 deployment in stages.** With the new configuration
loaded, use reviewed Terraform targets to provision client identities and replace regional caches
or edge pods while the old write-tier listener still accepts connections. Inspect the target graph
and make sure it does not include the write-tier ECS service. Deploy the mTLS write-tier listener
only after every client presents a certificate. Edge userdata changes force EC2 replacement because
cloud-init runs only once; each replaced edge loses its ephemeral NVMe cache and refills on demand.
The root module's new `enable_internal_replication` and edge trust wiring are breaking inputs for
existing edge deployments. Do not apply an unreviewed combined plan.

Before applying any change to an existing VPC created by this module, read the
[route ownership note](modules/vpc/README.md#route-ownership): the private route table manages
its full route set, and a plan that removes a route you did not declare must not be applied.

## Documentation

For full Lore documentation including getting started guides, scaling, authentication modes, and security, visit [lore.org](https://lore.org).

## Need Help?

Open an issue with your Terraform version, error output, and what you've already tried.
