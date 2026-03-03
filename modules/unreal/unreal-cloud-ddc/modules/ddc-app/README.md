# DDC Application Submodule

This submodule deploys the [Unreal Cloud DDC](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine) application directly to Kubernetes using Epic's official OCI chart with yamlencode() configuration.

> **📖 For complete DDC setup and user guidance, see the [parent module documentation](../../README.md).**

**What this submodule creates**: Pulls Epic's official Helm chart from GitHub Container Registry and deploys the Unreal Cloud DDC application using Terraform-generated values files. Creates LoadBalancer service that automatically provisions AWS NLB with proper health checks. Uses external-dns addon to create predictable Route53 endpoints (e.g., `us-east-1.ddc.example.com`) that dynamically update when AWS Load Balancer Controller creates or updates NLBs.

## Prerequisites

### Required Infrastructure (from ddc-infra submodule)

- **EKS cluster** with AWS Load Balancer Controller
- **external-dns addon** for Route53 record management
- **ScyllaDB cluster** with accessible IPs
- **S3 bucket** for asset storage
- **IAM roles** for service account (IRSA)
- **Route53 hosted zone** for DNS management

### GitHub Container Registry Access

- **Epic Games organization membership** - [Join here](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)
- **GitHub Personal Access Token** with `packages:read` permission
- **AWS Secrets Manager secret** with GitHub credentials

## Configuration

### Key Variables

**Application Configuration**:

- `ddc_application_config`: Complete DDC configuration object with container image, resources, namespaces
- `namespace`: Kubernetes namespace for DDC services
- `ddc_bearer_token`: Authentication token for DDC API
- `ddc_endpoint_pattern`: DDC hostname pattern (e.g., "us-east-1.dev.ddc.example.com")

**Infrastructure Integration**:

- `service_account_arn`: IAM role ARN for DDC service account
- `database_connection`: Database connection object (type, host, port, auth)
- `s3_bucket_id`: S3 bucket for asset storage
- `ghcr_credentials_secret_arn`: GitHub credentials for container access
- `certificate_arn`: Optional ACM certificate for HTTPS listener

## Architecture: Helm Deployment with Generated Values

**Deployment Process**: This module pulls Epic's official Helm chart from GitHub Container Registry (GHCR) and deploys the Unreal Cloud DDC application using Terraform-generated values files created with `yamlencode()`.

### Key Benefits

- **Type Safety**: Terraform validates HCL structure at plan time
- **Maintainability**: All configuration in clean HCL syntax
- **Official Chart**: Uses Epic's unmodified Helm chart from GHCR
- **Generated Values**: Creates Helm values files from Terraform locals
- **Automatic NLB**: LoadBalancer service creates NLB with proper health checks
- **Predictable Endpoints**: external-dns creates consistent Route53 records (e.g., `us-east-1.ddc.example.com`)

### Configuration Overrides

The module automatically configures:

```hcl
# Direct Kestrel access (no NGINX proxy)
nginx.enabled = false
service.type = "LoadBalancer"  # Creates NLB automatically
ASPNETCORE_URLS = "http://0.0.0.0:80"
persistence.volume.hostPath.path = "/mnt/.ephemeral"  # EKS Auto Mode NVMe
```

## Infrastructure Change Behavior

### ⚠️ Automatic Redeployment on Database Changes

**When database connection changes** (from ddc-infra module):

1. **Terraform detects change** → Module input updated
2. **Helm template re-renders** → New connection configuration
3. **DDC pods restart** → ~30-60 seconds downtime
4. **Service restored** → Connects to updated database

**This ensures DDC always connects to healthy database nodes.**

## Troubleshooting

### LoadBalancer Service Issues

**Problem**: NLB not created or pods not healthy

**Solution**: Verify AWS Load Balancer Controller is running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Generated Values Inspection

**Debug Mode**: Enable `debug = true` to generate user-visible values file:

```bash
# File created at: examples/single-region/generated/helm-values/debug-unreal-cloud-ddc-values.yaml
cat generated/helm-values/debug-unreal-cloud-ddc-values.yaml
```

### Pod Health Checks

```bash
# Configure kubectl access
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check DDC pod status
kubectl get pods -n unreal-cloud-ddc
# Expected: 1/1 Running (bring-your-own NLB) or 2/2 Running (auto NLB)
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
