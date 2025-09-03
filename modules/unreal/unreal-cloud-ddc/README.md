# Unreal Cloud DDC (Derived Data Cache) Module

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

> **⚠️ IMPORTANT**
>
> **You MUST have Epic Games GitHub organization access to use this module.** Without access, container image pulls will fail and deployment will not work. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) to join the organization before proceeding.
>
> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

## Version Requirements

Consult the versions.tf file for requiments

**Critical Version Dependencies:**

- **Terraform >= 1.11** - Required for enhanced region support and multi-region deployments
- **AWS Provider >= 6.0** - Required for enhanced region support enabling simplified multi-region configuration
- **Kubernetes Provider >= 2.33.0** - Required for EKS cluster management and service deployment
- **Helm Provider >= 2.16.0, < 3.0.0** - Required for DDC application deployment

**DDC Application Version:**

- **Use DDC version 1.2.0** - Stable and tested
- **Avoid DDC version 1.3.0** - Has configuration parsing bugs that cause pod crashes

These version requirements enable the security patterns and multi-region capabilities used throughout this module.

## Features

- **Complete DDC Infrastructure** - Single module deploys EKS cluster, ScyllaDB database, S3 storage, and load balancers
- **Multi-Region Support** - Cross-region replication with automatic datacenter configuration
- **Security by Default** - Private subnets, least privilege IAM, restricted network access
- **Access Method Control** - External (internet) or internal (VPC-only) access patterns
- **Regional DNS Endpoints** - e.g. `<region>.ddc.example.com` pattern for optimal routing
- **Automatic Keyspace Management** - SSM automation fixes DDC replication strategy issues
- **Container Integration** - ECR pull-through cache for Epic Games container images

## Architecture

**Core Components:**

- **EKS Cluster**: Kubernetes cluster with specialized node groups (system, worker, NVME)
- **ScyllaDB**: High-performance database cluster for DDC metadata
- **S3 Bucket**: Object storage for cached game assets
- **Network Load Balancer**: External access with regional DNS endpoints
- **Route53 Private Hosted Zone**: DNS for internal routing between services (when needed)
- **Private Subnets**: All compute resources deployed privately for security

### Single Region Architecture

> **⚠️ TODO - ADD ARCHITECTURE DIAGRAM HERE**

#### Traffic Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Game Devs     │───▶│   Public NLB     │───▶│   EKS Cluster   │
│ (UE Clients)    │    │us-east-1.ddc... │    │  DDC Services   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │               ┌─────────────────┐
                                │               │   ScyllaDB      │
                                │               │   (Metadata)    │
                                │               └─────────────────┘
                                │                        │
                                │               ┌─────────────────┐
                                │               │   S3 Bucket     │
                                │               │  (Asset Data)   │
                                │               └─────────────────┘
```

### Multi-Region Architecture

> **⚠️ TODO - ADD ARCHITECTURE DIAGRAM HERE**

#### Traffic Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US East       │───▶│us-east-1.ddc... │───▶│ EKS us-east-1   │
│  Game Devs      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   US West       │───▶│us-west-2.ddc... │───▶│ EKS us-west-2   │◀─┐
│  Game Devs      │    │                  │    │                 │  │
└─────────────────┘    └──────────────────┘    └─────────────────┘  │
                                                         │           │
                                               ┌─────────────────┐  │
                                               │   ScyllaDB      │  │
                                               │  Multi-Region   │──┘
                                               └─────────────────┘
```

## Prerequisites

### Required Access & Tools

1. **Epic Games GitHub Organization Access** (CRITICAL ⚠️)

   - Must be member of Epic Games GitHub organization
   - Required to pull DDC container images
   - Follow [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)

2. **AWS Account Setup**

   - AWS CLI configured with deployment permissions
   - Route53 hosted zone for DNS records
   - VPC with public and private subnets

3. **GitHub Container Registry Access**

   - GitHub Personal Access Token with `packages:read` permission
   - Token stored in AWS Secrets Manager with `ecr-pullthroughcache/` prefix

4. **Network Planning**
   - Office/VPN IP ranges for security group access
   - VPC CIDR planning for multi-region deployments

### GitHub Container Registry Setup

#### Step 1: Create GitHub Personal Access Token

**Create a GitHub Personal Access Token (Classic) to access Epic Games container images:**

