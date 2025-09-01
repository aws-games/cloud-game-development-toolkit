# Unreal Cloud DDC Terraform Module

This module deploys **[Unreal Cloud DDC](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)** infrastructure on AWS, providing a complete derived data cache solution for Unreal Engine projects.

> **⚠️ Can't access the Unreal Cloud DDC link?** You need Epic Games GitHub organization access. Follow the [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine) to join the organization and get access to DDC resources. **Note: This is critical to use DDC. You must do this or the deployment will not work.**

## 🔧 Version Requirements

**⚠️ Important Version Dependencies:**

- **Terraform 1.11+** - Required for ephemeral values and write-only attributes used in secure secret management
- **AWS Provider 6.0+** - Required for the `region` parameter on resources, enabling simplified multi-region deployments without provider aliases

These versions enable enhanced security (ephemeral secrets) and simplified multi-region configuration patterns used throughout this module.

## ✨ Features

- **Single module call** deploys complete DDC infrastructure (EKS, ScyllaDB, S3, Load Balancers)
- **Multi-region support** with cross-region replication (maximum 2 regions)
- **Unified provider management** - handles both single and multi-region deployments
- **Automatic dependency management** between infrastructure and applications
- **Built-in monitoring** with ScyllaDB monitoring stack (Prometheus, Grafana, Alertmanager)
- **Security by default** with VPC isolation, IAM roles, and encrypted storage

## 🏢 Architecture

### Single Region

![unreal-cloud-ddc-single-region](./assets/media/diagrams/unreal-cloud-ddc-single-region.png)

- **EKS Cluster**: Kubernetes cluster with specialized node groups (system, worker, NVME)
- **ScyllaDB**: High-performance database cluster for DDC metadata
- **S3 Bucket**: Object storage for cached game assets
- **Load Balancers**: Network Load Balancer for DDC API, Application Load Balancer for monitoring
- **Monitoring Stack**: Prometheus, Grafana, and Alertmanager for observability

### Multi-Region

<!-- TODO: ADD MULTI-REGION ARCH DIAGRAM -->

- **Primary Region**: Complete DDC infrastructure with EKS, ScyllaDB, and S3
- **Secondary Region**: Replicated infrastructure for high availability
- **VPC Peering**: Secure cross-region connectivity
- **Cross-Region Replication**: Automatic data synchronization
- **DNS**: Region-specific endpoints for optimal routing

## 🧩 Submodules

### DDC Infrastructure

**DDC Infrastructure** creates the core AWS resources: EKS cluster with specialized node groups, ScyllaDB database cluster on dedicated EC2 instances, S3 storage buckets, and load balancers for external access.

📚 For more info, see the [DDC Infrastructure module docs](./modules/ddc-infra/README.md)

### DDC Services

**DDC Services** deploys the Unreal Cloud DDC applications to the EKS cluster using Helm charts, manages container orchestration, and configures service networking.

📚 For more info, see the [DDC Services module docs](./modules/ddc-services/README.md)

### DDC Monitoring

**DDC Monitoring** provides observability with Prometheus metrics collection, Grafana dashboards for visualization, and Alertmanager for handling alerts across the DDC infrastructure.

📚 For more info, see the [DDC Monitoring module docs](./modules/ddc-monitoring/README.md)

## 🎒 Prerequisites

### Required Tools & Access

- **Epic Games Organization Access**: Must be member of Epic Games GitHub organization to access DDC container images
- **GitHub Personal Access Token**: Stored in AWS Secrets Manager (prefixed with `ecr-pullthroughcache/`) with structure `{"username":"<your-github-username>","accessToken":"<your-pat>"}` and `packages:read` permission. See [AWS ECR pull-through cache documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-secret.html) for details.
- **AWS CLI**: Configured with appropriate permissions for deployment and testing
- **kubectl**: For EKS cluster access and post-deployment verification
- **Helm**: For application deployment and cleanup operations
- **Route53 Hosted Zone**: For DNS records and SSL certificate validation (recommended)
- **VPC Infrastructure**: Existing VPC with public and private subnets

📚 **For answers to common questions and detailed explanations**, see the [FAQ section](#frequently-asked-questions-faq).

**Important**: The module currently supports a maximum of 2 regions (primary and secondary).

### Multi-Region Requirements

**⚠️ Critical: Region Family Restrictions**

For multi-region deployments, you **must use different region families** to avoid ScyllaDB datacenter name collisions:

✅ **Supported combinations:**
- `us-east-1` + `us-west-2` (East Coast + West Coast)
- `us-east-1` + `eu-west-1` (US + Europe) 
- `us-west-2` + `ap-southeast-1` (US + Asia)

❌ **Blocked combinations:**
- `us-east-1` + `us-east-2` (same region family)
- `us-west-1` + `us-west-2` (same region family)
- `eu-west-1` + `eu-west-2` (same region family)

**Why this restriction exists:** ScyllaDB's EC2Snitch automatically converts region names (`us-east-1` → `us-east`, `us-east-2` → `us-east`), causing datacenter name collisions that break multi-region clusters.

**For detailed multi-region setup and examples, see the [Multi-Region Example](./examples/multi-region/README.md).**

## 📚 Examples

For example configurations, please see the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples){:target="\_blank"}.

## 🚀 Deployment Instructions

Make sure you've completed the [Prerequisites](#prerequisites) section first, then follow these steps to deploy DDC infrastructure.

⚠️ **CRITICAL**: Your IP address must be consistently allowed in `eks_api_access_cidrs` for both deployment and destruction. This module uses Helm to deploy applications, requiring EKS API access during `terraform destroy` to prevent orphaned AWS resources. See [Troubleshooting](#destroy-troubleshooting) if destroy operations fail.

### Step 1: Configure GitHub Credentials

Create GitHub Personal Access Token with Epic Games organization access and store in AWS Secrets Manager:

```bash
# Store GitHub credentials as JSON (required format for ECR pull-through cache)
aws secretsmanager create-secret \
  --name "ecr-pullthroughcache/cgd-unreal-cloud-ddc-github-credentials" \
  --description "GitHub PAT for DDC container images" \
  --secret-string '{"username":"your-github-username","accessToken":"your-personal-access-token"}'
```

See [AWS ECR pull-through cache documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-secret.html) for more details on secret structure.

### Step 2: Configure Terraform

Set up your Terraform configuration with the required providers and module call. See the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/examples) for complete working configurations including provider setup, VPC configuration, and all required variables.

