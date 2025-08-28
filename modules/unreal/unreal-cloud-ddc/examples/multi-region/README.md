# Unreal Cloud DDC - Multi-Region Example

This example demonstrates deploying Unreal Cloud DDC across two AWS regions with cross-region replication and VPC peering.

## Architecture

- **Primary Region**: Complete DDC infrastructure with EKS, ScyllaDB, and S3
- **Secondary Region**: Replicated infrastructure for high availability and performance
- **VPC Peering**: Secure connectivity between regions
- **DNS**: Region-specific endpoints for load balancing

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform >= 1.10.3** installed
3. **kubectl** installed for cluster management
4. **Route53 hosted zone** for DNS records
5. **GitHub credentials** stored in AWS Secrets Manager (both regions)

## Quick Start

1. **Configure variables**:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

2. **Deploy infrastructure**:
```bash
terraform init
terraform plan
terraform apply
```

3. **Configure kubectl**:
```bash
# Primary region
aws eks update-kubeconfig --region us-east-1 --name <primary-cluster-name>

# Secondary region  
aws eks update-kubeconfig --region us-east-2 --name <secondary-cluster-name>
```

## Configuration

### Required Variables

```hcl
# terraform.tfvars
project_prefix = "my-game"
environment    = "prod"
regions        = ["us-east-1", "us-east-2"]

# DNS Configuration
route53_public_hosted_zone_name = "yourdomain.com"

# GitHub Credentials (must be prefixed with 'ecr-pullthroughcache/')
github_credential_arn_region_1 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecr-pullthroughcache/github-token"
github_credential_arn_region_2 = "arn:aws:secretsmanager:us-east-2:123456789012:secret:ecr-pullthroughcache/github-token"

# Networking
vpc_cidr_region_1 = "10.0.0.0/16"
vpc_cidr_region_2 = "10.1.0.0/16"
```

### Optional Variables

```hcl
# Infrastructure sizing
eks_cluster_version  = "1.31"
scylla_instance_type = "i4i.xlarge"
scylla_node_count    = 3

# Tags
additional_tags = {
  Project   = "my-game"
  Team      = "platform"
  ManagedBy = "terraform"
}
```

## Endpoints

After deployment, you'll have:

- **Primary DDC**: `https://ddc-primary.yourdomain.com`
- **Secondary DDC**: `https://ddc-secondary.yourdomain.com`
- **Primary Monitoring**: `https://monitoring-primary.ddc.yourdomain.com`
- **Secondary Monitoring**: `https://monitoring-secondary.ddc.yourdomain.com`

## Unreal Engine Configuration

Configure your Unreal Engine project to use the nearest DDC endpoint:

```ini
# DefaultEngine.ini
[DDC]
DefaultBackend=S3
S3Region=us-east-1
S3Bucket=<primary-s3-bucket>
S3Endpoint=https://ddc-primary.yourdomain.com

# For EU/Asia teams, use secondary region
S3Region=us-east-2
S3Endpoint=https://ddc-secondary.yourdomain.com
```

## Monitoring

Access ScyllaDB monitoring dashboards:
- Primary: `https://monitoring-primary.ddc.yourdomain.com`
- Secondary: `https://monitoring-secondary.ddc.yourdomain.com`

## Troubleshooting

### Common Issues

1. **VPC Peering not working**:
   - Check security groups allow cross-region traffic
   - Verify route table entries
   - Ensure CIDR blocks don't overlap

2. **DNS resolution fails**:
   - Verify Route53 hosted zone exists
   - Check ACM certificate validation
   - Confirm load balancer is healthy

3. **ScyllaDB replication issues**:
   - Check cross-region connectivity
   - Verify ScyllaDB cluster status
   - Review CloudWatch logs

### Useful Commands

```bash
# Check EKS cluster status
kubectl get nodes
kubectl get pods -n unreal-cloud-ddc

# Test cross-region connectivity
kubectl exec -it <pod-name> -- ping <secondary-region-ip>

# View ScyllaDB status
kubectl exec -it <scylla-pod> -- nodetool status
```

## Cleanup

```bash
terraform destroy
```

**Note**: Ensure all S3 buckets are empty before destroying, as Terraform cannot delete non-empty buckets.

## Cost Optimization

- Use smaller instance types for development environments
- Consider single-region deployment if global distribution isn't needed
- Monitor CloudWatch costs and adjust retention periods
- Use Spot instances for non-production workloads (configure in infrastructure_config)

## Security Considerations

- VPC peering provides secure cross-region connectivity
- All traffic between regions stays within AWS backbone
- ScyllaDB uses TLS encryption for inter-node communication
- Load balancers use ACM certificates for HTTPS termination