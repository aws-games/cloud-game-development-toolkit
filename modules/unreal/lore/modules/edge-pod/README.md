# Edge Pod Sub-Module

Deploys a single Lore edge pod — a self-hydrating read cache that proxies branch resolution
to the write tier and serves clones from local NVMe.

## Usage

```hcl
module "edge_pod" {
  source = "terraform-aws-lore//modules/edge-pod"

  vpc_id                   = module.lore.vpc_id
  subnet_id                = module.lore.private_subnet_ids[0]
  server_security_group_id = module.lore.server_security_group_id
  container_image          = var.container_image
  write_tier_dns           = module.lore.write_tier_discovery_dns
  ca_certificate_pem       = module.lore.ca_certificate_pem
}
```

## Architecture

- EC2 instance running Docker (not ECS) — independent lifecycle from write tier
- NVMe instance store formatted as XFS and mounted at `/srv/urc`
- Self-signed TLS cert generated at boot with instance IP as SAN
- Composite storage: local NVMe cache + replicated durable backend (QUIC to write tier)
- Remote mutable store: branch resolution proxied to write tier via gRPC+TLS

## Prerequisites

- Instance type must have instance store (NVMe) — c8gd.8xlarge recommended
- 32+ vCPU required for full internet egress bandwidth (AWS cap on <32 vCPU instances)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_quic_grpc_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_quic_grpc_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_tier_from_edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_tier_from_edge_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.hmac](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [tls_private_key.edge](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.edge](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.al2023_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ca_certificate_pem"></a> [ca\_certificate\_pem](#input\_ca\_certificate\_pem) | PEM-encoded CA certificate of the write tier (for TLS verification) | `string` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Docker image URI for the Lore server (must match instance architecture) | `string` | n/a | yes |
| <a name="input_server_security_group_id"></a> [server\_security\_group\_id](#input\_server\_security\_group\_id) | Security group ID of the write tier (edge pod is granted ingress) | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID for the edge pod instance | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the edge pod will be deployed | `string` | n/a | yes |
| <a name="input_write_tier_dns"></a> [write\_tier\_dns](#input\_write\_tier\_dns) | DNS name of the write tier (Cloud Map). Used for both gRPC branch resolution (:41337) and QUIC replication (:41340). | `string` | n/a | yes |
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | CIDRs allowed to reach the edge pod (QUIC:41337, gRPC:41337, HTTP:41339) | `list(string)` | `[]` | no |
| <a name="input_hmac_key"></a> [hmac\_key](#input\_hmac\_key) | 64-char hex HMAC key for presigned URLs. Generated if null. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type. c8gd.8xlarge minimum for full bandwidth (32 vCPU exempts internet egress cap). | `string` | `"c8gd.8xlarge"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for all resources created by this module | `string` | `"edge"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | EC2 instance ID of the edge pod |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP address of the edge pod |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID of the edge pod |
<!-- END_TF_DOCS -->
