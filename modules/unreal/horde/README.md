# Unreal Horde

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.59.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.54.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.unreal_horde_log_group](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.unreal_horde_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.unreal_horde](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.unreal_horde_task_definition](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.unreal_horde_default_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.unreal_horde_secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.unreal_horde_default_role](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_role) | resource |
| [aws_iam_role.unreal_horde_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_role) | resource |
| [aws_lb.unreal_horde_alb](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/lb) | resource |
| [aws_lb_listener.unreal_horde_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.unreal_horde_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.unreal_horde_alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.alb_access_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.unreal_horde_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/security_group) | resource |
| [aws_security_group.unreal_horde_sg](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_alb_outbound_service](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_inbound_alb](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.unreal_horde](https://registry.terraform.io/providers/hashicorp/random/3.6.2/docs/resources/string) | resource |
| [random_string.unreal_horde_alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/3.6.2/docs/resources/string) | resource |
| [aws_ecs_cluster.unreal_horde_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/ecs_cluster) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.access_logs_bucket_alb_write](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_tasks_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.unreal_horde_default_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.unreal_horde_secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The TLS certificate ARN for the Unreal Horde load balancer. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster to deploy the Unreal Horde into. Defaults to null and a cluster will be created. | `string` | `null` | no |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | The CPU allotment for the Unreal Horde container. | `number` | `1024` | no |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | The memory allotment for the Unreal Horde container. | `number` | `4096` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the Unreal Horde container. | `string` | `"unreal-horde-container"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The container port that Unreal Horde runs on. | `number` | `5000` | no |
| <a name="input_create_unreal_horde_default_policy"></a> [create\_unreal\_horde\_default\_policy](#input\_create\_unreal\_horde\_default\_policy) | Optional creation of Unreal Horde default IAM Policy. Default is set to true. | `bool` | `true` | no |
| <a name="input_create_unreal_horde_default_role"></a> [create\_unreal\_horde\_default\_role](#input\_create\_unreal\_horde\_default\_role) | Optional creation of Unreal Horde default IAM Role. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_unreal_horde_role"></a> [custom\_unreal\_horde\_role](#input\_custom\_unreal\_horde\_role) | ARN of the custom IAM Role you wish to use with Unreal Horde. | `string` | `null` | no |
| <a name="input_desired_container_count"></a> [desired\_container\_count](#input\_desired\_container\_count) | The desired number of containers running Unreal Horde. | `number` | `1` | no |
| <a name="input_enable_unreal_horde_alb_access_logs"></a> [enable\_unreal\_horde\_alb\_access\_logs](#input\_enable\_unreal\_horde\_alb\_access\_logs) | Enables access logging for the Unreal Horde ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_enable_unreal_horde_alb_deletion_protection"></a> [enable\_unreal\_horde\_alb\_deletion\_protection](#input\_enable\_unreal\_horde\_alb\_deletion\_protection) | Enables deletion protection for the Unreal Horde ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Unreal Horde load balancer. | `list(string)` | `[]` | no |
| <a name="input_github_credentials_secret_arn"></a> [github\_credentials\_secret\_arn](#input\_github\_credentials\_secret\_arn) | A secret containing the Github username and password with permissions to the EpicGames organization. | `string` | n/a | yes |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the Unreal Horde load balancer to have a public IP. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to Unreal Engine Horde module resources. | `string` | `"unreal-horde"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "unreal-horde",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_unreal_horde_alb_access_logs_bucket"></a> [unreal\_horde\_alb\_access\_logs\_bucket](#input\_unreal\_horde\_alb\_access\_logs\_bucket) | ID of the S3 bucket for Unreal Horde ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_unreal_horde_alb_access_logs_prefix"></a> [unreal\_horde\_alb\_access\_logs\_prefix](#input\_unreal\_horde\_alb\_access\_logs\_prefix) | Log prefix for Unreal Horde ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_unreal_horde_alb_subnets"></a> [unreal\_horde\_alb\_subnets](#input\_unreal\_horde\_alb\_subnets) | A list of subnets to deploy the Unreal Horde load balancer into. Public subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_unreal_horde_cloudwatch_log_retention_in_days"></a> [unreal\_horde\_cloudwatch\_log\_retention\_in\_days](#input\_unreal\_horde\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the cloudwatch log group for Unreal Horde. | `string` | `365` | no |
| <a name="input_unreal_horde_subnets"></a> [unreal\_horde\_subnets](#input\_unreal\_horde\_subnets) | A list of subnets to deploy the Unreal Horde into. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy Unreal Horde into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | n/a |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | n/a |
<!-- END_TF_DOCS -->
