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

### Setup Instructions

1. **Copy the example configuration**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Update terraform.tfvars with your values**:
   ```hcl
   # terraform.tfvars
   route53_public_hosted_zone_name = "yourcompany.com"
   ghcr_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:github-ddc-credentials-XXXXXX"
   ```

3. **Create GitHub Container Registry Secret** (if not already created):
   ```bash
   aws secretsmanager create-secret \
     --name "github-ddc-credentials" \
     --description "GitHub PAT for DDC container images" \
     --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
   ```

### Configuration Overview

The example creates a complete DDC deployment:

```hcl
module "unreal_cloud_ddc" {
  source = "../../.."

  # Core Infrastructure
  project_prefix = "cgd"
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  certificate_arn = aws_acm_certificate.ddc.arn
  route53_hosted_zone_name = var.route53_public_hosted_zone_name
  
  # Load Balancer (internet-facing)
  load_balancers_config = {
    nlb = {
      internet_facing = true
      subnets = aws_subnet.public_subnets[*].id
    }
  }
  
  # Security (your IP only)
  allowed_external_cidrs = ["<your-ip>/32"]

  # DDC Application
  ddc_application_config = {
    namespaces = {
      "civ" = { description = "The Civilization series" }
      "dev-sandbox" = { description = "Development testing" }
    }
  }

  # DDC Infrastructure (EKS + ScyllaDB)
  ddc_infra_config = {
    region = "us-east-1"
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs = ["<your-ip>/32"]
    
    scylla_config = {
      current_region = {
        replication_factor = 3
      }
      subnets = aws_subnet.private_subnets[*].id
    }
  }

  # GitHub Container Registry Access
  ghcr_credentials_secret_arn = var.ghcr_credentials_secret_arn

  # Centralized Logging
  enable_centralized_logging = true
  log_retention_days = 30
}
```

## Deployment

```bash
# 1. Initialize Terraform
terraform init

# 2. Review the plan
terraform plan

# 3. Deploy (takes ~15 minutes)
terraform apply

# 4. Get connection details
terraform output
```

**Expected Output**:
```
ddc_connection = {
  endpoint_public_dns = "https://us-east-1.ddc.yourcompany.com"
  kubectl_command = "aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1"
  security_warning = null
}
```

## Verification

### 1. Test DDC Health Endpoint

```bash
# Get the endpoint from Terraform output
DDC_ENDPOINT=$(terraform output -raw ddc_connection | jq -r '.endpoint_public_dns')

# Test health endpoint
curl "$DDC_ENDPOINT/health/live"
# Expected: "HEALTHY"
```

### 2. Check Kubernetes Cluster

```bash
# Configure kubectl (use command from terraform output)
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1

# Check all pods are running
kubectl get pods -n unreal-cloud-ddc
# Expected: All pods in "Running" status

# Check TargetGroupBinding
kubectl get targetgroupbinding -n unreal-cloud-ddc
# Expected: Status shows "Ready=True"
```

### 3. Test DDC API Operations

```bash
# Get bearer token from Terraform output
BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id $(terraform output -raw bearer_token_secret_arn) --query SecretString --output text)

# Test PUT operation
curl -X PUT "$DDC_ENDPOINT/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa" \
  --data "test" \
  -H "content-type: application/octet-stream" \
  -H "X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA" \
  -H "Authorization: ServiceAccount $BEARER_TOKEN"

# Test GET operation
curl "$DDC_ENDPOINT/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json" \
  -H "Authorization: ServiceAccount $BEARER_TOKEN"
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
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.20.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc"></a> [unreal\_cloud\_ddc](#module\_unreal\_cloud\_ddc) | ../../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.ddc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.ddc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.ddc_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ddc_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.allow_my_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_ingress_rule.allow_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_icmp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_eks_cluster_auth.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ghcr_credentials_secret_arn"></a> [ghcr\_credentials\_secret\_arn](#input\_ghcr\_credentials\_secret\_arn) | ARN of the secret in AWS Secrets Manager containing GitHub credentials (username and accessToken fields) for Epic Games container registry access. You must create this secret in your AWS account. | `string` | `"arn:aws:secretsmanager:us-east-1:644937705968:secret:unreal-cloud-ddc-ghcr-token-TOLwVX"` | no |
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records. | `string` | `"novekm.people.aws.dev"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bearer_token_secret_arn"></a> [bearer\_token\_secret\_arn](#output\_bearer\_token\_secret\_arn) | ARN of the DDC bearer token secret in AWS Secrets Manager |
| <a name="output_ddc_endpoint"></a> [ddc\_endpoint](#output\_ddc\_endpoint) | DDC DNS endpoint |
| <a name="output_ddc_endpoint_nlb"></a> [ddc\_endpoint\_nlb](#output\_ddc\_endpoint\_nlb) | DDC direct NLB endpoint |
| <a name="output_scylla_instance_ids"></a> [scylla\_instance\_ids](#output\_scylla\_instance\_ids) | ScyllaDB instance IDs for SSM access |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | ScyllaDB instance private IPs |
| <a name="output_security_warning"></a> [security\_warning](#output\_security\_warning) | Security warnings for the deployment |
<!-- END_TF_DOCS -->