1. **Go to GitHub Settings**

   - Navigate to [GitHub.com](https://github.com) and sign in
   - Click your profile picture → **Settings**

2. **Access Developer Settings**

   - Scroll down to **Developer settings** (bottom of left sidebar)
   - Click **Personal access tokens** → **Tokens (classic)**

3. **Generate New Token**

   - Click **Generate new token** → **Generate new token (classic)**
   - Enter a descriptive **Note**: `DDC Container Registry Access`
   - Set **Expiration**: Choose appropriate duration (90 days recommended)

4. **Configure Permissions**

   - **REQUIRED**: Check `read:packages` - _Download packages from GitHub Package Registry_
   - Leave all other permissions unchecked

5. **Generate and Save Token**
   - Click **Generate token**
   - **CRITICAL**: Copy the token immediately - you cannot view it again
   - Store in AWS Secrets Manager (next step)

⚠️ **Prerequisites**: You must be a member of the Epic Games GitHub organization to access their private container registry. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) for organization access.

**Store credentials in AWS Secrets Manager:**

> **🚨 IMPORTANT**
>
> The name of the secret must EXACTLY start with `ecr-pullthroughcache/` or it will not work. Also, you must use a classic access token. The naming after the `ecr-pullthroughcache/` generally doesn't matter, but has some things to be aware of. See [these Amazon ECR docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-secret.html) for more information. Since this value is a personal token that you must create in your own GitHub account, we recommend naming such as `ecr-pullthroughcache/your-github-username/name-of-the-token-in-GitHub`

```bash
aws secretsmanager create-secret \
  --name "ecr-pullthroughcache/<Whatever you want to name this>" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

> **ℹ️ Note**
>
> You may want to target a specific region with --region if deploying to a region different from your AWS CLI default. For multi-region deployments, create the secret in each region where DDC will be deployed. Each region's ECR pull-through cache requires its own copy of the GitHub credentials to authenticate with Epic Games' container registry and create the private ECR repository.
> This private ECR repo is used by Helm to install Unreal DDC on the EKS cluster.

## Examples

For a quickstart, please review the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples). They provide a good reference for not only the ways to declare and customize the module configuration, but how to provision and reference the infrastructure mentioned in the prerequisites. As mentioned earlier, we avoid creating infrastructure that is more general (e.g. VPCs, Subnets, Security Groups, etc.) as this can be highly nuanced . All examples show sample configurations of these resources created external to the module, but please customize based on your own needs.

This module provides two types of examples:

- **[Single Region Basic](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples/single-region-basic)** - Basic DDC deployment for small teams
- **[Multi-Region Basic](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples/multi-region-basic)** - Cross-region DDC with replication for global teams

## Deployment Instructions

### Step 1: Declare and configure the module

Note, this is just a condensed sample. See the examples for the related required infrastructure.

**Single Region Example**

```terraform
module "unreal_cloud_ddc" {
  source = "../../"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  # - Shared -
  region = local.primary_region
  existing_vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_load_balancer_subnets = aws_subnet.public_subnets[*].id
  existing_service_subnets = aws_subnet.private_subnets[*].id
  existing_security_groups = [aws_security_group.allow_my_ip.id]

  # DNS Configuration
  existing_route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  existing_certificate_arn = aws_acm_certificate.ddc.arn

  # - DDC Infra Configuration -
  ddc_infra_config = {
    region = local.primary_region
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    eks_api_access_cidrs   = ["${chomp(data.http.my_ip.response_body)}/32"]
    scylla_subnets = aws_subnet.private_subnets[*].id
  }

