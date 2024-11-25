To use this example you will need to deploy each module individually.
```
terraform apply --target module.unreal_cloud_ddc_vpc
terraform apply --target module.unreal_cloud_ddc_infra
terraform apply --target module.unreal_cloud_ddc_intra_cluster
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.38 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.24.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.38 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc_infra"></a> [unreal\_cloud\_ddc\_infra](#module\_unreal\_cloud\_ddc\_infra) | ../../modules/unreal/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster"></a> [unreal\_cloud\_ddc\_intra\_cluster](#module\_unreal\_cloud\_ddc\_intra\_cluster) | ../../modules/unreal/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_vpc"></a> [unreal\_cloud\_ddc\_vpc](#module\_unreal\_cloud\_ddc\_vpc) | git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git | 25322b6b6be69db6cca7f167d7b0e5327156a595 |

## Resources

| Name | Type |
|------|------|
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_caller_ip"></a> [caller\_ip](#input\_caller\_ip) | IPs that will be allow listed to access cluster over internet | `list(string)` | `[]` | no |
| <a name="input_ghcr_password"></a> [ghcr\_password](#input\_ghcr\_password) | GHCR password | `string` | n/a | yes |
| <a name="input_ghcr_username"></a> [ghcr\_username](#input\_ghcr\_username) | GHCR username | `string` | n/a | yes |
| <a name="input_jwt_audience"></a> [jwt\_audience](#input\_jwt\_audience) | JWT Audience | `string` | n/a | yes |
| <a name="input_jwt_authority"></a> [jwt\_authority](#input\_jwt\_authority) | JWT Authority | `string` | n/a | yes |
| <a name="input_okta_auth_server_id"></a> [okta\_auth\_server\_id](#input\_okta\_auth\_server\_id) | Okta Auth Server ID | `string` | n/a | yes |
| <a name="input_okta_domain"></a> [okta\_domain](#input\_okta\_domain) | Okta Domain | `string` | n/a | yes |
| <a name="input_profile"></a> [profile](#input\_profile) | AWS Profile name | `string` | `"default"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | `"us-west-2"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.73.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.24.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.77.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc_infra"></a> [unreal\_cloud\_ddc\_infra](#module\_unreal\_cloud\_ddc\_infra) | ../../modules/unreal/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster"></a> [unreal\_cloud\_ddc\_intra\_cluster](#module\_unreal\_cloud\_ddc\_intra\_cluster) | ../../modules/unreal/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_vpc"></a> [unreal\_cloud\_ddc\_vpc](#module\_unreal\_cloud\_ddc\_vpc) | ./vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_authorization_token.token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret.oidc_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eks_cluster_ip_allow_list"></a> [eks\_cluster\_ip\_allow\_list](#input\_eks\_cluster\_ip\_allow\_list) | IPs that will be allow listed to access cluster over internet | `list(string)` | `[]` | no |
| <a name="input_github_credential_arn"></a> [github\_credential\_arn](#input\_github\_credential\_arn) | Github Credential ARN | `string` | n/a | yes |
| <a name="input_oidc_credential_arn"></a> [oidc\_credential\_arn](#input\_oidc\_credential\_arn) | OIDC Secrets Credential ARN | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