### Step 3: Deploy Infrastructure

Ensure AWS credentials are configured and verify access:

**Verify AWS credentials:**

```bash
# Check that AWS credentials are configured and valid
aws sts get-caller-identity
```

**Initialize Terraform:**

```bash
terraform init
```

**Plan deployment:**

```bash
terraform plan
```

**Deploy infrastructure:**

```bash
terraform apply
```

## ✅ Verifying and Testing DDC Deployment

Run these tests to ensure DDC is working before configuring Unreal Engine projects.

After deploying DDC infrastructure, verify the deployment is working correctly before developers configure Unreal Engine.

### Connection Information

**After deployment completes, terraform displays key connection values:**

```bash
# These outputs are automatically shown after 'terraform apply'
# You can also view them anytime with:
terraform output
```

**Key outputs for Unreal Engine configuration:**

- **`s3_bucket_name`** - S3 bucket for cached assets
- **`region`** - AWS region where DDC is deployed
- **`ddc_endpoint_url`** - Main DDC API endpoint (Route53 DNS)
- **`nlb_dns_name`** - Backup endpoint (direct load balancer)

**Additional outputs (for testing/troubleshooting):**

- **`eks_cluster_name`** - For kubectl access
- **`monitoring_url`** - Grafana dashboard access
- **`bearer_token_secret_arn`** - DDC authentication token location

**⚠️ IMPORTANT - Multi-Region:** For multi-region deployments, each region produces its own set of outputs with region-specific URLs (e.g., `us-east-1.ddc.yourdomain.com`, `us-west-2.ddc.yourdomain.com`). Users should connect to their geographically closest region for optimal performance.

### Basic Verification

Verifies that Kubernetes pods are deployed and running correctly:

**Configure kubectl access:**

```bash
# Terraform outputs provide these values if following examples
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

**Check DDC pods are running:**

```bash
# Use terraform output for actual namespace
kubectl get pods -n $(terraform output -raw namespace)
```

**Verify all pods are in Running state:**

```bash
kubectl get pods -n $(terraform output -raw namespace) --field-selector=status.phase=Running
```

### Automated Testing Scripts

Runs comprehensive functional tests to verify DDC API connectivity and version compatibility. These scripts are located in the `assets/scripts/` directory of the DDC module:

**Test DDC functionality:**

```bash
# Requires authentication - tests end-to-end DDC operations
./assets/scripts/ddc_functional_test.sh
```

**Check deployed versions:**

```bash
# Verifies DDC and Kubernetes component versions
./assets/scripts/ddc_version_check.sh
```

### Manual Connectivity Test

For quick verification without running scripts:

**Simple connectivity test (recommended first):**

```bash
# Tests basic authentication and endpoint availability
curl http://ddc.yourdomain.com/api/v1/health -H 'Authorization: ServiceAccount your-bearer-token-from-aws-secrets-manager'
```

**If Route53 DNS fails, try direct ELB endpoint:**

```bash
curl http://cgd-unreal-cloud-ddc-123456789.elb.us-east-1.amazonaws.com/api/v1/health -H 'Authorization: ServiceAccount your-bearer-token-from-aws-secrets-manager'
```

**Full functionality test:**

```bash
# Tests write capability and writes small dummy data to cache
curl http://ddc.yourdomain.com/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H 'Authorization: ServiceAccount your-bearer-token-from-aws-secrets-manager'
```

**Replace with your values:**

- `ddc.yourdomain.com` → Your actual DDC endpoint URL
- `your-bearer-token-from-aws-secrets-manager` → Token from AWS Secrets Manager

### What to Expect

**Successful Response:**

```
HTTP/1.1 200 OK
Content-Type: application/json
...
```

**Common Issues:**

- **Connection timeout**: Check security groups allow your IP
- **401 Unauthorized**: Verify bearer token is correct
- **DNS resolution failed**: Check Route53 records

## 🔌 Connecting Unreal Engine to DDC

### Overview

Unlike version control systems (Perforce, Git) that have GUI clients, **DDC works transparently in the background**. There's no "DDC client" to install - Unreal Engine connects directly to your deployed DDC service to cache derived data (compiled shaders, textures, etc.).

### Prerequisites for Connection

#### 1. Unreal Engine Installation

- **Epic Games Launcher**: Download from [Epic Games](https://www.epicgames.com/store/download)
- **Unreal Engine**: Install version compatible with your DDC version (see [Version Compatibility](#version-compatibility))
- **Project Setup**: Have an existing Unreal Engine project or create a new one

#### 2. Network Access

- **Your IP must be allowed** in the security groups configured during DDC deployment
- **Corporate networks**: May need firewall rules for DDC endpoints
- **VPN access**: If DDC is deployed in private subnets

### Configuration Steps

#### Step 1: Get DDC Connection Information

Your DevOps team deployed the DDC infrastructure and has the connection details you need. Ask them for the following information:

**Required information from DevOps:**

- **S3 Bucket Name** - Where cached assets are stored (e.g., `cgd-unreal-cloud-ddc-bucket-abc123`)
- **AWS Region** - Where DDC is deployed (e.g., `us-east-1`)
- **DDC Endpoint URL** - Main DDC API endpoint (e.g., `http://ddc.yourdomain.com`)
- **Backup Endpoint** - Direct load balancer DNS (fallback if Route53 fails)

**For DevOps:** These values are available via `terraform output` command.

#### Step 2: Configure Unreal Engine Project

**Option A: Project-Specific Configuration (Recommended)**

Edit your project's `Config/DefaultEngine.ini` file:

```bash
# Get connection information from terraform
terraform output ddc_connection
```

```ini
[DDC]
; Use your deployed DDC service
DefaultBackend=Shared

; Configure the shared DDC backend
Shared=(Type=S3, Remote=true, Bucket=your-s3-bucket-name, Region=your-aws-region, BaseUrl=http://your-ddc-dns-name)

; Example with actual values:
; Shared=(Type=S3, Remote=true, Bucket=cgd-unreal-cloud-ddc-bucket-abc123, Region=us-east-1, BaseUrl=http://ddc.yourdomain.com)

; Optional: Configure local cache as fallback
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache, MaxFileAge=60)
```

