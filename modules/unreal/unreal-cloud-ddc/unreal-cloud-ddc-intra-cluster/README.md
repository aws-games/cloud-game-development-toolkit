# Unreal Engine Cloud DDC Intra Cluster Module

!!!warning
    Many of the links in this document lead back to the Unreal Engine source code hosted on GitHub. Access to the Unreal Engine source code requires that you connect your existing GitHub account to your Epic account. If you are seeing 404 errors when opening certain links, follow the instructions [here](https://www.unrealengine.com/en-US/ue-on-github) to connect your accounts.

[Unreal Cloud Derived Data Cache](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine) ([source code](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)) is a caching system that stores additional data required to use assets, such as compiled shaders. This allows the engine to quickly retrieve this data instead of having to regenerate it, saving time and disk space for the development team. For distributed teams, a cloud-hosted DDC enables efficient collaboration by ensuring all team members have access to the same cached data regardless of their location. This Terraform module deploys the [Unreal Cloud DDC container image](https://github.com/orgs/EpicGames/packages/container/package/unreal-cloud-ddc) provided by the Epic Games GitHub organization. It also configures the necessary service accounts and IAM roles required to run the Unreal Cloud DDC service on AWS.

This module currently utilizes the [Terraform EKS Blueprints Addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons) repository to install the following addons to the Kubernetes cluster, with the required IAM roles and service accounts:

- **CoreDNS**: Provides DNS services for the Kubernetes cluster, enabling reliable name resolution for the Unreal Cloud DDC service.
    Kube-Proxy: Manages network traffic routing within the cluster, ensuring seamless communication between the Unreal Cloud DDC service and other components.
- **VPC-CNI**: Implements the Kubernetes networking model within the AWS VPC, allowing the Unreal Cloud DDC service to be properly integrated with the network infrastructure.
- **EBS CSI Driver**: Provides persistent storage capabilities using Amazon Elastic Block Store (EBS), enabling the Unreal Cloud DDC service to store and retrieve cached data.

## Deployment Architecture
![Unreal Engine Cloud DDC Infrastructure Module Architecture](./assets/media/diagrams/unreal-cloud-ddc-single-region.png)

## Prerequisites
!!!note
    This module is designed to be used in conjunction with the [Unreal Cloud DDC Infra Module](../unreal-cloud-ddc-infra/README.md) which deploys the required infrastructure to host the Cloud DDC service.

## Authentication & Security

### Bearer Token Authentication

The Unreal Cloud DDC uses bearer tokens to authenticate API requests and prevent unauthorized access to cached game assets.

**How Bearer Tokens Work:**
- Auto-generated 64-character secure token stored in AWS Secrets Manager
- Required in the `Authorization: ServiceAccount <token>` header for all API calls
- Validates client access to read/write cached data
- Replicated across regions in multi-region deployments

**Token Usage Example:**
```bash
# Get token from Secrets Manager
TOKEN=$(aws secretsmanager get-secret-value --secret-id unreal-cloud-ddc-bearer-token --query SecretString --output text)

# Use in API calls
curl -H "Authorization: ServiceAccount $TOKEN" http://ddc-url/api/v1/refs/ddc/default/...
```

**Production Recommendations:**
- Use OIDC authentication instead of bearer tokens for enhanced security
- Rotate tokens regularly
- Store tokens securely and never commit to version control

### GitHub Container Registry Access

**Why Manual Setup is Required:**
Access to Epic's Unreal Cloud DDC container images requires specific ECR pull-through cache configuration that cannot be automated due to AWS naming requirements.

**Setup Steps:**

1. **Link GitHub to Epic Account**
   - Visit [Unreal Engine on GitHub](https://www.unrealengine.com/en-US/ue-on-github)
   - Connect your existing GitHub account to your Epic account
   - This grants access to the Unreal Engine repository and container images

2. **Create GitHub Personal Access Token**
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - **Required Permissions:**
     - `read:packages` - Access to GitHub Container Registry packages
     - `repo` - Access to private repositories (required for Unreal Engine repo)
   - [Detailed instructions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
   
   ⚠️ **Critical**: Both permissions are mandatory. Missing either will cause container pull failures.

3. **Create AWS Secret (Required Format)**
   ```bash
   aws secretsmanager create-secret \
     --name "ecr-pullthroughcache/github-credentials" \
     --secret-string '{"username":"YOUR-GITHUB-USERNAME","access-token":"YOUR-GITHUB-TOKEN"}'
   ```

**Critical Requirements:**
- Secret name **must** be prefixed with `ecr-pullthroughcache/`
- JSON fields **must** be named `username` and `access-token`
- These naming requirements are enforced by AWS ECR pull-through cache

4. **Pass Secret ARN to Module**
   ```hcl
   ghcr_credentials_secret_manager_arn = "arn:aws:secretsmanager:region:account:secret:ecr-pullthroughcache/github-credentials-XXXXXX"
   ```

## Networking Architecture

### Single Region Deployment
- **EKS Cluster**: Deployed in private subnets across multiple AZs
- **Load Balancer**: Network Load Balancer in public subnets
- **ScyllaDB**: Private instances with internal communication
- **S3 Access**: Via VPC endpoint for optimal performance

### Multi-Region Deployment
- **Inter-Region Connectivity**: Required between regions for ScyllaDB cluster communication
  - **Options**: VPC Peering, Transit Gateway, or Direct Connect
  - **Requirements**: Private network connectivity with appropriate routing
- **Cross-Region Replication**: Automatic data synchronization between regions
- **Load Balancing**: Route53 latency-based routing between regional endpoints
- **Security Groups**: Cross-region rules for ScyllaDB cluster ports (7000, 9042, etc.)

### Security Group Configuration
**EKS Cluster Security Groups:**
- Inbound: HTTPS (443) from load balancer
- Outbound: All traffic for container registry and S3 access

**ScyllaDB Security Groups:**
- Inbound: Cluster communication ports (7000, 7001, 9042, 9100, 9142, 9160, 9180, 10000)
- Cross-region: Same ports from peer VPC CIDR blocks

**Load Balancer Security Groups:**
- Inbound: HTTP (80), HTTPS (443) from allowed CIDR blocks
- Outbound: To EKS cluster on application ports

## Customizing Your Deployment

### OIDC Authentication (Production Recommended)
**OIDC vs Bearer Token Comparison:**

| Feature | Bearer Token | OIDC Authentication |
|---------|--------------|--------------------|
| **Security** | Static token | Dynamic, time-limited tokens |
| **Setup Complexity** | Simple | Requires IDP integration |
| **Production Ready** | Development only | ✅ Recommended |
| **Token Rotation** | Manual | Automatic |
| **Audit Trail** | Limited | Full user attribution |

**OIDC Setup Steps:**

1. **Configure Your Identity Provider**
   - Set up OIDC application in your IDP (Azure AD, Okta, etc.)
   - Configure redirect URIs and scopes
   - Note the client ID and client secret

2. **Create AWS Secret**
   ```bash
   aws secretsmanager create-secret \
     --name "external-idp-oidc-credentials" \
     --secret-string '{"client_secret":"YOUR-CLIENT-SECRET","client_id":"YOUR-CLIENT-ID"}'
   ```

3. **Configure Module Variable**
   ```hcl
   oidc_credentials_secret_manager_arn = "aws!arn:aws:secretsmanager:region:account:secret:external-idp-oidc-credentials-XXXXXX|client_secret"
   ```
   
   **Format Requirements:**
   - Prefix: `aws!`
   - Suffix: `|<json-field>` (e.g., `|client_secret`)

**Bearer Token Alternative (Development Only):**
For development environments, you can use the auto-generated bearer token:
```hcl
unreal_cloud_ddc_helm_config = {
  token = data.aws_secretsmanager_secret_version.ddc_token.secret_string
  # Other configuration...
}
```

⚠️ **Security Warning**: Bearer tokens should never be used in production environments due to their static nature and security limitations.

### Chart Values (Helm Configurations)

The `unreal_cloud_ddc_helm_values` variable provides an open-ended way to configure the Unreal Cloud DDC deployment through the use of YAML files. We generally recommend you to use a template file. An example of a template file configuration can be found in the `unreal-cloud-ddc-single-region` sample located [here](/samples/unreal-cloud-ddc-single-region/assets/unreal_cloud_ddc_single_region.yaml). You can also find additional example templates provided by Epic [here](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Helm/UnrealCloudDDC).

## Troubleshooting

### Common Deployment Issues

**Helm Chart Deployment Failures:**
- **Symptom**: Helm release stuck in pending or failed state
- **Cause**: Missing GitHub credentials or incorrect secret format
- **Solution**: Verify ECR pull-through cache secret exists and has correct format

**Pod CrashLoopBackOff:**
- **Symptom**: DDC pods continuously restarting
- **Cause**: ScyllaDB connection issues or authentication failures
- **Solution**: Check ScyllaDB connectivity and bearer token configuration

**Authentication Errors:**
- **Symptom**: HTTP 401 responses from DDC API
- **Cause**: Invalid or missing bearer token
- **Solution**: Verify token in Secrets Manager and Helm configuration

### Validation Commands

**Check Pod Status:**
```bash
# Configure kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check DDC pods
kubectl get pods -n unreal-cloud-ddc

# View pod logs
kubectl logs -n unreal-cloud-ddc -l app.kubernetes.io/name=unreal-cloud-ddc --tail=50
```

**Test API Connectivity:**
```bash
# Get bearer token
TOKEN=$(aws secretsmanager get-secret-value --secret-id unreal-cloud-ddc-bearer-token --query SecretString --output text)

# Test API endpoint
curl -H "Authorization: ServiceAccount $TOKEN" http://<load-balancer-url>/api/v1/refs/ddc/default/test
```

**Verify ScyllaDB Configuration:**
```bash
# Check from within DDC pod
POD_NAME=$(kubectl get pods -n unreal-cloud-ddc -l app.kubernetes.io/name=unreal-cloud-ddc -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n unreal-cloud-ddc $POD_NAME -- cqlsh -e "SELECT data_center FROM system.local;"
```

**Monitor Helm Releases:**
```bash
# List releases
helm list -n unreal-cloud-ddc

# Check release status
helm status unreal-cloud-ddc-initialize -n unreal-cloud-ddc
```

### Performance Optimization

**Load Balancer Configuration:**
- Use Network Load Balancer for better performance
- Enable cross-zone load balancing
- Configure appropriate health check settings

**Resource Allocation:**
- NVME nodes: Use for high-performance caching
- Worker nodes: Scale based on replication workload
- System nodes: Ensure adequate resources for Kubernetes system components


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=6.2.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.16.0, <3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.33.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >=3.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.2.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.37.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints_all_other_addons"></a> [eks\_blueprints\_all\_other\_addons](#module\_eks\_blueprints\_all\_other\_addons) | git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git | a9963f4a0e168f73adb033be594ac35868696a91 |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_iam_policy.s3_secrets_manager_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ebs_csi_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.unreal_cloud_ddc_sa_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ebs_csi_policy_attacment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.unreal_cloud_ddc_sa_iam_role_s3_secrets_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.unreal_cloud_ddc_initialization](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.unreal_cloud_ddc_with_replication](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.unreal_cloud_ddc_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [null_resource.delete_init_deployment](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.unreal_cloud_ddc_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.unreal_cloud_ddc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.unreal_cloud_ddc_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_s3_bucket.unreal_cloud_ddc_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_manager_hosted_zone_arn"></a> [certificate\_manager\_hosted\_zone\_arn](#input\_certificate\_manager\_hosted\_zone\_arn) | ARN of the Certificate Manager for Ingress. | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS Cluster | `string` | n/a | yes |
| <a name="input_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#input\_cluster\_oidc\_provider\_arn) | ARN of the OIDC Provider from EKS Cluster | `string` | n/a | yes |
| <a name="input_enable_certificate_manager"></a> [enable\_certificate\_manager](#input\_enable\_certificate\_manager) | Enable Certificate Manager for Ingress. Required for TLS termination. | `bool` | `false` | no |
| <a name="input_ghcr_credentials_secret_manager_arn"></a> [ghcr\_credentials\_secret\_manager\_arn](#input\_ghcr\_credentials\_secret\_manager\_arn) | Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache. | `string` | n/a | yes |
| <a name="input_is_multi_region_deployment"></a> [is\_multi\_region\_deployment](#input\_is\_multi\_region\_deployment) | Determines whether this is a multi region Unreal DDC deployment. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_oidc_credentials_secret_manager_arn"></a> [oidc\_credentials\_secret\_manager\_arn](#input\_oidc\_credentials\_secret\_manager\_arn) | Arn for oidc credentials stored in secret manager. | `string` | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where the Unreal Cloud DDC deployment will reside | `string` | n/a | yes |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID of the S3 Bucket for Unreal Cloud DDC to use | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "Unreal DDC"<br/>}</pre> | no |
| <a name="input_unreal_cloud_ddc_helm_base_infra_chart"></a> [unreal\_cloud\_ddc\_helm\_base\_infra\_chart](#input\_unreal\_cloud\_ddc\_helm\_base\_infra\_chart) | Path to your Unreal Cloud DDC helm chart | `string` | n/a | yes |
| <a name="input_unreal_cloud_ddc_helm_config"></a> [unreal\_cloud\_ddc\_helm\_config](#input\_unreal\_cloud\_ddc\_helm\_config) | Configuration values to pass to the Unreal Cloud DDC helm chart. | `map(string)` | `{}` | no |
| <a name="input_unreal_cloud_ddc_helm_replication_chart"></a> [unreal\_cloud\_ddc\_helm\_replication\_chart](#input\_unreal\_cloud\_ddc\_helm\_replication\_chart) | Path to your Unreal Cloud DDC helm chart if replication is needed. This is used in multi-region deployments and is not required for single region deployments. | `string` | `null` | no |
| <a name="input_unreal_cloud_ddc_namespace"></a> [unreal\_cloud\_ddc\_namespace](#input\_unreal\_cloud\_ddc\_namespace) | Namespace for Unreal Cloud DDC | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_unreal_cloud_ddc_service_account_name"></a> [unreal\_cloud\_ddc\_service\_account\_name](#input\_unreal\_cloud\_ddc\_service\_account\_name) | Name of Unreal Cloud DDC service account. | `string` | `"unreal-cloud-ddc-sa"` | no |
| <a name="input_unreal_cloud_ddc_version"></a> [unreal\_cloud\_ddc\_version](#input\_unreal\_cloud\_ddc\_version) | Version of the Unreal Cloud DDC Helm chart. | `string` | `"1.2.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_unreal_cloud_ddc_load_balancer_name"></a> [unreal\_cloud\_ddc\_load\_balancer\_name](#output\_unreal\_cloud\_ddc\_load\_balancer\_name) | n/a |
| <a name="output_unreal_cloud_ddc_load_balancer_zone_id"></a> [unreal\_cloud\_ddc\_load\_balancer\_zone\_id](#output\_unreal\_cloud\_ddc\_load\_balancer\_zone\_id) | n/a |
<!-- END_TF_DOCS -->
| Name | Description |
|------|-------------|
| <a name="output_unreal_cloud_ddc_load_balancer_name"></a> [unreal\_cloud\_ddc\_load\_balancer\_name](#output\_unreal\_cloud\_ddc\_load\_balancer\_name) | n/a |
| <a name="output_unreal_cloud_ddc_load_balancer_zone_id"></a> [unreal\_cloud\_ddc\_load\_balancer\_zone\_id](#output\_unreal\_cloud\_ddc\_load\_balancer\_zone\_id) | n/a |
<!-- END_TF_DOCS -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=6.2.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.16.0, <3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.33.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >=3.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.2.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.37.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints_all_other_addons"></a> [eks\_blueprints\_all\_other\_addons](#module\_eks\_blueprints\_all\_other\_addons) | git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git | a9963f4a0e168f73adb033be594ac35868696a91 |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_iam_policy.s3_secrets_manager_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ebs_csi_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.unreal_cloud_ddc_sa_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ebs_csi_policy_attacment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.unreal_cloud_ddc_sa_iam_role_s3_secrets_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.unreal_cloud_ddc_initialization](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.unreal_cloud_ddc_with_replication](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.unreal_cloud_ddc_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [null_resource.delete_init_deployment](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.unreal_cloud_ddc_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.unreal_cloud_ddc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.unreal_cloud_ddc_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_s3_bucket.unreal_cloud_ddc_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_manager_hosted_zone_arn"></a> [certificate\_manager\_hosted\_zone\_arn](#input\_certificate\_manager\_hosted\_zone\_arn) | ARN of the Certificate Manager for Ingress. | `list(string)` | `[]` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Endpoint of the EKS Cluster | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS Cluster | `string` | n/a | yes |
| <a name="input_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#input\_cluster\_oidc\_provider\_arn) | ARN of the OIDC Provider from EKS Cluster | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Version of the EKS Cluster | `string` | n/a | yes |
| <a name="input_enable_certificate_manager"></a> [enable\_certificate\_manager](#input\_enable\_certificate\_manager) | Enable Certificate Manager for Ingress. Required for TLS termination. | `bool` | `false` | no |
| <a name="input_ghcr_credentials_secret_manager_arn"></a> [ghcr\_credentials\_secret\_manager\_arn](#input\_ghcr\_credentials\_secret\_manager\_arn) | Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache. | `string` | n/a | yes |
| <a name="input_is_multi_region_deployment"></a> [is\_multi\_region\_deployment](#input\_is\_multi\_region\_deployment) | Determines whether this is a multi region Unreal DDC deployment. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_oidc_credentials_secret_manager_arn"></a> [oidc\_credentials\_secret\_manager\_arn](#input\_oidc\_credentials\_secret\_manager\_arn) | Arn for oidc credentials stored in secret manager. | `string` | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where the Unreal Cloud DDC deployment will reside | `string` | n/a | yes |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID of the S3 Bucket for Unreal Cloud DDC to use | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "Unreal DDC"<br/>}</pre> | no |
| <a name="input_unreal_cloud_ddc_helm_base_infra_chart"></a> [unreal\_cloud\_ddc\_helm\_base\_infra\_chart](#input\_unreal\_cloud\_ddc\_helm\_base\_infra\_chart) | Path to your Unreal Cloud DDC helm chart | `string` | n/a | yes |
| <a name="input_unreal_cloud_ddc_helm_config"></a> [unreal\_cloud\_ddc\_helm\_config](#input\_unreal\_cloud\_ddc\_helm\_config) | Configuration values to pass to the Unreal Cloud DDC helm chart. | `map(string)` | `{}` | no |
| <a name="input_unreal_cloud_ddc_helm_replication_chart"></a> [unreal\_cloud\_ddc\_helm\_replication\_chart](#input\_unreal\_cloud\_ddc\_helm\_replication\_chart) | Path to your Unreal Cloud DDC helm chart if replication is needed. This is used in multi-region deployments and is not required for single region deployments. | `string` | `null` | no |
| <a name="input_unreal_cloud_ddc_namespace"></a> [unreal\_cloud\_ddc\_namespace](#input\_unreal\_cloud\_ddc\_namespace) | Namespace for Unreal Cloud DDC | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_unreal_cloud_ddc_service_account_name"></a> [unreal\_cloud\_ddc\_service\_account\_name](#input\_unreal\_cloud\_ddc\_service\_account\_name) | Name of Unreal Cloud DDC service account. | `string` | `"unreal-cloud-ddc-sa"` | no |
| <a name="input_unreal_cloud_ddc_version"></a> [unreal\_cloud\_ddc\_version](#input\_unreal\_cloud\_ddc\_version) | Version of the Unreal Cloud DDC Helm chart. | `string` | `"1.2.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_unreal_cloud_ddc_load_balancer_name"></a> [unreal\_cloud\_ddc\_load\_balancer\_name](#output\_unreal\_cloud\_ddc\_load\_balancer\_name) | n/a |
| <a name="output_unreal_cloud_ddc_load_balancer_zone_id"></a> [unreal\_cloud\_ddc\_load\_balancer\_zone\_id](#output\_unreal\_cloud\_ddc\_load\_balancer\_zone\_id) | n/a |
<!-- END_TF_DOCS -->
