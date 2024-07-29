# Perforce Helix Swarm

### Overview

[Perforce Helix Swarm](https://www.perforce.com/products/helix-swarm) is a free code review tool for projects hosted in [Perforce Helix Core](https://www.perforce.com/products/helix-core).

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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.59.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.swarm_redis_service_log_group](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.swarm_service_log_group](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.swarm_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.swarm_cluster_fargate_providers](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.swarm_service](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.swarm_task_definition](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/ecs_task_definition) | resource |
| [aws_efs_access_point.redis_efs_access_point](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/efs_access_point) | resource |
| [aws_efs_access_point.swarm_efs_access_point](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.swarm_efs_file_system](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.swarm_efs_mount_target](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/efs_mount_target) | resource |
| [aws_iam_policy.swarm_default_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.swarm_efs_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.swarm_ssm_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.swarm_default_role](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_role) | resource |
| [aws_iam_role.swarm_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/iam_role) | resource |
| [aws_lb.swarm_alb](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/lb) | resource |
| [aws_lb_listener.swarm_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.swarm_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.swarm_alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.swarm_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/security_group) | resource |
| [aws_security_group.swarm_efs_security_group](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/security_group) | resource |
| [aws_security_group.swarm_service_sg](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.swarm_alb_outbound_service](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.swarm_service_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.swarm_service_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.swarm_efs_inbound_service](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.swarm_service_inbound_alb](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.swarm](https://registry.terraform.io/providers/hashicorp/random/3.6.2/docs/resources/string) | resource |
| [random_string.swarm_alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/3.6.2/docs/resources/string) | resource |
| [aws_ecs_cluster.swarm_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.ecs_tasks_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.swarm_default_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.swarm_efs_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.swarm_ssm_policy](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/5.59.0/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The TLS certificate ARN for the Helix Swarm service load balancer. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster to deploy the Helix Swarm service into. Defaults to null and a cluster will be created. | `string` | `null` | no |
| <a name="input_create_swarm_default_policy"></a> [create\_swarm\_default\_policy](#input\_create\_swarm\_default\_policy) | Optional creation of Helix Swarm default IAM Policy. Default is set to true. | `bool` | `true` | no |
| <a name="input_create_swarm_default_role"></a> [create\_swarm\_default\_role](#input\_create\_swarm\_default\_role) | Optional creation of Helix Swarm Default IAM Role. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_swarm_role"></a> [custom\_swarm\_role](#input\_custom\_swarm\_role) | ARN of the custom IAM Role you wish to use with Helix Swarm. | `string` | `null` | no |
| <a name="input_enable_elastic_filesystem"></a> [enable\_elastic\_filesystem](#input\_enable\_elastic\_filesystem) | Flag to enable/disable elastic filesystem for persistent storage. Defaults to false. | `bool` | `false` | no |
| <a name="input_enable_swarm_alb_access_logs"></a> [enable\_swarm\_alb\_access\_logs](#input\_enable\_swarm\_alb\_access\_logs) | Enables access logging for the Helix Swarm ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_enable_swarm_alb_deletion_protection"></a> [enable\_swarm\_alb\_deletion\_protection](#input\_enable\_swarm\_alb\_deletion\_protection) | Enables deletion protection for the Helix Swarm ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_redis_host"></a> [existing\_redis\_host](#input\_existing\_redis\_host) | The hostname where the Redis cache that Swarm should use is running. | `string` | `null` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Helix Swarm service load balancer. | `list(string)` | `[]` | no |
| <a name="input_fqdn"></a> [fqdn](#input\_fqdn) | The fully qualified domain name that Swarm should use for internal URLs. | `string` | `null` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the Helix Swarm service load balancer to have a public IP. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to swarm module resources. | `string` | `"swarm"` | no |
| <a name="input_p4d_port"></a> [p4d\_port](#input\_p4d\_port) | The P4D\_PORT environment variable where Swarm should look for Helix Core. Defaults to 'ssl:perforce:1666' | `string` | `"ssl:perforce:1666"` | no |
| <a name="input_p4d_super_user_arn"></a> [p4d\_super\_user\_arn](#input\_p4d\_super\_user\_arn) | The ARN of the parameter or secret where the p4d super user username is stored. | `string` | n/a | yes |
| <a name="input_p4d_super_user_password_arn"></a> [p4d\_super\_user\_password\_arn](#input\_p4d\_super\_user\_password\_arn) | The ARN of the parameter or secret where the p4d super user password is stored. | `string` | n/a | yes |
| <a name="input_p4d_swarm_password_arn"></a> [p4d\_swarm\_password\_arn](#input\_p4d\_swarm\_password\_arn) | The ARN of the parameter or secret where the swarm user password is stored. | `string` | n/a | yes |
| <a name="input_p4d_swarm_user_arn"></a> [p4d\_swarm\_user\_arn](#input\_p4d\_swarm\_user\_arn) | The ARN of the parameter or secret where the swarm user username is stored. | `string` | n/a | yes |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_redis_container_cpu"></a> [redis\_container\_cpu](#input\_redis\_container\_cpu) | CPU allotment for Helix Swarm Redis container. | `number` | `1024` | no |
| <a name="input_redis_container_memory"></a> [redis\_container\_memory](#input\_redis\_container\_memory) | Memory allotment for Helix Swarm Redis container. | `number` | `2048` | no |
| <a name="input_redis_container_name"></a> [redis\_container\_name](#input\_redis\_container\_name) | The name of the Redis container. | `string` | `"swarm-redis"` | no |
| <a name="input_redis_container_port"></a> [redis\_container\_port](#input\_redis\_container\_port) | The port where the Redis cache that Swarm should use is running. | `number` | `6379` | no |
| <a name="input_redis_image"></a> [redis\_image](#input\_redis\_image) | The Redis image and version that Helix Swarm should use. | `string` | `"redis"` | no |
| <a name="input_swarm_alb_access_logs_bucket"></a> [swarm\_alb\_access\_logs\_bucket](#input\_swarm\_alb\_access\_logs\_bucket) | ID of the S3 bucket for Helix Swarm ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_swarm_alb_access_logs_prefix"></a> [swarm\_alb\_access\_logs\_prefix](#input\_swarm\_alb\_access\_logs\_prefix) | Log prefix for Helix Swarm ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_swarm_alb_subnets"></a> [swarm\_alb\_subnets](#input\_swarm\_alb\_subnets) | A list of subnets to deploy the Helix Swarm load balancer into. Public subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_swarm_cloudwatch_log_retention_in_days"></a> [swarm\_cloudwatch\_log\_retention\_in\_days](#input\_swarm\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the cloudwatch log group for Helix Swarm. | `string` | `365` | no |
| <a name="input_swarm_container_cpu"></a> [swarm\_container\_cpu](#input\_swarm\_container\_cpu) | The CPU allotment for the swarm container. | `number` | `1024` | no |
| <a name="input_swarm_container_memory"></a> [swarm\_container\_memory](#input\_swarm\_container\_memory) | The memory allotment for the swarm container. | `number` | `2048` | no |
| <a name="input_swarm_container_name"></a> [swarm\_container\_name](#input\_swarm\_container\_name) | The name of the swarm container. | `string` | `"helix-swarm-container"` | no |
| <a name="input_swarm_container_port"></a> [swarm\_container\_port](#input\_swarm\_container\_port) | The container port that swarm runs on. | `number` | `80` | no |
| <a name="input_swarm_desired_container_count"></a> [swarm\_desired\_container\_count](#input\_swarm\_desired\_container\_count) | The desired number of containers running the Helix Swarm service. | `number` | `1` | no |
| <a name="input_swarm_efs_performance_mode"></a> [swarm\_efs\_performance\_mode](#input\_swarm\_efs\_performance\_mode) | The performance mode of the EFS file system used by the Helix Swarm service. Defaults to general purpose. | `string` | `"generalPurpose"` | no |
| <a name="input_swarm_efs_throughput_mode"></a> [swarm\_efs\_throughput\_mode](#input\_swarm\_efs\_throughput\_mode) | The throughput mode of the EFS file system used by the Helix Swarm service. Defaults to bursting. | `string` | `"bursting"` | no |
| <a name="input_swarm_service_subnets"></a> [swarm\_service\_subnets](#input\_swarm\_service\_subnets) | A list of subnets to deploy the Helix Swarm service into. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "swarm",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | The CPU allotment for the Helix Swarm task. | `number` | `2048` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | The memory allotment for the Helix Swarm task. | `number` | `4096` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy swarm into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | The DNS name of the Swarm ALB |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group associated with the swarm load balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | The hosted zone ID of the Swarm ALB |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster hosting Swarm |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | Security group associated with the ECS service running swarm |
<!-- END_TF_DOCS -->
