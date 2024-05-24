# Perforce Helix Swarm

### Overview

[Perforce Helix Swarm](https://www.perforce.com/products/helix-swarm) is a free code review tool for projects hosted in [Perforce Helix Core](https://www.perforce.com/products/helix-core).

### Prerequisites

This module depends on the presence of a Perforce Helix Swarm AMI in your AWS account. There is a [Packer](https://www.packer.io/) template available at [`/assets/perforce/helix-swarm`](/assets/perforce/swarm/) that you can use to create this AMI yourself. *Note: make sure to deploy the AMI into the same region you plan to deploy this module.*

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.30 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.30 |
| <a name="provider_random"></a> [random](#provider\_random) | >=3.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.helix_swarm_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.helix_swarm_default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_instance.helix_swarm_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_lb.swarm_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.swarm_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.swarm_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.swarm_alb_target_group_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_s3_bucket.swarm_alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_security_group.swarm_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.swarm_instance_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.helix_swarm_alb_outbound_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.helix_swarm_outbound_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_swarm_inbound_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.helix_swarm](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.swarm_alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ami.helix_swarm_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.ec2_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_subnet.instance_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | Certificate ARN for Helix Swarm load balancer. | `string` | n/a | yes |
| <a name="input_create_swarm_default_role"></a> [create\_swarm\_default\_role](#input\_create\_swarm\_default\_role) | Optional creation of Helix Swarm default IAM Role with SSM managed instance core policy attached. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_swarm_role"></a> [custom\_swarm\_role](#input\_custom\_swarm\_role) | ARN of the custom IAM Role you wish to use with Helix Swarm. | `string` | `null` | no |
| <a name="input_enable_swarm_alb_access_logs"></a> [enable\_swarm\_alb\_access\_logs](#input\_enable\_swarm\_alb\_access\_logs) | Enables access logging got the Helix Swarm ALB. Defaults to false. | `bool` | `false` | no |
| <a name="input_enable_swarm_alb_deletion_protection"></a> [enable\_swarm\_alb\_deletion\_protection](#input\_enable\_swarm\_alb\_deletion\_protection) | Enables deletion protection for the Helix Swarm ALB. Defaults to false. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) Defaults to dev. | `string` | `"dev"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Helix Swarm load balancer. | `list(string)` | `[]` | no |
| <a name="input_instance_subnet_id"></a> [instance\_subnet\_id](#input\_instance\_subnet\_id) | The subnet where the Helix Swarm instance will be deployed. | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The instance type for Perforce Helix Swarm. Defaults to t3.small. | `string` | `"t3.small"` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the Helix Swarm load balancer to have a public IP. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to swarm module resources. | `string` | `"swarm"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_swarm_alb_access_logs_bucket"></a> [swarm\_alb\_access\_logs\_bucket](#input\_swarm\_alb\_access\_logs\_bucket) | ID of the S3 bucket for swarm ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_swarm_alb_access_logs_prefix"></a> [swarm\_alb\_access\_logs\_prefix](#input\_swarm\_alb\_access\_logs\_prefix) | Log prefix for Helix Swarm ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_swarm_alb_subnets"></a> [swarm\_alb\_subnets](#input\_swarm\_alb\_subnets) | The subnets where the ALB for Perforce Helix Swarm will be deployed. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "swarm",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy Helix Swarm into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | n/a |
| <a name="output_swarm_alb_dns_name"></a> [swarm\_alb\_dns\_name](#output\_swarm\_alb\_dns\_name) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->