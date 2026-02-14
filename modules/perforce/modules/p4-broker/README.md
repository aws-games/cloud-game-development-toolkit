# P4 Broker (Perforce Helix Broker)

This module deploys a Perforce Helix Broker (`p4broker`) as an ECS Fargate service. P4 Broker is a TCP-level proxy/filter that sits between Perforce clients and the Perforce server. It uses a broker configuration file to define routing rules, command filtering, and redirection.

## Architecture

P4 Broker operates at the Perforce protocol level and requires a TCP listener on the shared Network Load Balancer (NLB). Unlike P4 Auth and P4 Code Review (which are HTTP services behind the shared ALB), P4 Broker handles raw TCP Perforce protocol traffic.

```text
Client --> NLB (TCP:1666) --> P4 Broker (ECS) --> P4 Server (EC2)
```

## Usage

```hcl
module "p4_broker" {
  source = "./modules/p4-broker"

  # General
  name           = "p4-broker"
  project_prefix = "cgd"

  # Compute
  cluster_name    = "my-ecs-cluster"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/p4-broker:latest"

  # Broker Configuration
  p4_target = "ssl:p4server:1666"
  broker_command_rules = [
    {
      command = "*"
      action  = "pass"
    }
  ]

  # Networking
  vpc_id  = "vpc-12345678"
  subnets = ["subnet-111", "subnet-222"]
}
```

## Broker Configuration

The broker configuration file (`p4broker.conf`) is generated from Terraform variables and uploaded to S3. An init container downloads the configuration before the broker starts.

### Command Rules

Command rules control how `p4broker` handles client commands:

```hcl
broker_command_rules = [
  {
    command = "obliterate"
    action  = "reject"
    message = "Obliterate is not permitted through the broker."
  },
  {
    command = "*"
    action  = "pass"
  }
]
```

## Container Image

A Dockerfile for building the P4 Broker image is provided in `assets/docker/perforce/p4-broker/`. The module accepts any container image URI via the `container_image` variable.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 6.6 |
| random | ~> 3.7 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.6 |
| random | ~> 3.7 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.cluster_fargate_providers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_config_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_lb_target_group.nlb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_object.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| container\_image | The Docker image URI for the P4 Broker container. | `string` | n/a | yes |
| p4\_target | The upstream Perforce server target (e.g., ssl:p4server:1666). | `string` | n/a | yes |
| subnets | A list of subnets to deploy the P4 Broker ECS Service into. | `list(string)` | n/a | yes |
| vpc\_id | The ID of the existing VPC you would like to deploy P4 Broker into. | `string` | n/a | yes |
| broker\_command\_rules | Command filtering rules for the P4 Broker configuration. | `list(object)` | `[{command="*", action="pass"}]` | no |
| cloudwatch\_log\_retention\_in\_days | The log retention in days of the CloudWatch log group. | `number` | `365` | no |
| cluster\_name | The name of the ECS cluster to deploy into. | `string` | `null` | no |
| container\_cpu | The CPU allotment for the P4 Broker container. | `number` | `1024` | no |
| container\_memory | The memory allotment for the P4 Broker container. | `number` | `2048` | no |
| container\_name | The name of the P4 Broker container. | `string` | `"p4-broker-container"` | no |
| container\_port | The container port that P4 Broker listens on. | `number` | `1666` | no |
| create\_default\_role | Optional creation of P4 Broker default IAM Role. | `bool` | `true` | no |
| custom\_role | ARN of the custom IAM Role you wish to use with P4 Broker. | `string` | `null` | no |
| debug | Set this flag to enable execute command on service containers. | `bool` | `false` | no |
| desired\_count | The desired number of P4 Broker ECS tasks. | `number` | `1` | no |
| extra\_env | Extra environment variables to set on the P4 Broker container. | `map(string)` | `null` | no |
| name | The name attached to P4 Broker module resources. | `string` | `"p4-broker"` | no |
| project\_prefix | The project prefix for this workload. | `string` | `"cgd"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_name | Name of the ECS cluster hosting P4 Broker |
| config\_bucket\_name | The name of the S3 bucket containing the broker configuration |
| service\_arn | The ARN of the P4 Broker ECS service |
| service\_security\_group\_id | Security group associated with the ECS service running P4 Broker |
| target\_group\_arn | The NLB target group ARN for P4 Broker |
| task\_definition\_arn | The ARN of the P4 Broker task definition |
<!-- END_TF_DOCS -->

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.6 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.6 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.7 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.cluster_fargate_providers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.s3_config_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution_role_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution_role_s3_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_target_group.nlb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.broker_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.ecs_service_outbound_to_internet_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_service_outbound_to_internet_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [random_string.broker_config](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.p4_broker](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ecs_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_tasks_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_config_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | The Docker image URI for the P4 Broker container. | `string` | n/a | yes |
| <a name="input_p4_target"></a> [p4\_target](#input\_p4\_target) | The upstream Perforce server target (e.g., ssl:p4server:1666). | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of subnets to deploy the P4 Broker ECS Service into. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy P4 Broker into. | `string` | n/a | yes |
| <a name="input_broker_command_rules"></a> [broker\_command\_rules](#input\_broker\_command\_rules) | Command filtering rules for the P4 Broker configuration. | <pre>list(object({<br>    command = string<br>    action  = string<br>    message = optional(string, null)<br>  }))</pre> | <pre>[<br>  {<br>    "action": "pass",<br>    "command": "*",<br>    "message": null<br>  }<br>]</pre> | no |
| <a name="input_cloudwatch_log_retention_in_days"></a> [cloudwatch\_log\_retention\_in\_days](#input\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the CloudWatch log group for P4 Broker. | `number` | `365` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the ECS cluster to deploy the P4 Broker into. Cluster is not created if this variable is provided. | `string` | `null` | no |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | The CPU allotment for the P4 Broker container. | `number` | `1024` | no |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | The memory allotment for the P4 Broker container. | `number` | `2048` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the P4 Broker container. | `string` | `"p4-broker-container"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The container port that P4 Broker listens on. | `number` | `1666` | no |
| <a name="input_create_default_role"></a> [create\_default\_role](#input\_create\_default\_role) | Optional creation of P4 Broker default IAM Role. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_role"></a> [custom\_role](#input\_custom\_role) | ARN of the custom IAM Role you wish to use with P4 Broker. | `string` | `null` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | Set this flag to enable execute command on service containers and force redeploys. | `bool` | `false` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | The desired number of P4 Broker ECS tasks. | `number` | `1` | no |
| <a name="input_extra_env"></a> [extra\_env](#input\_extra\_env) | Extra environment variables to set on the P4 Broker container. | `map(string)` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to P4 Broker module resources. | `string` | `"p4-broker"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IaC": "Terraform",<br>  "ModuleBy": "CGD-Toolkit",<br>  "ModuleName": "p4-broker",<br>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce",<br>  "RootModuleName": "terraform-aws-perforce"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster hosting P4 Broker |
| <a name="output_config_bucket_name"></a> [config\_bucket\_name](#output\_config\_bucket\_name) | The name of the S3 bucket containing the broker configuration |
| <a name="output_service_arn"></a> [service\_arn](#output\_service\_arn) | The ARN of the P4 Broker ECS service |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | Security group associated with the ECS service running P4 Broker |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | The NLB target group ARN for P4 Broker |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | The ARN of the P4 Broker task definition |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