  # - DDC Services Configuration -
  ddc_services_config = {
    region = local.primary_region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}
```

### Step 2: Deploy Infrastructure

> **⚠️ IMPORTANT**
>
> This module creates **internet-accessible** services by default. Review security configurations and restrict access to your organization's IP ranges before deployment.

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs for UE configuration
# terraform output ddc_connection
```

## Verification & Testing

### Networking

**1. Basic Health Check**

**[Request]**

```bash
# Test DDC health endpoint
curl <DDC Route53 DNS Endpoint>/health/live
```

**[Response]**

After running this you should get a response that looks as the following:

```bash
HEALTHY%
```

**2. PUT a file in Unreal Cloud DDC**

**[Request]**

```bash
# Test PUT operation (write to cache)
curl -X PUT "<DDC Route53 DNS Endpoint>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa" \
  --data "test" \
  -H "content-type: application/octet-stream" \
  -H "X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E" \
  -H "Authorization: ServiceAccount <Value of the Bearer token from the AWS Secrets Manager secret"
```

**[Response]**

After running this you should get a response that looks as the following:

```bash
HTTP/1.1 200 OK
Server: http
Date: Wed, 29 Jan 2025 19:15:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server-Timing: blob.put.FileSystemStore;dur=0.1451;desc="PUT to store: 'FileSystemStore'",blob.put.AmazonS3Store;dur=267.0449;desc="PUT to store: 'AmazonS3Store'",blob.get-metadata.FileSystemStore;dur=0.0406;desc="Blob GET Metadata from: 'FileSystemStore'",ref.finalize;dur=7.1407;desc="Finalizing the ref",ref.put;dur=25.2064;desc="Inserting ref"

{"needs":[]}}%
```

> ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️NOTE TO KEVON - YOU MAY NEED TO USE HTTP⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️

**3. GET the file you wrote to Unreal Cloud DDC**

**[Request]**

```bash
# Test GET operation (read from cache)
curl "<DDC Route53 DNS Endpoint>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json" \
  -H "Authorization: ServiceAccount <Value of the Bearer token from the AWS Secrets Manager secret"
```

**[Response]**

After running this you should get a response that looks as the following:

```bash
HTTP/1.1 200 OK
Server: http
Date: Wed, 29 Jan 2025 19:16:46 GMT
Content-Type: application/json
Content-Length: 66
Connection: keep-alive
X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E
X-Jupiter-LastAccess: 01/29/2025 19:16:46
Server-Timing: ref.get;dur=0.0299;desc="Fetching Ref from DB"

{"RawHash":"4878ca0425c739fa427f7eda20fe845f6b2e46ba","RawSize":4}%
```

#### ⚠️ Troubleshooting ⚠️

If the above command do not work, try to test access to the Network Load Balancer directly

**Example:**

```bash
# Test DDC health endpoint
curl <Network Load Balancer Endpoint>/health/live

# Expected response: "Healthy"
```

### Application

**1. Verify the Unreal Cloud DDC EKS Cluster Status**

**[Request]**

```bash
# Configure kubectl access
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>

# Check pod status
kubectl get pods -n unreal-cloud-ddc

```

**[Response]**

 <!-- Expected: All pods should be "Running" -->

```bash
TODO
```

### Database

**1. Check the status of the database nodes**

Connect to any of the Scylla Nodes and run the following command (SSM with Session Manager recommended):

**[Request]**

```bash
nodetool status
```

**[Response]**

```bash
TODO
```

**2. Check the keyspaces are present**

On the instance, start cqlsh session:

```bash
cqlsh
```

**[Request]**

Check if all keyspaces are there

```bash
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces:

- jupiter
- jupiter_ddc_local

**2. Check the keyspace configuration**

On the instance, start cqlsh session:

```bash
cqlsh
```

**[Request]**

Check if all keyspaces are there

```bash
describe keyspaces
```

**[Response]**

Should include at least the following keyspaces:

- jupiter
- jupiter_ddc_local

## Client Connection Guide

> **📖 For complete DDC setup and configuration guidance, see the [Epic Games DDC Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/how-to-set-up-a-cloud-type-derived-data-cache-for-unreal-engine).**

### Unreal Engine Configuration

**1. Get connection details:**
You can either see the relevant details in the Terraform outputs after a successful apply, or separately run the following command to get all of the outputs. Ensure you have defined the outputs you would like to use at in the same directory you initialized Terraform in.

**[Request]**

```bash
# Get all outputs
terraform output -json
```

**[Response]**

**2/ Configure project (`Config/DefaultEngine.ini`):**

```ini
[DDC]
; Production configuration
Cloud=(Type=HTTPDerivedDataBackend, Host="<DDS Route53 DNS Endpoint>")

; Optional: Local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)

; Hierarchical setup (try cloud first, then local)
Hierarchical=(Type=Hierarchical, Inner=Cloud, Inner=Local)
```

### Multi-Region Configuration

You can also have a multi-region configuration which has benefits for geographically distributed teams:

For distributed teams:

```ini
[DDC]
; Region 1 (Primary in this case)
Primary=(Type=HTTPDerivedDataBackend, Host="<DDS Route53 DNS Endpoint for Region 1>")

; Region 2
Secondary=(Type=HTTPDerivedDataBackend, Host="https://us-west-2.ddc.yourcompany.com")

; Try primary first, then secondary, then local
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

> **Note:** while the Hierarchical setup mentions `Primary` and `Secondary` you can have more than 2 AWS regions used. This is just setting the priority order for cache usage. This is helpful to set for both latency and DR considerations. For more information on this see [these docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine).

## Troubleshooting

### Common Issues

#### 1. Pod Crashes with Unix Socket Error

**Symptoms**: `CrashLoopBackOff`, logs show `Invalid url: 'unix:///nginx/jupiter-http.sock'`

