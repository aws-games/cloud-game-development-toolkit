<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.89.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.89.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_codebuild_project.codebuild_project](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/codebuild_project) | resource |
| [aws_ecr_repository.ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/ecr_repository) | resource |
| [aws_iam_role.codebuild_role](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codebuild_policy](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base_image"></a> [base\_image](#input\_base\_image) | The base image to use for the custom image build. This is the image that will be used as the starting point for the build. | `string` | `null` | no |
| <a name="input_ecr_kms_key_id"></a> [ecr\_kms\_key\_id](#input\_ecr\_kms\_key\_id) | KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed. | `string` | `"alias/aws/ecr"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. Development, Staging, Production, etc.). This will tag ressources and set ASPNETCORE\_ENVIRONMENT variable. | `string` | `"Development"` | no |
| <a name="input_ghcr_credentials_secret_manager_arn"></a> [ghcr\_credentials\_secret\_manager\_arn](#input\_ghcr\_credentials\_secret\_manager\_arn) | Arn for credentials stored in secret manager. | `string` | n/a | yes |
| <a name="input_image_tags"></a> [image\_tags](#input\_image\_tags) | List of tags to use for the custom image build. This is a list of tags that will be applied to the built image. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | (Required) The name prepended to resources created by the module. | `string` | n/a | yes |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "iac-management": "CGD-Toolkit",<br/>  "iac-module": "container-image-pipeline",<br/>  "iac-provider": "Terraform"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_codebuild_project_name"></a> [codebuild\_project\_name](#output\_codebuild\_project\_name) | Name of the created CodeBuild project |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | URL of the created ECR repository |
<!-- END_TF_DOCS -->
