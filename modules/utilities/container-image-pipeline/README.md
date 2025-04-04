<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.87.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.87.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/5.87.0/docs/resources/ecr_repository) | resource |
| [aws_imagebuilder_component.base_component](https://registry.terraform.io/providers/hashicorp/aws/5.87.0/docs/resources/imagebuilder_component) | resource |
| [aws_imagebuilder_container_recipe.container_recipe](https://registry.terraform.io/providers/hashicorp/aws/5.87.0/docs/resources/imagebuilder_container_recipe) | resource |
| [aws_imagebuilder_image_pipeline.container_image_pipeline](https://registry.terraform.io/providers/hashicorp/aws/5.87.0/docs/resources/imagebuilder_image_pipeline) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | The container image to use. | `string` | n/a | yes |
| <a name="input_container_recipe_arn"></a> [container\_recipe\_arn](#input\_container\_recipe\_arn) | The ARN of the container recipe to use. | `string` | n/a | yes |
| <a name="input_ecr_kms_key_id"></a> [ecr\_kms\_key\_id](#input\_ecr\_kms\_key\_id) | KMS key ARN/ID to encrypt the ECR repository. Replace with your own KMS key ARN/ID if needed. | `string` | `"alias/aws/ecr"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. Development, Staging, Production, etc.). This will tag ressources and set ASPNETCORE\_ENVIRONMENT variable. | `string` | `"Development"` | no |
| <a name="input_imagebuilder_component_kms_key_id"></a> [imagebuilder\_component\_kms\_key\_id](#input\_imagebuilder\_component\_kms\_key\_id) | Optional KMS key ARN/ID to encrypt the EC2 Image Builder component. Replace with your own KMS key ARN/ID if needed. | `string` | `"alias/aws/imagebuilder"` | no |
| <a name="input_infrastructure_configuration_arn"></a> [infrastructure\_configuration\_arn](#input\_infrastructure\_configuration\_arn) | ARN of the container image pipeline infrastructure configuration | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | (Required) The name prepended to resources created by the module. | `string` | n/a | yes |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "iac-management": "CGD-Toolkit",<br/>  "iac-module": "container-image-pipeline",<br/>  "iac-provider": "Terraform"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pipeline_arn"></a> [pipeline\_arn](#output\_pipeline\_arn) | ARN of the created image pipeline |
<!-- END_TF_DOCS -->