**Cause**: For the EKS Cluster, we use an existing Network Load Balancer (NLB)which is created during deployment, instead of letting EKS create its own NLBs using the Load Balancer Controller. You can see this in our Helm Chart, where we use `ClusterIP` mode. This is to prevent race conditions with destroy. This is because the following occurs:

Without `ClusterIP` and external NLB:

`terraform apply` ✅:

1. Infra is provisioned using AWS Provider (including EKS and NLB)
2. Helm and Kubernetes Providers are used to configure the EKS Cluster (will create networking resources like NLB, Target Groups)
3. Load Balancer Controller creates load balancers and related infrastructure

`terraform destroy` ❌:

1. AWS Provider is used to destroy infra and potentially the EKS Cluster is deleted before Helm and Kubernetes is able to reset the configuration it applied to the cluster. This configuration if using `LoadBalancer` type created actual AWS infrastructure which would be orphaned in the AWS account and likely cause race conditions due to dependencies

With `ClusterIP` and external NLB:
`terraform apply` ✅:

1. Infra is provisioned using AWS Provider (including EKS and NLB)
2. Helm and Kubernetes Providers are used to configure the EKS Cluster
3. Load Balancer Controller creates load balancers and related infrastructure

`terraform destroy` ✅:

1. Helm and Kubernetes Providers are used to reset EKS configuration. There are no NLB to destroy since none were created, just associated with the exting NLB and Target Groups.
1. AWS Provider is used to destroy AWS infra and potentially the EKS Cluster is deleted before Helm and Kubernetes is able to reset the configuration it applied to the cluster. This configuration if using `LoadBalancer` type created actual AWS infrastructure which would be orphaned in the AWS account and likely cause race conditions due to dependencies

However, Unreal Cloud DDC expects NGINX and will use that networking configuration along with the default created load balancers (by load balancer controller). So to solve for this, we had to modify the configuration to use standard HTTP instead of NGINX

**Solution**: Verify NGINX is disabled in Helm values:

```bash
helm get values cgd-unreal-cloud-ddc-initialize -n unreal-cloud-ddc | grep -A5 nginx
# Should show: enabled: false
```

#### 2. DDC API Connection Timeout

**Symptoms**: `curl` commands timeout or return connection refused

**Solutions**:

1. Check security group allows your IP: `curl https://checkip.amazonaws.com/`
2. Verify DNS resolution: `nslookup us-east-1.ddc.yourcompany.com`
3. Check EKS cluster status: `kubectl get nodes`

#### GitHub Container Registry Access Denied

**Symptoms**: Pod image pull failures, `ImagePullBackOff` status

**Solutions**:

1. Verify Epic Games organization membership
2. Check GitHub PAT has `packages:read` permission
3. Confirm secret is stored correctly in AWS Secrets Manager

### Debug Commands

```bash
# Check current IP
curl https://checkip.amazonaws.com/

# Test DNS resolution
nslookup us-east-1.ddc.yourcompany.com

# Configure kubectl (REQUIRED before any kubectl commands)
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check pod logs
kubectl logs -f <pod-name> -n unreal-cloud-ddc

# Check service status
kubectl get svc -n unreal-cloud-ddc
```

## User Personas

### DevOps Team (Infrastructure Provisioners)

**Responsibilities:**

- Deploy and manage DDC infrastructure
- Configure networking and security
- Handle certificates and DNS
- Monitor infrastructure health

**Access Requirements:**

- EKS API access for kubectl/Terraform
- Full access to all AWS services
- Office/VPN network access

### Game Developers (Service Consumers)

**Responsibilities:**

- Use DDC for faster asset iteration
- Configure Unreal Engine DDC settings
- Report performance issues

**Access Requirements:**

- DDC service access only (not backend infrastructure)
- Unreal Engine Editor access

## Deployment Patterns

### Single Region Deployment

**When to Use:**

- Small teams (5-20 developers)
- Co-located teams (same geographic region)
- Prototyping/MVP projects
- Budget-conscious deployments

**Benefits:**

- Lower cost (single region)
- Simpler management
- Faster deployment

### Multi-Region Deployment

**When to Use:**

- Distributed teams (US + Europe + Asia)
- Large studios (50+ developers)
- Performance-critical workflows
- Disaster recovery requirements

**Benefits:**

- Reduced latency for global teams
- Built-in disaster recovery
- Regional data compliance

## Security & Access Patterns

For detailed configuration options and deployment patterns, see the [examples](examples/) directory:

