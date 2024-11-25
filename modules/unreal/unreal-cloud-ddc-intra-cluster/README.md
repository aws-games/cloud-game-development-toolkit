<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.38 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.9.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.24.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.38 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >=2.9.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >=2.24.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_load_balancer_controller"></a> [aws\_load\_balancer\_controller](#module\_aws\_load\_balancer\_controller) | git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addon.git | 327207ad17f3069fdd0a76c14d3e07936eff4582 |
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addon.git | 327207ad17f3069fdd0a76c14d3e07936eff4582 |
| <a name="module_ebs_csi_irsa_role"></a> [ebs\_csi\_irsa\_role](#module\_ebs\_csi\_irsa\_role) | git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks | ccb4f252cc340d85fd70a8a1fb1cae496a698c1f |
| <a name="module_eks_blueprints_all_other_addons"></a> [eks\_blueprints\_all\_other\_addons](#module\_eks\_blueprints\_all\_other\_addons) | git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git | a9963f4a0e168f73adb033be594ac35868696a91 |
| <a name="module_eks_service_account_iam_role"></a> [eks\_service\_account\_iam\_role](#module\_eks\_service\_account\_iam\_role) | git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-assumable-role-with-oidc | ccb4f252cc340d85fd70a8a1fb1cae496a698c1f |
| <a name="module_s3_iam_policy"></a> [s3\_iam\_policy](#module\_s3\_iam\_policy) | git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-policy | ccb4f252cc340d85fd70a8a1fb1cae496a698c1f |

## Resources

| Name | Type |
|------|------|
| [helm_release.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.unreal_cloud_ddc_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_eks_cluster.unreal_cloud_ddc_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cert_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_s3_bucket.unreal_cloud_ddc_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager_hosted_zone_arns"></a> [cert\_manager\_hosted\_zone\_arns](#input\_cert\_manager\_hosted\_zone\_arns) | List of ARNs to be passed to Certificate Manager Addon | `list(string)` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS Cluster | `string` | n/a | yes |
| <a name="input_external_secrets_secret_manager_arn_list"></a> [external\_secrets\_secret\_manager\_arn\_list](#input\_external\_secrets\_secret\_manager\_arn\_list) | List of ARNS for Secret Manager Secrets to use in Unreal Cloud DDC | `list(string)` | `[]` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the OIDC Provider from EKS Cluster | `string` | n/a | yes |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID of the S3 Bucket for Unreal Cloud DDC to use | `string` | n/a | yes |
| <a name="input_unreal_cloud_ddc_helm_values"></a> [unreal\_cloud\_ddc\_helm\_values](#input\_unreal\_cloud\_ddc\_helm\_values) | List of YAML files for Unreal Cloud DDC | `list(string)` | `[]` | no |
| <a name="input_unreal_cloud_ddc_namespace"></a> [unreal\_cloud\_ddc\_namespace](#input\_unreal\_cloud\_ddc\_namespace) | Namespace for Unreal Cloud DDC | `string` | `"unreal-cloud-ddc"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.73.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=2.16.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.33.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.77.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.16.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.34.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ebs_csi_irsa_role"></a> [ebs\_csi\_irsa\_role](#module\_ebs\_csi\_irsa\_role) | git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks | ccb4f252cc340d85fd70a8a1fb1cae496a698c1f |
| <a name="module_eks_blueprints_all_other_addons"></a> [eks\_blueprints\_all\_other\_addons](#module\_eks\_blueprints\_all\_other\_addons) | git::https://github.com/aws-ia/terraform-aws-eks-blueprints-addons.git | a9963f4a0e168f73adb033be594ac35868696a91 |
| <a name="module_eks_service_account_iam_role"></a> [eks\_service\_account\_iam\_role](#module\_eks\_service\_account\_iam\_role) | git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks | ccb4f252cc340d85fd70a8a1fb1cae496a698c1f |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_pull_through_cache_rule.unreal_cloud_ddc_ecr_pull_through_cache_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_iam_policy.s3_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secrets_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [helm_release.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.unreal_cloud_ddc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.unreal_cloud_ddc_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.unreal_cloud_ddc_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.unreal_cloud_ddc_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS Cluster | `string` | n/a | yes |
| <a name="input_gchr_credentials_secret_manager_arn"></a> [gchr\_credentials\_secret\_manager\_arn](#input\_gchr\_credentials\_secret\_manager\_arn) | Arn for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache. | `string` | n/a | yes |
| <a name="input_oidc_credentials_secret_manager_arn"></a> [oidc\_credentials\_secret\_manager\_arn](#input\_oidc\_credentials\_secret\_manager\_arn) | Arn for oidc credentials stored in secret manager. | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the OIDC Provider from EKS Cluster | `string` | n/a | yes |
| <a name="input_s3_bucket_id"></a> [s3\_bucket\_id](#input\_s3\_bucket\_id) | ID of the S3 Bucket for Unreal Cloud DDC to use | `string` | n/a | yes |
| <a name="input_unreal_cloud_ddc_helm_values"></a> [unreal\_cloud\_ddc\_helm\_values](#input\_unreal\_cloud\_ddc\_helm\_values) | List of YAML files for Unreal Cloud DDC | `list(string)` | `[]` | no |
| <a name="input_unreal_cloud_ddc_namespace"></a> [unreal\_cloud\_ddc\_namespace](#input\_unreal\_cloud\_ddc\_namespace) | Namespace for Unreal Cloud DDC | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_unreal_cloud_ddc_version"></a> [unreal\_cloud\_ddc\_version](#input\_unreal\_cloud\_ddc\_version) | Version of the Unreal Cloud DDC Helm chart | `string` | `"1.2.0"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
