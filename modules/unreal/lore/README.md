# Lore on AWS

Terraform module for deploying Lore — version control for large binary game assets — on AWS.

## What This Module Creates

- **Edge pods** — NVMe-cached nodes that clients connect to for push and clone
- **Durable backend** — S3 for fragments, DynamoDB for metadata (managed by the module)
- **Observability** — CloudWatch logs, optional X-Ray tracing

You provide: a container image and a list of allowed client CIDRs.

## Prerequisites

### IAM Permissions

The IAM principal running `terraform apply` needs permissions for
EC2/VPC, ECS, Auto Scaling, IAM, S3, DynamoDB, Secrets Manager,
CloudWatch Logs, and Service Discovery. Cognito and Lambda are only
required if using `auth_mode = "cognito"` or X-Ray smoke tests.

For dev/test, `AdministratorAccess` covers everything. For production,
use the scoped policy at
[deployer-permissions.json](deployer-permissions.json).

The `VpcNetworking` statement can be omitted if you provide your own
VPC via the `vpc_id` and subnet variables.

### Other Requirements

- Terraform >= 1.9
- A Lore container image accessible to ECS (public registry or ECR)
- Client CIDRs for security group ingress rules

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

## Documentation

For full Lore documentation including getting started guides, scaling, authentication modes, and security, visit [lore.org](https://lore.org).

## Need Help?

Open an issue with your Terraform version, error output, and what you've already tried.
