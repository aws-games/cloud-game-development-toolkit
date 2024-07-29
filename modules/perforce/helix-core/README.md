# Perforce Helix Core

[Perforce Helix Core](https://www.perforce.com/products/helix-core/aws) is a scalable version control system that helps teams manage code alongside large, digital assets and collaborate more effectively in one central, secure location. With AWS, teams can quickly deploy Helix Core and accelerate innovation.

This module deploys Perforce Helix Core on AWS using an Amazon Machine Image (AMI) that is included in the Cloud Game Development Toolkit. You can provision this AMI using [Hashicorp Packer](https://www.packer.io/). To get started, navigate to `/assets/packer/perforce/helix-core` and consult the documentation.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.50 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.59.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ebs_volume.depot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_ebs_volume.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_ebs_volume.metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_eip.helix_core_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_instance_profile.helix_core_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.helix_core_default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.helix_core_default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_instance.helix_core_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.helix_core_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_volume_attachment.depot_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [aws_volume_attachment.logs_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [aws_volume_attachment.metadata_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [aws_vpc_security_group_egress_rule.helix_core_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [awscc_secretsmanager_secret.helix_core_super_user_password](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [awscc_secretsmanager_secret.helix_core_super_user_username](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [random_string.helix_core](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ami.helix_core_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.ec2_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.helix_core_default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_subnet.instance_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_FQDN"></a> [FQDN](#input\_FQDN) | The FQDN that should be used to generate the self-signed SSL cert on the Helix Core instance. | `string` | `null` | no |
| <a name="input_create_default_sg"></a> [create\_default\_sg](#input\_create\_default\_sg) | Whether to create a default security group for the Helix Core instance. | `bool` | `true` | no |
| <a name="input_create_helix_core_default_role"></a> [create\_helix\_core\_default\_role](#input\_create\_helix\_core\_default\_role) | Optional creation of Helix Core default IAM Role with SSM managed instance core policy attached. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_helix_core_role"></a> [custom\_helix\_core\_role](#input\_custom\_helix\_core\_role) | ARN of the custom IAM Role you wish to use with Helix Core. | `string` | `null` | no |
| <a name="input_depot_volume_size"></a> [depot\_volume\_size](#input\_depot\_volume\_size) | The size of the depot volume in GiB. Defaults to 128 GiB. | `number` | `128` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Helix Core load balancer. | `list(string)` | `[]` | no |
| <a name="input_helix_authentication_service_url"></a> [helix\_authentication\_service\_url](#input\_helix\_authentication\_service\_url) | The URL for the Helix Authentication Service. | `string` | `null` | no |
| <a name="input_helix_core_super_user_password_secret_arn"></a> [helix\_core\_super\_user\_password\_secret\_arn](#input\_helix\_core\_super\_user\_password\_secret\_arn) | If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's password here. | `string` | `null` | no |
| <a name="input_helix_core_super_user_username_secret_arn"></a> [helix\_core\_super\_user\_username\_secret\_arn](#input\_helix\_core\_super\_user\_username\_secret\_arn) | If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's username here. Otherwise, the default of 'perforce' will be used. | `string` | `null` | no |
| <a name="input_instance_subnet_id"></a> [instance\_subnet\_id](#input\_instance\_subnet\_id) | The subnet where the Helix Core instance will be deployed. | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The instance type for Perforce Helix Core. Defaults to c6in.large. | `string` | `"c6in.large"` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the Helix Core instance to have a public IP. | `bool` | `false` | no |
| <a name="input_logs_volume_size"></a> [logs\_volume\_size](#input\_logs\_volume\_size) | The size of the logs volume in GiB. Defaults to 32 GiB. | `number` | `32` | no |
| <a name="input_metadata_volume_size"></a> [metadata\_volume\_size](#input\_metadata\_volume\_size) | The size of the metadata volume in GiB. Defaults to 32 GiB. | `number` | `32` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to swarm module resources. | `string` | `"helix-core"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_server_type"></a> [server\_type](#input\_server\_type) | The Perforce Helix Core server type. | `string` | n/a | yes |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | The type of backing store [EBS, FSxZ] | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "helix-core",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC where Helix Core should be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helix_core_eip_id"></a> [helix\_core\_eip\_id](#output\_helix\_core\_eip\_id) | The ID of the Elastic IP associated with your Helix Core instance. |
| <a name="output_helix_core_eip_private_ip"></a> [helix\_core\_eip\_private\_ip](#output\_helix\_core\_eip\_private\_ip) | The private IP of your Helix Core instance. |
| <a name="output_helix_core_eip_public_ip"></a> [helix\_core\_eip\_public\_ip](#output\_helix\_core\_eip\_public\_ip) | The public IP of your Helix Core instance. |
| <a name="output_helix_core_super_user_password_secret_arn"></a> [helix\_core\_super\_user\_password\_secret\_arn](#output\_helix\_core\_super\_user\_password\_secret\_arn) | The ARN of the AWS Secrets Manager secret holding your Helix Core super user's password. |
| <a name="output_helix_core_super_user_username_secret_arn"></a> [helix\_core\_super\_user\_username\_secret\_arn](#output\_helix\_core\_super\_user\_username\_secret\_arn) | The ARN of the AWS Secrets Manager secret holding your Helix Core super user's username. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The default security group of your Helix Core instance. |
<!-- END_TF_DOCS -->
