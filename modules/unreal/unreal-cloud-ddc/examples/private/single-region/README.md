# Single Region Basic DDC Example

This example demonstrates a basic single-region DDC deployment suitable for small to medium teams.

## Overview

This example creates:
- VPC with public and private subnets
- Security group allowing access from your IP
- ACM certificate for HTTPS
- DDC infrastructure in a single region
- Basic DDC services configuration

## When to Use

**Ideal for:**
- Small teams (5-20 developers)
- Co-located teams (same geographic region)
- Prototyping/MVP projects
- Budget-conscious deployments

**Benefits:**
- Lower cost (single region)
- Simpler management
- Faster deployment
- Easy to understand

## Prerequisites

1. **Route53 Public Hosted Zone** - Domain for certificate validation
2. **GitHub Container Registry Access** - Epic Games organization membership and PAT

## Configuration

### Required Variables

```hcl
# terraform.tfvars
route53_public_hosted_zone_name = "yourcompany.com"
ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/your-secret"
```

### Basic Configuration

The example uses sensible defaults:

```hcl
module "unreal_cloud_ddc" {
  source = "../../"

  # Basic networking
  existing_vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_load_balancer_subnets = aws_subnet.public_subnets[*].id
  existing_service_subnets = aws_subnet.private_subnets[*].id
  existing_security_groups = [aws_security_group.allow_my_ip.id]

  # DNS and certificates
  existing_route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  existing_certificate_arn = aws_acm_certificate.ddc.arn

  # Infrastructure defaults
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    eks_api_access_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]
    scylla_subnets = aws_subnet.private_subnets[*].id
  }

  # Services defaults
  ddc_services_config = {
    region = "us-east-1"
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}
```

## Deployment

```bash
# Initialize and deploy
terraform init
terraform plan
terraform apply

# Get connection details
terraform output ddc_endpoint
terraform output security_warning  # Check for any security issues
```

## Private Access Options

Since this example deploys DDC in private subnets, you'll need a way to access the services. Here are your options:

### Option 1: AWS Client VPN (Recommended)

This example includes AWS Client VPN configuration for secure private access.

**What it provides:**
- Secure VPN tunnel to your VPC
- Access to private DDC services and EKS cluster
- No need for bastion hosts or public endpoints

**Architecture:**
```
┌─────────────────┐    VPN Tunnel    ┌──────────────────────────────────┐
│ Your Computer   │ ───────────────► │ AWS Client VPN Service           │
│ (VPN Client)    │                  │                                  │
└─────────────────┘                  └──────────────────────────────────┘
                                                      │
                                                      ▼ (Creates ENI in VPC)
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                             │
│                                                                             │
│  ┌─────────────────────┐    SOURCE NAT    ┌─────────────────────────────┐   │
│  │ VPN Endpoint ENI    │ ─────────────────► │ DDC Services (Private)      │   │
│  │ IP: 10.0.x.x        │                   │ EKS Cluster API             │   │
│  │ SG: client_vpn      │                   │ ScyllaDB                    │   │
│  └─────────────────────┘                   └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Setup:**
1. Deploy the infrastructure (includes Client VPN)
2. Download VPN configuration:
   ```bash
   aws ec2 export-client-vpn-client-configuration \
     --client-vpn-endpoint-id $(terraform output -raw client_vpn_endpoint_id) \
     --output text > ddc-client-vpn.ovpn
   ```
3. Add client certificates to the `.ovpn` file
4. Connect using any OpenVPN client

**📖 Learn more:** [AWS Client VPN User Guide](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/)

### Option 2: AWS Systems Manager Session Manager

**For EKS cluster access only:**
```bash
# Connect to EKS node via Session Manager
aws ssm start-session --target i-1234567890abcdef0

# Then use kubectl from the node
kubectl get pods -n unreal-cloud-ddc
```

### Option 3: Bastion Host

Deploy an EC2 instance in a public subnet and SSH tunnel through it.

## Verification

### Functional Test Script

Use the automated functional test script to verify your DDC deployment:

```bash
# From the private/single-region example directory (where you ran terraform apply)
chmod +x ../../../assets/scripts/ddc_functional_test.sh
../../../assets/scripts/ddc_functional_test.sh
```

**What the test does:**
- Tests DDC health endpoint
- Performs PUT operation (write to cache)
- Performs GET operation (read from cache)
- Validates bearer token authentication
- Checks EKS cluster connectivity

### Manual Health Check

```bash
# Test DDC health endpoint
curl https://us-east-1.ddc.yourcompany.com/health/live
# Expected: "HEALTHY"
```

### EKS Cluster

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1

# Check pods
kubectl get pods -n unreal-cloud-ddc
```

## Unreal Engine Configuration

> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

### Basic Setup

```ini
[DDC]
; Cloud DDC configuration
Cloud=(Type=HTTPDerivedDataBackend, Host="https://us-east-1.ddc.yourcompany.com")

; Local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)

; Try cloud first, then local
Hierarchical=(Type=Hierarchical, Inner=Cloud, Inner=Local)
```

## Scaling Up

When you outgrow this basic setup:

1. **More Developers**: See [complete example](../complete/) for advanced configuration
2. **Global Teams**: See [multi-region example](../multi-region-basic/) for cross-region setup
3. **High Availability**: Increase ScyllaDB replication factor and node counts

## Troubleshooting

### Common Issues

1. **Certificate Validation Fails**
   - Verify Route53 hosted zone ownership
   - Check domain in `route53_public_hosted_zone_name`

2. **Access Denied**
   - Check your IP: `curl https://checkip.amazonaws.com/`
   - Verify security group allows your IP

3. **Pod Image Pull Errors**
   - Verify Epic Games GitHub organization membership
   - Check GitHub PAT in AWS Secrets Manager

### Debug Commands

```bash
# Check your current IP
curl https://checkip.amazonaws.com/

# Test direct NLB access
terraform output ddc_endpoint_nlb

# Check pod logs
kubectl logs -f deployment/cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc
```

## Next Steps

- **Multi-Region**: Use the [multi-region example](../multi-region-basic/) for global teams
- **Customization**: Review the main module [README](../../README.md) for all configuration options