- **Single Region**: Basic deployment for small to medium teams
- **Multi-Region**: Cross-region deployment for global teams

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                        | Version            |
| --------------------------------------------------------------------------- | ------------------ |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform)    | >= 1.11            |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                      | >= 6.0.0           |
| <a name="requirement_helm"></a> [helm](#requirement_helm)                   | >= 2.16.0, < 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement_kubernetes) | >= 2.33.0          |

## Providers

| Name                                             | Version  |
| ------------------------------------------------ | -------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | >= 6.0.0 |

## Modules

| Name                                                                    | Source                 | Version |
| ----------------------------------------------------------------------- | ---------------------- | ------- |
| <a name="module_ddc_infra"></a> [ddc_infra](#module_ddc_infra)          | ./modules/ddc-infra    | n/a     |
| <a name="module_ddc_services"></a> [ddc_services](#module_ddc_services) | ./modules/ddc-services | n/a     |

## Resources

| Name                                                                                                                                                  | Type     |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_lb.shared_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)                                                   | resource |
| [aws_lb_target_group.shared_nlb_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                      | resource |
| [aws_route53_record.ddc_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                          | resource |
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)                                  | resource |
| [aws_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_security_group.external_nlb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                      | resource |
| [aws_security_group.internal_nlb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                      | resource |

## Inputs

| Name                                                                                                                           | Description                                                                                                                                                  | Type                                                                                                                                                                                                                                  | Default      | Required |
| ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | :------: |
| <a name="input_access_method"></a> [access_method](#input_access_method)                                                       | Access method for the DDC service. 'external'/'public' creates public NLB for internet access. 'internal'/'private' creates private NLB for VPC-only access. | `string`                                                                                                                                                                                                                              | `"external"` |    no    |
| <a name="input_allowed_external_cidrs"></a> [allowed_external_cidrs](#input_allowed_external_cidrs)                            | List of CIDR blocks allowed to access DDC service externally. Cannot include 0.0.0.0/0 for security.                                                         | `list(string)`                                                                                                                                                                                                                        | `[]`         |    no    |
| <a name="input_ddc_infra_config"></a> [ddc_infra_config](#input_ddc_infra_config)                                              | Configuration for DDC infrastructure deployment                                                                                                              | <pre>object({<br> region = string<br> scylla_replication_factor = number<br> kubernetes_version = optional(string, "1.31")<br> create_seed_node = optional(bool, true)<br> existing_scylla_seed = optional(string, null)<br> })</pre> | `null`       |    no    |
| <a name="input_ddc_services_config"></a> [ddc_services_config](#input_ddc_services_config)                                     | Configuration for DDC services deployment                                                                                                                    | <pre>object({<br> unreal_cloud_ddc_version = string<br> ghcr_credentials_secret_manager_arn = string<br> namespace = optional(string, "unreal-cloud-ddc")<br> })</pre>                                                                | `null`       |    no    |
| <a name="input_private_subnets"></a> [private_subnets](#input_private_subnets)                                                 | List of private subnet IDs for EKS nodes and ScyllaDB instances                                                                                              | `list(string)`                                                                                                                                                                                                                        | `[]`         |    no    |
| <a name="input_public_subnets"></a> [public_subnets](#input_public_subnets)                                                    | List of public subnet IDs for load balancers                                                                                                                 | `list(string)`                                                                                                                                                                                                                        | `[]`         |    no    |
| <a name="input_region"></a> [region](#input_region)                                                                            | AWS region for deployment                                                                                                                                    | `string`                                                                                                                                                                                                                              | n/a          |   yes    |
| <a name="input_route53_public_hosted_zone_name"></a> [route53_public_hosted_zone_name](#input_route53_public_hosted_zone_name) | Route53 public hosted zone name for DNS records                                                                                                              | `string`                                                                                                                                                                                                                              | `null`       |    no    |
| <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)                                                                            | VPC ID where DDC infrastructure will be deployed                                                                                                             | `string`                                                                                                                                                                                                                              | n/a          |   yes    |

## Outputs

| Name                                                                          | Description                                |
| ----------------------------------------------------------------------------- | ------------------------------------------ |
| <a name="output_ddc_connection"></a> [ddc_connection](#output_ddc_connection) | DDC connection information for this region |
| <a name="output_ddc_infra"></a> [ddc_infra](#output_ddc_infra)                | DDC infrastructure outputs                 |
| <a name="output_ddc_services"></a> [ddc_services](#output_ddc_services)       | DDC services outputs                       |
| <a name="output_dns_endpoints"></a> [dns_endpoints](#output_dns_endpoints)    | DNS endpoints for DDC services             |

<!-- END_TF_DOCS -->

## Contributing

See the [Contributing Guidelines](../../../CONTRIBUTING.md) for information on how to contribute to this project.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../../../LICENSE) file for details.
