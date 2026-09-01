# Default Example

Write tier + multi-edge pods with Cloud Map service discovery. No auth.

## What it creates

- Write tier: ECS on c8gd.8xlarge with S3+DynamoDB storage, Cloud Map registration
- Edge pod 1: EC2 with NVMe cache in UZ-a
- Edge pod 2: EC2 with NVMe cache in UZ-b
- Cloud Map private DNS for edge pod → write tier discovery

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit with your container image and CIDR

terraform init
terraform apply
```

## Connect

```bash
lore clone lores://<edge_1_ip>:41337/my-repo
```

## Tear down

```bash
terraform destroy
# Takes ~12 minutes (capacity provider reconciliation)
```
