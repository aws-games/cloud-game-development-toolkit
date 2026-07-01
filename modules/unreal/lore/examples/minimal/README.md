# Minimal Example

Write tier only — no edge pods. For development and testing where you don't need horizontal scaling.

For production deployments, use the [default](../default/) example.

## What it creates

- Single ECS task on i4i.xlarge (NVMe-backed)
- No auth, no edge pods, no observability
- Deletion protection disabled, force destroy enabled

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit with your container image and CIDR

terraform init
terraform apply
```

## Connect

Clients connect via Cloud Map DNS (requires VPN/DirectConnect to the VPC):

```bash
lore clone lores://<write_tier_dns>:41337/my-repo
```

## Cost

~$2/month when idle (S3 storage only). Instance cost only while running.
