# Perforce Helix Authentication Service (HAS)

[Perforce Helix Authentication Service](https://www.perforce.com/downloads/helix-authentication-service) enables you to integrate certain Perforce products with your organization's Identity Provider (IdP).

This module deploys Perforce Helix Authentication Service on AWS as a fully managed ECS Service using Fargate.

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
| [aws_cloudwatch_log_group.helix_authentication_service_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.helix_authentication_service_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.helix_authentication_service_cluster_fargate_providers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.helix_authentication_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.helix_authentication_service_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.helix_authentication_service_default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.helix_authentication_service_secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.helix_authentication_service_default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.helix_authentication_service_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_lb.helix_authentication_service_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.helix_authentication_service_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.helix_authentication_service_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.helix_authentication_service_alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.helix_authentication_service_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.helix_authentication_service_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.helix_authentication_service_alb_outbound_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.helix_authentication_service_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.helix_authentication_service_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_authentication_service_inbound_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [awscc_secretsmanager_secret.helix_authentication_service_admin_password](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [awscc_secretsmanager_secret.helix_authentication_service_admin_username](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [random_string.helix_authentication_service](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.helix_authentication_service_alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ecs_cluster.helix_authentication_service_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.ecs_tasks_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.helix_authentication_service_default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.helix_authentication_service_secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The TLS certificate ARN for the Helix Authentication Service load balancer. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster to deploy the Helix Authentication Service into. Defaults to null and a cluster will be created. | `string` | `null` | no |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | The CPU allotment for the Helix Authentication Service container. | `number` | `1024` | no |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | The memory allotment for the Helix Authentication Service container. | `number` | `4096` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the Helix Authentication Service container. | `string` | `"helix-auth-container"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The container port that Helix Authentication Service runs on. | `number` | `3000` | no |
| <a name="input_create_helix_authentication_service_default_policy"></a> [create\_helix\_authentication\_service\_default\_policy](#input\_create\_helix\_authentication\_service\_default\_policy) | Optional creation of Helix Authentication Service default IAM Policy. Default is set to true. | `bool` | `true` | no |
| <a name="input_create_helix_authentication_service_default_role"></a> [create\_helix\_authentication\_service\_default\_role](#input\_create\_helix\_authentication\_service\_default\_role) | Optional creation of Helix Authentication Service default IAM Role. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_helix_authentication_service_role"></a> [custom\_helix\_authentication\_service\_role](#input\_custom\_helix\_authentication\_service\_role) | ARN of the custom IAM Role you wish to use with Helix Authentication Service. | `string` | `null` | no |
| <a name="input_desired_container_count"></a> [desired\_container\_count](#input\_desired\_container\_count) | The desired number of containers running the Helix Authentication Service. | `number` | `1` | no |
| <a name="input_enable_helix_authentication_service_alb_access_logs"></a> [enable\_helix\_authentication\_service\_alb\_access\_logs](#input\_enable\_helix\_authentication\_service\_alb\_access\_logs) | Enables access logging for the Helix Authentication Service ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_enable_helix_authentication_service_alb_deletion_protection"></a> [enable\_helix\_authentication\_service\_alb\_deletion\_protection](#input\_enable\_helix\_authentication\_service\_alb\_deletion\_protection) | Enables deletion protection for the Helix Authentication Service ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_enable_web_based_administration"></a> [enable\_web\_based\_administration](#input\_enable\_web\_based\_administration) | Flag for enabling web based administration of Helix Authentication Service. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Helix Authentication Service load balancer. | `list(string)` | `[]` | no |
| <a name="input_fqdn"></a> [fqdn](#input\_fqdn) | The fully qualified domain name of Helix Authentication Service. | `string` | `"localhost"` | no |
| <a name="input_helix_authentication_service_admin_password_secret_arn"></a> [helix\_authentication\_service\_admin\_password\_secret\_arn](#input\_helix\_authentication\_service\_admin\_password\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the Helix Authentication Service Administrator password. | `string` | `null` | no |
| <a name="input_helix_authentication_service_admin_username_secret_arn"></a> [helix\_authentication\_service\_admin\_username\_secret\_arn](#input\_helix\_authentication\_service\_admin\_username\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the Helix Authentication Service Administrator username. | `string` | `null` | no |
| <a name="input_helix_authentication_service_alb_access_logs_bucket"></a> [helix\_authentication\_service\_alb\_access\_logs\_bucket](#input\_helix\_authentication\_service\_alb\_access\_logs\_bucket) | ID of the S3 bucket for Helix Authentication Service ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_helix_authentication_service_alb_access_logs_prefix"></a> [helix\_authentication\_service\_alb\_access\_logs\_prefix](#input\_helix\_authentication\_service\_alb\_access\_logs\_prefix) | Log prefix for Helix Authentication Service ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_helix_authentication_service_alb_subnets"></a> [helix\_authentication\_service\_alb\_subnets](#input\_helix\_authentication\_service\_alb\_subnets) | A list of subnets to deploy the Helix Authentication Service load balancer into. Public subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_helix_authentication_service_cloudwatch_log_retention_in_days"></a> [helix\_authentication\_service\_cloudwatch\_log\_retention\_in\_days](#input\_helix\_authentication\_service\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the cloudwatch log group for Helix Authentication Service. | `string` | `365` | no |
| <a name="input_helix_authentication_service_subnets"></a> [helix\_authentication\_service\_subnets](#input\_helix\_authentication\_service\_subnets) | A list of subnets to deploy the Helix Authentication Service into. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the Helix Authentication Service load balancer to have a public IP. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to Helix Authentication Service module resources. | `string` | `"helix-auth-svc"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "helix-authentication-service",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy Helix Authentication Service into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | The DNS name of the Helix Authentication Service ALB |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group associated with the Helix Authentication Service load balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | The hosted zone ID of the Helix Authentication Service ALB |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster hosting helix\_authentication\_service |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | Security group associated with the ECS service running Helix Authentication Service |
<!-- END_TF_DOCS -->
