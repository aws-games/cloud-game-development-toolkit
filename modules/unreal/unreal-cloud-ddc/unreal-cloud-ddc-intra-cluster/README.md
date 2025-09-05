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

### GitHub Secret
Next, for the module to be able to access the Unreal Cloud DDC container image, there are 2 things you must do. First, if you have not done so, you must [connect your GitHub account to your Epic account](https://www.unrealengine.com/en-US/ue-on-github), thereby granting you access to the container images in the Unreal Engine repository. Next, you will need to create a `github_credentials` secret which includes a `username` and `access-token` field.

!!!note
    Instructions on creating a new access token can be found [here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens). You will need to provide the `read:package` and `repo` permissions to the access token you create.

You can then upload the secret to AWS Secret Manager using the following [AWS CLI](https://aws.amazon.com/cli/) command:

```commandline
aws secretsmanager create-secret --name "ecr-pullthroughcache/github-credentials" --secret-string '{"username":"USERNAME-PLACEHOLDER","access-token":"ACCESS-TOKEN-PLACEHOLDER"}'
```

!!!note
    Make sure to replace the `GITHUB-USERNAME-PLACEHOLDER` and `GITHUB-ACCESS-TOKEN-PLACEHOLDER` with the appropriate values from your GitHub account prior to running the command.

!!!warning
    Note that the name of the secret must be prefixed with `ecr-pullthroughcache/` and the fields must be called `username` and `access-token` for ECR to properly detect the secrets. If making changes to the above command, you must adhere to these rules.

Once the secret is created, pass the newly uploaded secret's ARN into the `ghcr_credentials_secret_manager_arn` variable.

## Customizing Your Deployment

### OIDC Secret
To use client secrets for OIDC authentication, a new secret must be uploaded to AWS Secrets Manager. You can upload the new secret to AWS Secret Manager using the following [AWS CLI](https://aws.amazon.com/cli/) command:

!!!note
    Make sure to replace the `CLIENT-SECRET-PLACEHOLDER` and `CLIENT-ID-PLACEHOLDER` with the appropriate values from your IDP prior to running the command.

```commandline
aws secretsmanager create-secret --name "external-idp-oidc-credentials" --secret-string '{"client_secret":"CLIENT-SECRET-PLACEHOLDER","client_id":"CLIENT-ID-PLACEHOLDER"}'
```

The ARN for the newly created secret must then be passed to the `oidc_credentials_secret_manager_arn` variable. The secret is referenced using the following format and should be passed into the variable using the same format:

```
aws!arn:aws:secretsmanager:<region>:<aws-account-number>:secret:<secret-name>|<json-field>
```

!!!note
    Note the prefix `aws!` and the postfix `|<json-field>` are added to the ARN of the newly created secret.

!!!note
    While we highly encourage the use of OIDC tokens for production environments, users can use a bearer token in its place by providing the token to the `unreal_cloud_ddc_helm_values` variable. See DDC sample for an example implementation.

    ```
        unreal_cloud_ddc_helm_values = [
            templatefile("${path.module}/assets/unreal_cloud_ddc_single_region.yaml", {
                token = <bearer-token>
                # Other templatefile parameters...
            })
        ]
    ```

### Chart Values (Helm Configurations)

The `unreal_cloud_ddc_helm_values` variable provides an open-ended way to configure the Unreal Cloud DDC deployment through the use of YAML files. We generally recommend you to use a template file. An example of a template file configuration can be found in the `unreal-cloud-ddc-single-region` sample located [here](/samples/unreal-cloud-ddc-single-region/assets/unreal_cloud_ddc_single_region.yaml). You can also find additional example templates provided by Epic [here](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Helm/UnrealCloudDDC).


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.73.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.16.0, <3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.33.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.10.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

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
| [helm_release.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.unreal_cloud_ddc_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.unreal_cloud_ddc_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.unreal_cloud_ddc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.unreal_cloud_ddc_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.unreal_cloud_ddc_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_manager_hosted_zone_arn"></a> [certificate\_manager\_hosted\_zone\_arn](#input\_certificate\_manager\_hosted\_zone\_arn) | ARN of the Certificate Manager for Ingress. | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS Cluster | `string` | n/a | yes |
| <a name="input_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#input\_cluster\_oidc\_provider\_arn) | ARN of the OIDC Provider from EKS Cluster | `string` | n/a | yes |
| <a name="input_enable_certificate_manager"></a> [enable\_certificate\_manager](#input\_enable\_certificate\_manager) | Enable Certificate Manager for Ingress. Required for TLS termination. | `bool` | `false` | no |
| <a name="input_ghcr_credentials_secret_manager_arn"></a> [ghcr\_credentials\_secret\_manager\_arn](#input\_ghcr\_credentials\_secret\_manager\_arn) | Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_oidc_credentials_secret_manager_arn"></a> [oidc\_credentials\_secret\_manager\_arn](#input\_oidc\_credentials\_secret\_manager\_arn) | Arn for oidc credentials stored in secret manager. | `string` | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID of the S3 Bucket for Unreal Cloud DDC to use | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "Unreal DDC"<br/>}</pre> | no |
| <a name="input_unreal_cloud_ddc_helm_values"></a> [unreal\_cloud\_ddc\_helm\_values](#input\_unreal\_cloud\_ddc\_helm\_values) | List of YAML files for Unreal Cloud DDC | `list(string)` | `[]` | no |
| <a name="input_unreal_cloud_ddc_namespace"></a> [unreal\_cloud\_ddc\_namespace](#input\_unreal\_cloud\_ddc\_namespace) | Namespace for Unreal Cloud DDC | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_unreal_cloud_ddc_service_account_name"></a> [unreal\_cloud\_ddc\_service\_account\_name](#input\_unreal\_cloud\_ddc\_service\_account\_name) | Name of Unreal Cloud DDC service account. | `string` | `"unreal-cloud-ddc-sa"` | no |
| <a name="input_unreal_cloud_ddc_version"></a> [unreal\_cloud\_ddc\_version](#input\_unreal\_cloud\_ddc\_version) | Version of the Unreal Cloud DDC Helm chart. | `string` | `"1.2.0"` | no |

## Outputs

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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.73.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.16.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.33.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.4.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.37.1 |

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
| [helm_release.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.unreal_cloud_ddc_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.unreal_cloud_ddc_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.unreal_cloud_ddc_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.unreal_cloud_ddc_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.unreal_cloud_ddc_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_manager_hosted_zone_arn"></a> [certificate\_manager\_hosted\_zone\_arn](#input\_certificate\_manager\_hosted\_zone\_arn) | ARN of the Certificate Manager for Ingress. | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS Cluster | `string` | n/a | yes |
| <a name="input_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#input\_cluster\_oidc\_provider\_arn) | ARN of the OIDC Provider from EKS Cluster | `string` | n/a | yes |
| <a name="input_enable_certificate_manager"></a> [enable\_certificate\_manager](#input\_enable\_certificate\_manager) | Enable Certificate Manager for Ingress. Required for TLS termination. | `bool` | `false` | no |
| <a name="input_ghcr_credentials_secret_manager_arn"></a> [ghcr\_credentials\_secret\_manager\_arn](#input\_ghcr\_credentials\_secret\_manager\_arn) | Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_oidc_credentials_secret_manager_arn"></a> [oidc\_credentials\_secret\_manager\_arn](#input\_oidc\_credentials\_secret\_manager\_arn) | Arn for oidc credentials stored in secret manager. | `string` | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID of the S3 Bucket for Unreal Cloud DDC to use | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "Unreal DDC"<br/>}</pre> | no |
| <a name="input_unreal_cloud_ddc_helm_values"></a> [unreal\_cloud\_ddc\_helm\_values](#input\_unreal\_cloud\_ddc\_helm\_values) | List of YAML files for Unreal Cloud DDC | `list(string)` | `[]` | no |
| <a name="input_unreal_cloud_ddc_namespace"></a> [unreal\_cloud\_ddc\_namespace](#input\_unreal\_cloud\_ddc\_namespace) | Namespace for Unreal Cloud DDC | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_unreal_cloud_ddc_service_account_name"></a> [unreal\_cloud\_ddc\_service\_account\_name](#input\_unreal\_cloud\_ddc\_service\_account\_name) | Name of Unreal Cloud DDC service account. | `string` | `"unreal-cloud-ddc-sa"` | no |
| <a name="input_unreal_cloud_ddc_version"></a> [unreal\_cloud\_ddc\_version](#input\_unreal\_cloud\_ddc\_version) | Version of the Unreal Cloud DDC Helm chart. | `string` | `"1.2.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_unreal_cloud_ddc_load_balancer_name"></a> [unreal\_cloud\_ddc\_load\_balancer\_name](#output\_unreal\_cloud\_ddc\_load\_balancer\_name) | n/a |
| <a name="output_unreal_cloud_ddc_load_balancer_zone_id"></a> [unreal\_cloud\_ddc\_load\_balancer\_zone\_id](#output\_unreal\_cloud\_ddc\_load\_balancer\_zone\_id) | n/a |
<!-- END_TF_DOCS -->
