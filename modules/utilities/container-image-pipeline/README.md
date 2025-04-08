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
| [aws_ecr_repository.ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/ecr_repository) | resource |
| [aws_iam_instance_profile.image_builder_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.image_builder_iam_role](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.image_builder_container_policy](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.image_builder_managed_policy](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.image_builder_ssm_policy](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_imagebuilder_component.base_component](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/imagebuilder_component) | resource |
| [aws_imagebuilder_container_recipe.container_recipe](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/imagebuilder_container_recipe) | resource |
| [aws_imagebuilder_distribution_configuration.distribution_configuration](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/imagebuilder_distribution_configuration) | resource |
| [aws_imagebuilder_image_pipeline.container_image_pipeline](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/imagebuilder_image_pipeline) | resource |
| [aws_imagebuilder_infrastructure_configuration.infrastructure_configuration](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/resources/imagebuilder_infrastructure_configuration) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/5.89.0/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_recipe_version"></a> [container\_recipe\_version](#input\_container\_recipe\_version) | The version of the container recipe. Must follow semantic versioning (major.minor.patch). | `string` | n/a | yes |
| <a name="input_ecr_kms_key_id"></a> [ecr\_kms\_key\_id](#input\_ecr\_kms\_key\_id) | KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed. | `string` | `"alias/aws/ecr"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. Development, Staging, Production, etc.). This will tag ressources and set ASPNETCORE\_ENVIRONMENT variable. | `string` | `"Development"` | no |
| <a name="input_image_builder_base_component_version"></a> [image\_builder\_base\_component\_version](#input\_image\_builder\_base\_component\_version) | The version of the base component to use in the container image pipeline. Must follow semantic versioning (major.minor.patch). | `string` | n/a | yes |
| <a name="input_imagebuilder_component_kms_key_id"></a> [imagebuilder\_component\_kms\_key\_id](#input\_imagebuilder\_component\_kms\_key\_id) | Optional KMS key ARN/ID to encrypt the EC2 Image Builder component. Replace with your own KMS key ARN/ID if needed. | `string` | `null` | no |
| <a name="input_imagebuilder_instance_types"></a> [imagebuilder\_instance\_types](#input\_imagebuilder\_instance\_types) | The instance types to use for the EC2 Image Builder component. | `list(string)` | <pre>[<br/>  "t3a.nano"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | (Required) The name prepended to resources created by the module. | `string` | n/a | yes |
| <a name="input_parent_container_image"></a> [parent\_container\_image](#input\_parent\_container\_image) | The parent container image to use in the container recipe. | `string` | n/a | yes |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Optional list of security group IDs for the infrastructure configuration | `list(string)` | `null` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Optional subnet ID for the infrastructure configuration | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "iac-management": "CGD-Toolkit",<br/>  "iac-module": "container-image-pipeline",<br/>  "iac-provider": "Terraform"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pipeline_arn"></a> [pipeline\_arn](#output\_pipeline\_arn) | ARN of the created image pipeline |
<!-- END_TF_DOCS -->
