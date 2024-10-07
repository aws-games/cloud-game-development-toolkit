<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.69.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.62.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_jenkins"></a> [jenkins](#module\_jenkins) | ../../modules/jenkins | n/a |
| <a name="module_perforce_helix_authentication_service"></a> [perforce\_helix\_authentication\_service](#module\_perforce\_helix\_authentication\_service) | ../../modules/perforce/helix-authentication-service | n/a |
| <a name="module_perforce_helix_core"></a> [perforce\_helix\_core](#module\_perforce\_helix\_core) | ../../modules/perforce/helix-core | n/a |
| <a name="module_perforce_helix_swarm"></a> [perforce\_helix\_swarm](#module\_perforce\_helix\_swarm) | ../../modules/perforce/helix-swarm | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.helix](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.jenkins](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.helix](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.jenkins](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/default_security_group) | resource |
| [aws_ecs_cluster.build_pipeline_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.providers](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_eip.nat_gateway_eip](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/eip) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/nat_gateway) | resource |
| [aws_route53_record.helix_authentication_service](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_record.helix_cert](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_record.helix_swarm](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_record.jenkins](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_record.jenkins_cert](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_record.perforce_helix_core](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_record.perforce_helix_core_pvt](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_record) | resource |
| [aws_route53_zone.helix_private_zone](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route53_zone) | resource |
| [aws_route_table.private_rt](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route_table) | resource |
| [aws_route_table.public_rt](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route_table) | resource |
| [aws_route_table_association.private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/route_table_association) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/subnet) | resource |
| [aws_vpc.build_pipeline_vpc](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc) | resource |
| [aws_vpc_security_group_ingress_rule.helix_auth_access](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_auth_inbound_core](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_core_access](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_core_inbound_build_farm](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_core_inbound_swarm](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_swarm_access](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.helix_swarm_inbound_core](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_access](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/5.69.0/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_root_domain_name"></a> [root\_domain\_name](#input\_root\_domain\_name) | The fully qualified domain name of your existing Route53 Hosted Zone. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
