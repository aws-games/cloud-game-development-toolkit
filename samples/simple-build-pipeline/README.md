<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.97.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.5.0 |
| <a name="requirement_netapp-ontap"></a> [netapp-ontap](#requirement\_netapp-ontap) | 2.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.97.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_jenkins"></a> [jenkins](#module\_jenkins) | ../../modules/jenkins | n/a |
| <a name="module_terraform-aws-perforce"></a> [terraform-aws-perforce](#module\_terraform-aws-perforce) | ../../modules/perforce | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.shared](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.shared_certificate](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/default_security_group) | resource |
| [aws_ecs_cluster.build_pipeline_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.providers](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_eip.nat_gateway_eip](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/eip) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/internet_gateway) | resource |
| [aws_lb.service_nlb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb) | resource |
| [aws_lb.web_alb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb) | resource |
| [aws_lb_listener.internal_https](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener.public_https](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.jenkins](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.perforce_auth](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.perforce_code_review](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.alb_target](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.alb_attachment](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/lb_target_group_attachment) | resource |
| [aws_nat_gateway.nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/nat_gateway) | resource |
| [aws_route.private_rt_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route) | resource |
| [aws_route53_record.jenkins_private](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_record.jenkins_public](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_server_private](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_server_public](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_web_services_private](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_web_services_public](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_record.shared_certificate](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_record) | resource |
| [aws_route53_zone.private_zone](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route53_zone) | resource |
| [aws_route_table.private_rt](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route_table) | resource |
| [aws_route_table.public_rt](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route_table) | resource |
| [aws_route_table_association.private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/route_table_association) | resource |
| [aws_security_group.allow_my_ip](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/security_group) | resource |
| [aws_security_group.internal_shared_application_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/security_group) | resource |
| [aws_security_group.public_network_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/security_group) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/subnet) | resource |
| [aws_vpc.build_pipeline_vpc](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc) | resource |
| [aws_vpc_security_group_egress_rule.internal_alb_http_to_jenkins](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.internal_alb_http_to_p4_auth](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.internal_alb_http_to_p4_code_review](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.public_nlb_https_to_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_perforce](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.internal_alb_https_from_p4_server](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.internal_alb_https_from_public_nlb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_http_from_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_auth_http_from_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_code_review_http_from_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_server_from_jenkins_build_farm](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_server_from_jenkins_service](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.ubuntu_noble_amd](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/5.97.0/docs/data-sources/route53_zone) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/3.5.0/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The fully qualified domain name of your existing Route53 Hosted Zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_jenkins_url"></a> [jenkins\_url](#output\_jenkins\_url) | The URL for the Jenkins service. |
| <a name="output_p4_auth_admin_url"></a> [p4\_auth\_admin\_url](#output\_p4\_auth\_admin\_url) | The URL for the P4Auth service admin page. |
| <a name="output_p4_code_review_url"></a> [p4\_code\_review\_url](#output\_p4\_code\_review\_url) | The URL for the P4 Code Review service. |
| <a name="output_p4_server_connection_string"></a> [p4\_server\_connection\_string](#output\_p4\_server\_connection\_string) | The connection string for the P4 Server. Set your P4PORT environment variable to this value. |
<!-- END_TF_DOCS -->
