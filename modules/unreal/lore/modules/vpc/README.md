# VPC Sub-Module

Provisions VPC, public/private subnets, IGW, NAT gateway, and route tables.

This is an internal sub-module of `terraform-aws-lore`. Do not consume directly — use the root module.

## Route ownership

This sub-module manages each route table's complete inline route set. Before updating an existing
VPC, inspect the plan for routes added by another AWS service. Do not apply a plan that removes
GuardDuty Runtime Monitoring routes or any other service-managed route. For non-peering routes,
use the existing-VPC path in step 4 instead.

There is no safe in-place Terraform migration from these inline routes to separate `aws_route`
resources, and this module does not attempt one. The private route table declares exactly the
`0.0.0.0/0` NAT route plus `peering_routes`; the public route table declares exactly the
`0.0.0.0/0` internet gateway route. Gateway VPC endpoint routes (`vpce-`) are not affected.

Prerequisites before every apply against an existing VPC:

1. Save the plan: `terraform plan -out=tfplan`.
2. List routes the plan would remove. Any output means stop:

   ```bash
   terraform show -json tfplan | jq -r '
     .resource_changes[]
     | select(.type == "aws_route_table"
         and ((.change.actions | index("update")) or (.change.actions | index("delete"))))
     | .address as $a
     | ((.change.before.route // []) - (.change.after.route // []))[]
     | "\($a) removes \(.cidr_block // .ipv6_cidr_block // .destination_prefix_list_id)"'
   ```

   Routes whose target is unknown until apply (a new peering connection) also appear; confirm
   each one is a route you declared.
3. Compare with the live table (read-only):
   `aws ec2 describe-route-tables --route-table-ids <id> --query 'RouteTables[0].Routes'`.
   Every route other than `local`, the `0.0.0.0/0` default, a declared peering route or a
   `vpce-` gateway endpoint route will be removed by the next apply.
4. If such a route exists, do not apply. Peering routes can be moved into `peering_routes`
   (root: `vpc_peering_routes`). For any other route type, the supported path is to run the root
   module with an existing VPC (`vpc_id`, `private_subnet_ids`, `public_subnet_ids`) whose routes
   you manage yourself. The regional cache has no existing-VPC input yet.

The mocked tests in `tests/10_multi_region.tftest.hcl` pin the exact declared route sets, so a
change to them fails CI rather than surfacing first in a plan.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones (minimum 2) | `list(string)` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for all VPC resources | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | n/a | yes |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Enable VPC flow logs to CloudWatch | `bool` | `false` | no |
| <a name="input_peering_routes"></a> [peering\_routes](#input\_peering\_routes) | Routes to peered VPCs added to the private route table. The route table manages its routes inline, so routes created elsewhere with aws\_route are removed on the next apply; pass them here instead. | <pre>list(object({<br/>    cidr_block                = string<br/>    vpc_peering_connection_id = string<br/>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_nat_gateway_id"></a> [nat\_gateway\_id](#output\_nat\_gateway\_id) | ID of the NAT gateway |
| <a name="output_private_route_table_id"></a> [private\_route\_table\_id](#output\_private\_route\_table\_id) | ID of the private route table |
| <a name="output_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#output\_private\_subnet\_cidrs) | CIDR blocks of the private subnets |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | IDs of the private subnets |
| <a name="output_public_route_table_id"></a> [public\_route\_table\_id](#output\_public\_route\_table\_id) | ID of the public route table |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->