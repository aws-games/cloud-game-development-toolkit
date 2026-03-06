# Create Resources Complete (with Route53)

This example deploys **[P4 Server (formerly Helix Core)](https://www.perforce.com/products/helix-core)**,
**[P4 Code Review (formerly Helix Swarm)](https://www.perforce.com/products/helix-swarm)**, and
**[the P4 Auth Service (formerly the Helix Auth Service)](https://help.perforce.com/helix-core/integrations-plugins/helix-auth-svc/current/Content/HAS/overview-of-has.html)**
using Amazon Route53 as the DNS provider.

## Architecture

![perforce-complete-arch](../../assets/media/diagrams/perforce-arch-cdg-toolkit-terraform-aws-perforce-full-arch-route53-dns.png)

## Important

This example creates DNS records in an existing Rout53 Public Hosted Zone and as well as an ACM Certificate. This
certificate needs to be validated, which is not a fixed amount of time. During a standard deployment this is a non-issue
since multiple dependent resources take longer to deploy than the certificate takes to validate. However, if you change
the name of your domain where referenced in the ACM certificate ***after*** the initial apply, you may encounter the
following error:

```hcl
│ Error : modifying ELBv2 Listener (arn : aws :elasticloadbalancing : us-east-1 : xx : listener/app/cgd-perforce-shared-alb/xx) : operation error Elastic Load Balancing v2 : ModifyListener, https response error StatusCode : 400, RequestID : xx-xx-xx-xx-xx, api error UnsupportedCertificate : The certificate 'arn:aws:acm:us-east-1:x:certificate/xx-xx-xx-xx-xx' must have a fully-qualified domain name, a supported signature, and a supported key size.
│
│   with module.terraform-aws-perforce.aws_lb_listener.perforce_web_services[0
],
│   on../../lb.tf line 161, in resource "aws_lb_listener" "perforce_web_services" :
│  161 : resource "aws_lb_listener" "perforce_web_services" {
```

If this occurs, it is because Terraform is attempting to attach the certificate to the ALB listener before it has
finished validation. Wait a few minutes and retry `terraform apply`.

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.6 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | ~> 1.51 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.5 |
| <a name="requirement_netapp-ontap"></a> [netapp-ontap](#requirement\_netapp-ontap) | ~> 2.3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.6 |
| <a name="provider_http"></a> [http](#provider\_http) | ~> 3.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_terraform-aws-perforce"></a> [terraform-aws-perforce](#module\_terraform-aws-perforce) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.perforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.perforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat_gateway_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_rt_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.external_perforce_p4_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.external_perforce_web_services](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.perforce_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route_table.private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.allow_my_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.perforce_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_ingress_rule.allow_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_icmp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_perforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_lb.shared_services_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_p4_auth_admin_url"></a> [p4\_auth\_admin\_url](#output\_p4\_auth\_admin\_url) | The URL for the P4Auth service admin page. |
| <a name="output_p4_code_review_url"></a> [p4\_code\_review\_url](#output\_p4\_code\_review\_url) | The URL for the P4 Code Review service. |
| <a name="output_p4_server_connection_string"></a> [p4\_server\_connection\_string](#output\_p4\_server\_connection\_string) | The connection string for the P4 Server. Set your P4PORT environment variable to this value. |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