**Option B: Engine-Wide Configuration**

Edit the engine's `Engine/Config/BaseEngine.ini` (affects all projects):

```ini
[DDC]
DefaultBackend=Hierarchical

; Hierarchical setup: try shared first, then local
Hierarchical=(Type=Hierarchical, Inner=Shared, Inner=Local)
Shared=(Type=S3, Remote=true, Bucket=your-s3-bucket-name, Region=your-aws-region, BaseUrl=http://ddc.yourdomain.com)
Local=(Type=FileSystem, Path=%GAMEDIR%DerivedDataCache)
```

#### Step 3: Test DDC Connection

1. **Open Unreal Engine** with your configured project
2. **Open Output Log**: Window → Developer Tools → Output Log
3. **Filter for DDC**: In the log filter, type "DDC" to see DDC-related messages
4. **Compile a shader or asset**: Make a change that triggers asset compilation
5. **Check for DDC activity**: Look for messages like:
   ```
   LogDerivedDataCache: Shared DDC: Put succeeded for key...
   LogDerivedDataCache: Shared DDC: Get succeeded for key...
   ```

### Verification Steps

#### 1. Check DDC Status in Editor

- **Editor Preferences** → **General** → **Loading & Saving** → **Derived Data Cache**
- Verify your shared DDC backend is listed and active

#### 2. Monitor DDC Usage

```bash
# Check S3 bucket for cached objects
aws s3 ls s3://your-ddc-bucket-name --recursive

# Run functional test to verify API connectivity
./assets/scripts/ddc_functional_test.sh
```

#### 3. Performance Validation

- **First build**: Will be slower as DDC populates
- **Subsequent builds**: Should be significantly faster
- **Team sharing**: Other developers should see faster builds when using same assets

### Troubleshooting Connection Issues

#### "DDC Backend Not Available"

**Symptoms**: Unreal Engine logs show DDC connection failures

**Solutions**:

1. **Test connectivity with different endpoints**:

   ```bash
   # Test Route53 DNS name first (simple health check)
   curl http://ddc.yourdomain.com/api/v1/health -H "Authorization: ServiceAccount your-bearer-token"

   # If health check works, test full functionality
   curl http://ddc.yourdomain.com/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H "Authorization: ServiceAccount your-bearer-token"

   # If Route53 fails, try direct NLB connection
   terraform output nlb_dns_name  # Get NLB DNS name
   curl http://cgd-unreal-cloud-ddc-123456789.elb.us-east-1.amazonaws.com/api/v1/health -H "Authorization: ServiceAccount your-bearer-token"
   curl http://cgd-unreal-cloud-ddc-123456789.elb.us-east-1.amazonaws.com/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H "Authorization: ServiceAccount your-bearer-token"

   # For multi-region, test specific region
   curl http://us-east-1.ddc.yourdomain.com/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H "Authorization: ServiceAccount your-bearer-token"
   ```

2. **Check network access**: Verify your IP is in DDC security groups
3. **Verify DNS resolution**:
   ```bash
   nslookup ddc.yourdomain.com
   # Should resolve to NLB IP addresses
   ```
4. **Verify AWS credentials**: Run `aws sts get-caller-identity`
5. **Check configuration**: Ensure BaseUrl, Bucket, and Region are correct

**Connection Troubleshooting Flow**:

1. **Route53 DNS fails** → Check DNS records and Route53 configuration
2. **Direct NLB works** → DNS issue, fix Route53 records
3. **Both fail** → Network/security group issue
4. **401 errors** → Authentication issue (bearer token or AWS credentials)

#### "Access Denied" Errors

**Symptoms**: AWS authentication failures in UE logs

**Solutions**:

1. **Check IAM permissions**: Ensure AWS credentials have S3 and DDC access
2. **Verify bearer token**: Check AWS Secrets Manager for valid token
3. **Test AWS CLI**: Run `aws s3 ls s3://your-ddc-bucket`

#### "Slow Build Performance"

**Symptoms**: Builds not faster despite DDC configuration

**Solutions**:

1. **Check DDC hit rate**: Monitor Grafana dashboard (if enabled)
2. **Verify cache population**: Check S3 bucket for cached objects
3. **Network latency**: Consider regional deployment closer to developers

### Team Deployment Best Practices

#### 1. Shared Configuration

- **Version control DDC config**: Include `DefaultEngine.ini` changes in your project repository
- **Document setup**: Create team wiki with connection instructions
- **Standardize credentials**: Use shared AWS account or IAM roles

#### 2. Gradual Rollout

- **Start with build machines**: Configure CI/CD systems first
- **Pilot group**: Test with small group of developers
- **Full team**: Roll out after validation

#### 3. Monitoring & Maintenance

