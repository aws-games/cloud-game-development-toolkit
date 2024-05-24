# Perforce Module

### Overview

This module deploys Perforce Helix Core and Perforce Helix Swarm. Helix Authentication Service integration is a planned feature.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.30 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.30 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_helix_core"></a> [helix\_core](#module\_helix\_core) | ./helix-core | n/a |
| <a name="module_helix_swarm"></a> [helix\_swarm](#module\_helix\_swarm) | ./helix-swarm | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.helix_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.helix_core_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_core_inbound_swarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_core_self_p4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.). Defaults to dev. | `string` | `"dev"` | no |
| <a name="input_helix_core_servers"></a> [helix\_core\_servers](#input\_helix\_core\_servers) | n/a | <pre>map(object({<br>    server_type              = string // "commit" "edge" "standby"<br>    instance_type            = optional(string, "c6in.large")<br>    instance_subnet_id       = string<br>    existing_security_groups = optional(list(string), null)<br>    internal                 = optional(bool, false)<br>    storage = object({<br>      type                 = optional(string, "EBS")<br>      depot_volume_size    = optional(number, 64) // size of the depot volume in GiB<br>      metadata_volume_size = optional(number, 32) // size of the metadata volume in GiB<br>      logs_volume_size     = optional(number, 32) // size of the logs volume in GiB<br>    })<br>    custom_helix_core_role         = optional(string, null)<br>    create_helix_core_default_role = optional(bool, true)<br>  }))</pre> | `{}` | no |
| <a name="input_helix_swarm"></a> [helix\_swarm](#input\_helix\_swarm) | Helix Swarm deployment settings. | <pre>object({<br>    alb_subnet_ids                       = list(string)<br>    instance_subnet_id                   = string<br>    instance_type                        = optional(string, null)<br>    existing_security_groups             = optional(list(string), null)<br>    internal                             = optional(bool, false)<br>    certificate_arn                      = string<br>    enable_swarm_alb_access_logs         = optional(bool, false)<br>    swarm_alb_access_logs_bucket         = optional(string, null)<br>    swarm_alb_access_logs_prefix         = optional(string, null)<br>    enable_swarm_alb_deletion_protection = optional(bool, false)<br>    custom_swarm_role                    = optional(string, null)<br>    create_swarm_default_role            = optional(bool, true)<br>  })</pre> | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "Perforce",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC to deploy this Perforce module into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helix_core_sg"></a> [helix\_core\_sg](#output\_helix\_core\_sg) | n/a |
| <a name="output_helix_swarm_sg"></a> [helix\_swarm\_sg](#output\_helix\_swarm\_sg) | n/a |
| <a name="output_helix_swarm_url"></a> [helix\_swarm\_url](#output\_helix\_swarm\_url) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->