- **Monitor usage**: Use Grafana dashboard to track DDC performance
- **Cache cleanup**: Implement S3 lifecycle policies for old cache data
- **Version updates**: Follow [DDC Version Management](#ddc-version-management--updates) process

## 🔧 Troubleshooting

Common problems and solutions for deployment issues and connection issues.

### Creation Issues

#### EKS Cluster Creation Fails

**Symptoms**: `Error creating EKS Cluster` or timeout during cluster creation

**Common Causes & Solutions:**

- **Insufficient IAM permissions**: Ensure your AWS credentials have EKS cluster creation permissions
- **VPC/Subnet issues**: Verify subnets exist and have proper tags for EKS
- **IP range conflicts**: Check `eks_api_access_cidrs` doesn't conflict with VPC CIDR
- **Resource limits**: Check AWS service quotas for EKS clusters in your region

```bash
# Verify EKS permissions
aws iam simulate-principal-policy --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) --action-names eks:CreateCluster

# Check VPC subnets
aws ec2 describe-subnets --subnet-ids subnet-xxx --query 'Subnets[*].{SubnetId:SubnetId,VpcId:VpcId,AvailabilityZone:AvailabilityZone}'
```

#### ScyllaDB Instance Launch Fails

**Symptoms**: `Error launching EC2 instance` for ScyllaDB nodes

**Common Causes & Solutions:**

- **Instance type unavailable**: Try different instance type or availability zone
- **AMI not found**: Verify ScyllaDB AMI exists in your region
- **Security group issues**: Check VPC security group rules
- **Subnet capacity**: Ensure private subnets have available IP addresses

```bash
# Check instance type availability
aws ec2 describe-instance-type-offerings --location-type availability-zone --filters Name=instance-type,Values=i4i.xlarge

# Verify subnet capacity
aws ec2 describe-subnets --subnet-ids subnet-xxx --query 'Subnets[*].{SubnetId:SubnetId,AvailableIpAddressCount:AvailableIpAddressCount}'
```

### Deletion Issues {#destroy-troubleshooting}

#### Understanding IP Access Requirements

**Why This Matters**: Unlike typical Terraform modules that only manage AWS resources, this module also deploys Kubernetes applications via Helm. During `terraform destroy`, Helm must clean up applications before EKS infrastructure is deleted to prevent orphaned AWS resources.

**Common Failure Scenario:**

```bash
# Deploy from office
terraform apply  # IP: 203.0.113.5 (allowed in eks_api_access_cidrs)

# Destroy from home
terraform destroy  # IP: 198.51.100.10 (NOT in allowlist)
# Result: Helm cleanup fails → EKS destroyed → Orphaned AWS resources
```

#### Automatic vs Manual Cleanup

The module provides automatic Helm cleanup during destroy operations:

```hcl
# Default: Automatic cleanup enabled
ddc_services_config = {
  auto_cleanup = true   # Recommended for most users
}

# Advanced: Manual cleanup (experts only)
ddc_services_config = {
  auto_cleanup = false  # You handle cleanup manually
}
```

**When `auto_cleanup = true` (Default):**

- ✅ Prevents orphaned ENIs and Load Balancers
- ⚠️ Requires your IP in `eks_api_access_cidrs` during destroy
- ⚠️ Needs `helm` and `kubectl` installed locally

**When `auto_cleanup = false`:**

- ✅ No IP dependency during destroy
- 🚨 Manual cleanup mandatory before destroying EKS cluster

#### Destroy Fails with "EKS API Access Denied"

**Symptoms**: `terraform destroy` fails during Helm cleanup phase

**Root Cause**: Your IP address changed since deployment and is no longer in `eks_api_access_cidrs`

**Solutions:**

1. **Update IP and re-apply**:

   ```bash
   # Check current IP
   curl https://checkip.amazonaws.com/

   # Update eks_api_access_cidrs in your terraform.tfvars
   # Then apply changes
   terraform apply

   # Now destroy will work
   terraform destroy
   ```

2. **Manual cleanup** (if above fails):

   ```bash
   # From a machine with EKS access
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   helm list -A
   helm uninstall <release-name> -n <namespace> --wait

   # Then retry destroy
   terraform destroy
   ```

**Prevention Strategies:**

1. **Static IP**: Always deploy/destroy from same location
2. **Broader CIDR**: Use wider IP ranges (e.g., office + VPN ranges)
3. **Manual cleanup**: Set `auto_cleanup = false` and handle cleanup manually

#### Helm Cleanup Timeout {#helm-cleanup-failures}

**Symptoms**: Helm uninstall hangs or times out during destroy

**Common Causes & Solutions:**

- **Stuck finalizers**: Kubernetes resources with finalizers preventing deletion
- **Network issues**: Pods can't communicate with Kubernetes API
- **Resource dependencies**: External resources preventing pod termination

```bash
# Check for stuck resources
kubectl get all -n unreal-cloud-ddc
kubectl get pvc -n unreal-cloud-ddc

# Force delete stuck pods
kubectl delete pod <pod-name> -n unreal-cloud-ddc --force --grace-period=0

# Remove finalizers from stuck resources
kubectl patch <resource-type> <resource-name> -n unreal-cloud-ddc -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Connection Issues

#### Cannot Access DDC API

**Symptoms**: `Connection timeout` or `Connection refused` when accessing DDC URL

**Common Causes & Solutions:**

- **Security group restrictions**: Your IP not in security group allowlist
- **Load balancer not ready**: NLB still provisioning or unhealthy targets
- **DNS resolution issues**: Route53 records not propagated

```bash
# Check your current IP
curl https://checkip.amazonaws.com/

# Test DNS resolution
nslookup ddc.yourdomain.com

# Check load balancer health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

#### EKS API Access Denied

**Symptoms**: `kubectl` commands fail with `Unauthorized` or `Forbidden`

**Common Causes & Solutions:**

- **IP not in allowlist**: Current IP not in `eks_api_access_cidrs`
- **AWS credentials**: Invalid or expired AWS credentials
- **Kubeconfig outdated**: Need to refresh EKS kubeconfig

```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Test AWS credentials
aws sts get-caller-identity

# Check current IP vs allowlist
echo "Current IP: $(curl -s https://checkip.amazonaws.com/)"
echo "Check if this IP is in your eks_api_access_cidrs variable"
```

<!-- BEGIN_TF_DOCS -->
<!-- This section will be auto-generated by terraform-docs -->
<!-- END_TF_DOCS -->

## ❓ Frequently Asked Questions (FAQ)

### Prerequisites & Setup

#### Q: Why do I need Epic Games organization access?

**A:** Epic Games hosts DDC container images on GitHub Container Registry with controlled access. You must be a member of the Epic Games GitHub organization to access these private container images. See the [Prerequisites section](#prerequisites) for setup requirements.

📚 **Setup Guide**: [Epic Games Container Images Quick Start](https://dev.epicgames.com/documentation/en-us/unreal-engine/quick-start-guide-for-using-container-images-in-unreal-engine)

#### Q: How should game studios manage GitHub access?

**A:** Use a dedicated service account instead of individual developer accounts:

1. **Create Service Account**: New GitHub user with company email
2. **Join Epic Games Org**: Follow Epic's setup guide
3. **Generate Single PAT**: Create token with `packages:read` permission
4. **Store in Secrets Manager**: DevOps team manages centrally

**Benefits**: No individual dependencies, centralized control, reduced security risk.

#### Q: What's the correct secret format for GitHub credentials?

**A:** The secret must be JSON format as shown in [Deployment Instructions](#deployment-instructions):

```json
{
  "username": "your-github-username",
  "accessToken": "your-personal-access-token"
}
```

See [AWS ECR pull-through cache documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-secret.html) for details.

### Architecture & Components

#### Q: What are the main components of this module?

**A:** The module consists of three submodules as described in the [Submodules section](#submodules):

- **DDC Infrastructure**: EKS, ScyllaDB, S3, Load Balancers
- **DDC Services**: Helm charts and Kubernetes applications
- **DDC Monitoring**: Prometheus, Grafana, Alertmanager

#### Q: What is ScyllaDB and why not Amazon Keyspaces?

**A:** ScyllaDB provides ultra-high performance (sub-millisecond latency) for DDC metadata storage, while Amazon Keyspaces offers single-digit millisecond latency. DDC requires extremely low latency for optimal game asset caching performance.

#### Q: How does ECR pull-through cache work?

**A:** The module automatically caches Epic Games' container images in your AWS account:

1. First pull downloads from GitHub Container Registry
2. ECR caches the image locally
3. Future pulls use the local cache (faster, more reliable)

See [Deployment Instructions](#deployment-instructions) for GitHub credentials setup.

### Configuration & Deployment

#### Q: Can I customize the Helm chart configuration?

**A:** Yes, several ways:

1. **Built-in variables**: Use module variables like `replication_factor`
2. **Custom values**: Use `unreal_cloud_ddc_helm_values` for additional YAML files
3. **Template modification**: Copy and modify YAML files in `assets/submodules/ddc-services/`

#### Q: What is the DDC bearer token?

**A:** A regional service credential automatically created during deployment:

- **Shared by all users**: Unreal Engine clients, build systems, CI/CD
- **Per-region**: Each region has its own independent token
- **Stored in Secrets Manager**: Named `${project_prefix}-${name}-bearer-token`
- **Team-wide access**: Represents DDC service access for the entire studio

#### Q: How do I update DDC versions?

**A:** DDC versions are explicitly pinned and never auto-update:

1. Change `unreal_cloud_ddc_version` in your configuration
2. Run `terraform apply`
3. Verify update with testing scripts

See [DDC Version Management](#ddc-version-management--updates) for detailed process.

### Multi-Region & Networking

#### Q: How does multi-region replication work?

**A:** Each region deploys DDC independently with ScyllaDB cross-region replication:

- **Regional independence**: Users connect to their regional endpoint
- **Internal replication**: Only DDC services communicate across regions
- **Version consistency**: Secondary regions inherit versions from primary

See [Architecture section](#architecture) for deployment patterns.

#### Q: How do I set up multi-region GitHub credentials?

**A:** Each region requires its own GitHub credentials secret:

```hcl
# Primary region
ddc_services_config = {
  ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-east-1:123:secret:ecr-pullthroughcache/github-creds"
}

# Secondary region
ddc_services_config = {
  ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:us-west-2:123:secret:ecr-pullthroughcache/github-creds"
}
```

### Troubleshooting

#### Q: Why does terraform destroy fail with "EKS API Access Denied"?

**A:** Your IP address changed since deployment and is no longer in `eks_api_access_cidrs`. See [Troubleshooting section](#destroy-troubleshooting) for solutions:

1. Update IP and re-apply
2. Use manual cleanup if needed
3. Consider broader CIDR ranges

#### Q: How do I avoid IP restrictions during destroy?

**A:** Set `auto_cleanup = false` and manually clean up Helm releases before destroying infrastructure. See [Troubleshooting section](#destroy-troubleshooting) for manual cleanup process.

#### Q: Can I use this with existing EKS clusters?

**A:** Not currently - the module creates its own EKS cluster. This may be supported in future versions.

### Getting Help

#### Q: Where can I get additional support?

**A:**

1. **Troubleshooting**: See [Troubleshooting section](#troubleshooting) for common issues
2. **AWS Service Health**: [AWS Status Page](https://status.aws.amazon.com/)
3. **Service Limits**: [AWS Service Quotas Console](https://console.aws.amazon.com/servicequotas/)
4. **Community Support**: [GitHub Discussions](https://github.com/aws-games/cloud-game-development-toolkit/discussions/)
5. **Debug Logging**: Set `TF_LOG=DEBUG` for detailed Terraform logs

## 🔧 Implementation Details

Important technical considerations for module architecture and security patterns.

### Provider Configuration Requirements

**Understanding the Module Architecture:**

This module uses a **parent-child module structure** where the main DDC module orchestrates three submodules:
- `ddc-infra` - Creates EKS cluster and AWS infrastructure
- `ddc-services` - Deploys Kubernetes applications via Helm
- `ddc-monitoring` - Sets up monitoring stack

**Module Hierarchy Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Root Level (Your Project)                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Provider  │  │ Kubernetes      │  │  Helm Provider  │ │
│  │   (automatic)   │  │   Provider      │  │  (must pass)    │ │
│  │                 │  │  (must pass)    │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                │                │               │
│                                ▼                ▼               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Main DDC Module                                │ │
│  │                                                             │ │
│  │  • NLB (DDC API)           • ALB (Monitoring)              │ │
│  │  • Route53 DNS             • Security Groups               │ │
│  │  • DDC Bearer Token        • Load Balancer Config          │ │
│  │                                                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │ │
│  │  │ ddc-infra   │  │ddc-services │  │   ddc-monitoring    │  │ │
│  │  │             │  │             │  │                     │  │ │
│  │  │ • EKS       │  │ • Helm      │  │ • Prometheus        │  │ │
│  │  │ • ScyllaDB  │  │ • K8s Apps  │  │ • Grafana           │  │ │
│  │  │ • S3        │  │             │  │                     │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘  │ │
│  │                         ▲                                   │ │
│  │                         │                                   │ │
│  │                  Needs K8s + Helm                          │ │
│  │                    Providers                                │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Why Only Kubernetes and Helm Providers Need Passing:**

| Provider | Auto-Inherited? | Why? |
|----------|----------------|------|
| **AWS** | ✅ Yes | Uses region/credentials from environment automatically |
| **Kubernetes** | ❌ No | Needs EKS cluster connection details (host, auth, certs) |
| **Helm** | ❌ No | Needs Kubernetes connection to deploy charts |

**The Core Problem:**

Unlike simple modules that only use AWS resources, this module requires **Kubernetes and Helm providers** to deploy applications to the EKS cluster. These providers must be configured at the **root level** (your example/project) and explicitly passed down through the module hierarchy.

**Provider Flow Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                        Root Level                              │
│                                                                 │
│  1. Configure Providers                                         │
│     provider "kubernetes" {                                     │
│       host = module.ddc.ddc_infra.cluster_endpoint             │
│       # ... EKS connection details                              │
│     }                                                           │
│                                                                 │
│  2. Pass to Main Module                                         │
│     module "unreal_cloud_ddc" {                                 │
│       providers = {                                             │
│         kubernetes = kubernetes  ←───────────────────────────────────┐│
│         helm       = helm        ←───────────────────────────────────┐││
│       }                                                        │││
│     }                                                          │││
└─────────────────────────────────────────────────────────────────┘││
                                                                 │││
┌─────────────────────────────────────────────────────────────────┘││
│                     Main DDC Module                             ││
│                                                                 ││
│  3. Receive and Pass to Submodule                              ││
│     module "ddc_services" {                                     ││
│       providers = {                                             ││
│         kubernetes = kubernetes  ←──────────────────────────────────────┘│
│         helm       = helm        ←───────────────────────────────────────┘
│       }                                                          
│     }                                                            
└─────────────────────────────────────────────────────────────────┘
                                                                   
┌─────────────────────────────────────────────────────────────────┐
│                    ddc-services Submodule                      │
│                                                                 │
│  4. Use Configured Providers                                    │
│     resource "kubernetes_namespace" "ddc" { ... }               │
│     resource "helm_release" "ddc_app" { ... }                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Step-by-Step Implementation:**

**Step 1: Root Level Provider Configuration**

```hcl
# examples/single-region/providers.tf

# AWS Provider - inherited automatically, no passing needed
provider "aws" {
  region = "us-east-1"
}

# Kubernetes Provider - MUST be configured and passed
provider "kubernetes" {
  host                   = module.unreal_cloud_ddc.ddc_infra.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.ddc_infra.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.ddc_infra.cluster_name]
  }
}

# Helm Provider - MUST be configured and passed
provider "helm" {
  kubernetes {
    host                   = module.unreal_cloud_ddc.ddc_infra.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.ddc_infra.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.ddc_infra.cluster_name]
    }
  }
}
```

**Step 2: Root Level Module Call (Pass Providers Down)**

```hcl
# examples/single-region/main.tf
module "unreal_cloud_ddc" {
  source = "../../"
  
  # CRITICAL: Must pass providers explicitly
  providers = {
    kubernetes = kubernetes  # Pass configured K8s provider
    helm       = helm        # Pass configured Helm provider
    # AWS provider inherited automatically - no need to pass
  }
  
  # ... rest of your DDC configuration
  ddc_infra_config = { ... }
  ddc_services_config = { ... }
}
```

**Step 3: Main Module Receives and Passes to Submodules**

```hcl
# modules/unreal/unreal-cloud-ddc/main.tf (already implemented)
module "ddc_services" {
  source = "./modules/ddc-services"
  count  = var.ddc_services_config != null ? 1 : 0
  
  # Pass received providers to submodule
  providers = {
    kubernetes = kubernetes  # Forward from root level
    helm       = helm        # Forward from root level
  }
  
  # ... service configuration
}
```

**Step 4: Submodule Declares Provider Requirements**

```hcl
# modules/unreal/unreal-cloud-ddc/modules/ddc-services/versions.tf
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.16.0"
    }
  }
}
```

**Complete Provider Passing Map:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    WHERE TO CONFIGURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📁 examples/single-region/                                     │
│  ├── 📄 providers.tf ← CONFIGURE kubernetes & helm here        │
│  └── 📄 main.tf      ← PASS providers to main module here      │
│                                                                 │
│  📁 modules/unreal/unreal-cloud-ddc/                            │
│  └── 📄 main.tf      ← PASS providers to ddc-services here     │
│                                                                 │
│  📁 modules/unreal/unreal-cloud-ddc/modules/ddc-services/       │
│  └── 📄 versions.tf  ← DECLARE provider requirements here      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**What Happens Without Explicit Provider Passing:**

| Problem | Symptom | Root Cause |
|---------|---------|------------|
| **Circular Dependency** | `Error: Cycle: provider → module → provider` | Provider config uses module outputs, but module needs provider first |
| **Localhost Connection** | `dial tcp 127.0.0.1:80: connection refused` | Kubernetes provider defaults to local cluster instead of EKS |
| **Missing Provider** | `Warning: Missing required provider configuration` | Submodules can't find configured providers |

**Why This Architecture Works:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPENDENCY FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. ddc-infra creates EKS cluster                              │
│     ├── cluster_endpoint                                        │
│     ├── cluster_name                                            │
│     └── cluster_certificate_authority_data                     │
│                                                                 │
│  2. Root level configures providers using ↑ outputs           │
│     ├── provider "kubernetes" { host = cluster_endpoint }       │
│     └── provider "helm" { kubernetes { host = ... } }           │
│                                                                 │
│  3. Providers passed explicitly to ddc-services               │
│     └── No circular dependency because providers are           │
│         configured AFTER infrastructure exists                 │
│                                                                 │
│  4. ddc-services uses configured providers                     │
│     ├── kubernetes_namespace                                    │
│     └── helm_release                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key Insight:** The explicit provider passing **breaks the circular dependency** by separating provider configuration (root level) from provider usage (submodules).

**Quick Reference - Single Region:**

1. **Configure providers** in `examples/single-region/providers.tf`
2. **Pass providers** in `examples/single-region/main.tf` module call
3. **That's it!** - The main module handles the rest

### Multi-Region Provider Configuration

**Multi-region deployments require provider aliases** to distinguish between regions. Each region needs its own set of Kubernetes and Helm providers.

**Multi-Region Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Root Level (Multi-Region)                   │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Primary   │  │ Kubernetes      │  │  Helm Primary   │ │
│  │   (alias)       │  │ Primary (alias) │  │  (alias)        │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  AWS Secondary  │  │ Kubernetes      │  │ Helm Secondary  │ │
│  │   (alias)       │  │Secondary (alias)│  │  (alias)        │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                │                │               │
│                                ▼                ▼               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Primary DDC Module                             │ │
│  │  providers = {                                              │ │
│  │    aws        = aws.primary                                 │ │
│  │    kubernetes = kubernetes.primary                          │ │
│  │    helm       = helm.primary                                │ │
│  │  }                                                          │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │             Secondary DDC Module                            │ │
│  │  providers = {                                              │ │
│  │    aws        = aws.secondary                               │ │
│  │    kubernetes = kubernetes.secondary                        │ │
│  │    helm       = helm.secondary                              │ │
│  │  }                                                          │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Multi-Region Provider Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                     Multi-Region Flow                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Configure Aliased Providers                                 │
│     provider "aws" { alias = "primary", region = "us-east-1" }   │
│     provider "aws" { alias = "secondary", region = "us-west-2" } │
│     provider "kubernetes" { alias = "primary", ... }             │
│     provider "kubernetes" { alias = "secondary", ... }           │
│                                                                 │
│  2. Pass Aliased Providers to Each Module                      │
│     module "ddc_primary" {                                      │
│       providers = {                                             │
│         aws        = aws.primary        ←─────────────────────┐ │
│         kubernetes = kubernetes.primary ←─────────────────────┐ │
│         helm       = helm.primary       ←─────────────────────┐ │
│       }                                                      │ │
│     }                                                        │ │
│                                                              │ │
│     module "ddc_secondary" {                                 │ │
│       providers = {                                          │ │
│         aws        = aws.secondary      ←─────────────────────┘ │
│         kubernetes = kubernetes.secondary ←───────────────────┘ │
│         helm       = helm.secondary     ←─────────────────────┘ │
│       }                                                        │
│     }                                                          │
│                                                                │
│  3. Each Module Uses Its Region-Specific Providers            │
│     Primary → us-east-1 EKS cluster                           │
│     Secondary → us-west-2 EKS cluster                         │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

**Multi-Region Implementation Steps:**

**Step 1: Configure Aliased Providers**

```hcl
# examples/multi-region/providers.tf

# AWS Providers with aliases
provider "aws" {
  alias  = "primary"
  region = local.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = local.secondary_region
}

# Kubernetes Providers with aliases
provider "kubernetes" {
  alias                  = "primary"
  host                   = module.unreal_cloud_ddc_primary.ddc_infra.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_primary.ddc_infra.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_primary.ddc_infra.cluster_name, "--region", local.primary_region]
  }
}

provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.unreal_cloud_ddc_secondary.ddc_infra.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_secondary.ddc_infra.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_secondary.ddc_infra.cluster_name, "--region", local.secondary_region]
  }
}

# Helm Providers with aliases
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = module.unreal_cloud_ddc_primary.ddc_infra.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_primary.ddc_infra.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_primary.ddc_infra.cluster_name, "--region", local.primary_region]
    }
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = module.unreal_cloud_ddc_secondary.ddc_infra.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_secondary.ddc_infra.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_secondary.ddc_infra.cluster_name, "--region", local.secondary_region]
    }
  }
}
```

**Step 2: Pass Aliased Providers to Modules**

```hcl
# examples/multi-region/main.tf

# Primary Region Module
module "unreal_cloud_ddc_primary" {
  source = "../../"
  
  # CRITICAL: Pass region-specific providers
  providers = {
    aws        = aws.primary
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
  
  # ... rest of primary region configuration
}

# Secondary Region Module
module "unreal_cloud_ddc_secondary" {
  source = "../../"
  
  # CRITICAL: Pass region-specific providers
  providers = {
    aws        = aws.secondary
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
  }
  
  # ... rest of secondary region configuration
  depends_on = [module.unreal_cloud_ddc_primary]
}
```

**Key Multi-Region Differences:**

| Aspect | Single Region | Multi-Region |
|--------|---------------|---------------|
| **Provider Aliases** | Not needed | Required for each region |
| **AWS Provider** | Auto-inherited | Must pass with alias |
| **Module Calls** | One module | Multiple modules with different providers |
| **Dependencies** | None | Secondary depends on primary |

### Ephemeral Secrets Implementation

**Security Challenge:**

Traditional Terraform stores all values in state files, including sensitive data like passwords and tokens. This creates security risks when state files are shared or stored in version control.

**Ephemeral Values Solution:**

Terraform 1.11+ introduces **ephemeral values** and **write-only attributes** that never get stored in state files, providing enhanced security for sensitive data.

**Implementation Pattern:**

```hcl
# 1. Generate password ephemerally (not stored in state)
ephemeral "random_password" "ddc_token" {
  length  = 64
  special = false
}

# 2. Store in AWS Secrets Manager with write-only (not stored in state)
resource "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  secret_id                = aws_secretsmanager_secret.unreal_cloud_ddc_token[0].id
  secret_string_wo         = ephemeral.random_password.ddc_token[0].result  # Write-only
  secret_string_wo_version = 1
}

# 3. Use direct resource reference (not ephemeral read due to Helm limitations)
ddc_bearer_token = aws_secretsmanager_secret_version.unreal_cloud_ddc_token[0].secret_string_wo
```

**Security Benefits:**

- ✅ **Password generation** - Never stored in Terraform state
- ✅ **Secret storage** - Never stored in Terraform state  
- ⚠️ **Helm usage** - Stored in state (unavoidable with current Helm provider)

**Why Not Full Ephemeral Chain:**

The **Helm provider limitation** prevents complete ephemeral implementation:

- **Helm `values` must be in state** - Terraform needs to track configuration changes
- **No `values_wo` support** - Helm provider doesn't support write-only values
- **No ephemeral support** - Helm can't accept ephemeral values

**Security Comparison:**

| Approach | Password in State | Secret Storage in State | Helm Usage in State |
|----------|-------------------|-------------------------|---------------------|
| **Traditional** | ❌ Yes | ❌ Yes | ❌ Yes |
| **Ephemeral (This Module)** | ✅ No | ✅ No | ❌ Yes |
| **Theoretical Full Ephemeral** | ✅ No | ✅ No | ✅ No |

**Practical Impact:**

While not perfect, this implementation provides **significant security improvement**:
- **Reduced attack surface** - Secret appears in fewer places in state
- **Better audit trail** - Clear separation of secure vs. non-secure components
- **Future-ready** - Prepared for when Helm provider adds write-only support

**Alternative Approaches:**

If complete state isolation is required:
1. **External Secrets Operator** - Inject secrets at pod runtime from AWS Secrets Manager
2. **Kubernetes Manifests** - Use `kubernetes_manifest` instead of Helm (still stores config)
3. **Init Containers** - Fetch secrets during container startup

These alternatives add complexity but provide complete state isolation if required by security policies.

## 🔄 Migration Guide

Safe migration strategies and module version update procedures.

### From Existing Infrastructure

If you already have DDC infrastructure deployed, you can gradually migrate to this module:

1. **Deploy new infrastructure** alongside existing (different names/regions)
2. **Test thoroughly** with new infrastructure
3. **Migrate data/traffic** gradually using DDC replication features
4. **Decommission old infrastructure** once migration is complete

### Module Version Updates

For general guidance on toolkit versioning (commit hash vs release tags), see the [Module Version Management](../../docs/modules/index.md#module-version-management) documentation.

**Version Update Process:**

1. **Test new version** in development environment
2. **Review CHANGELOG.md** for breaking changes
3. **Update commit hash/tag** in configuration
4. **Run terraform plan** to review changes
5. **Apply in staging** before production
6. **Monitor deployment** for issues

**Breaking Changes:**

- Always review module documentation before updating
- Test in non-production environment first
- Plan for potential resource recreation
- Keep backups of critical data (S3, ScyllaDB)

## ⚙️ Advanced Configuration

Multi-region configurations and build farm optimizations for your Unreal Engine projects.

### Multi-Region Unreal Engine Setup

For teams distributed across regions, configure Unreal Engine to use multiple DDC endpoints:

```ini
[DDC]
; Primary region DDC
Primary=(Type=S3, Remote=true, Bucket=primary-bucket, Region=us-east-1, BaseUrl=http://ddc-primary.yourdomain.com)

; Secondary region DDC (fallback)
Secondary=(Type=S3, Remote=true, Bucket=secondary-bucket, Region=us-west-2, BaseUrl=http://ddc-secondary.yourdomain.com)

; Try primary first, then secondary, then local
Hierarchical=(Type=Hierarchical, Inner=Primary, Inner=Secondary, Inner=Local)
```

### Build Farm Integration

Optimized configuration for build machines:

```ini
[DDC]
DefaultBackend=SharedOnly
SharedOnly=(Type=S3, Remote=true, Bucket=your-bucket, Region=your-region, BaseUrl=http://your-ddc-endpoint, MaxCacheSize=50GB)
```

## 🛡️ Access Control & Security

Understand the difference between infrastructure access and application access.

### Critical Understanding: Two Types of Access

This module manages both **infrastructure** (AWS resources) and **applications** (Kubernetes), creating two distinct access requirements:

#### 1. Infrastructure Access (DevOps/CI)

- **Who needs this:** DevOps teams, CI/CD systems
- **What it controls:** `kubectl`, `terraform apply`, cluster management
- **Configuration:** `eks_api_access_cidrs` in `ddc_infra_config`
- **Security impact:** Full cluster control

#### 2. Application Access (End Users)

- **Who needs this:** Game developers, Unreal Engine clients, build systems
- **What it controls:** DDC API for asset caching
- **Configuration:** Security groups (`existing_security_groups`, `additional_*_security_groups`)
- **Security impact:** Limited to DDC operations

### Security Group Architecture

The module provides **4 levels of security group access control**:

#### Global Access (Simple)
```hcl
existing_security_groups = [aws_security_group.allow_my_ip.id]
```
**Flow:** `User → Global SG → ALL Load Balancers → All Services`

**Use for:** General access, your IP, office network

#### Targeted Access (Granular)
```hcl
ddc_infra_config = {
  additional_nlb_security_groups = [aws_security_group.game_clients.id]  # DDC NLB only
  additional_eks_security_groups = [aws_security_group.devops_team.id]   # EKS cluster only
}
ddc_monitoring_config = {
  additional_alb_security_groups = [aws_security_group.monitoring_team.id] # Monitoring ALB only
}
```

**Security Flows:**

1. **DDC NLB Access:** `Game Clients → additional_nlb_security_groups → DDC NLB → DDC Service`
2. **EKS Cluster Access:** `DevOps Team → additional_eks_security_groups → EKS Cluster → kubectl/services`
3. **Monitoring ALB Access:** `Ops Team → additional_alb_security_groups → Monitoring ALB → Grafana Dashboard`

#### What Each Security Group Controls

| Security Group | Controls Access To | Use Cases |
|---|---|---|
| `existing_security_groups` | **All load balancers** (NLB + ALB) | General access, your IP, office network |
| `additional_nlb_security_groups` | **DDC NLB only** | Game clients, build systems, Unreal Engine |
| `additional_eks_security_groups` | **EKS cluster only** | kubectl users, CI/CD, direct service access |
| `additional_alb_security_groups` | **Monitoring ALB only** | Ops team, monitoring tools, Grafana users |

#### Role-Based Access Example

```hcl
# Global access for everyone
existing_security_groups = [aws_security_group.allow_my_ip.id]

# Targeted access by role
ddc_infra_config = {
  additional_nlb_security_groups = [
    aws_security_group.game_developers.id,
    aws_security_group.build_machines.id
  ]
  additional_eks_security_groups = [
    aws_security_group.devops_team.id,
    aws_security_group.ci_cd_systems.id
  ]
}

ddc_monitoring_config = {
  additional_alb_security_groups = [
    aws_security_group.monitoring_team.id,
    aws_security_group.alerting_systems.id
  ]
}
```

**⚠️ Security Best Practices:**

- **Minimize EKS API access:** Only give to users who need cluster management
- **Separate access types:** Game developers need DDC access, not kubectl access
- **Use role-based security groups:** Different teams get different access levels
- **Combine global + targeted:** Use `existing_security_groups` for basic access, `additional_*` for specific roles

<!-- BEGIN_TF_DOCS -->
