# Edge Pod Sub-Module

Deploys a single Lore edge pod — a self-hydrating read cache that proxies branch resolution
to the write tier and serves clones from local NVMe.

## Usage

```hcl
module "lore" {
  # ...
  enable_internal_replication = true
  trusted_ca_pem              = module.edge_pod.replication_client_ca_certificate_pem
}

module "edge_pod" {
  source = "terraform-aws-lore//modules/edge-pod"

  vpc_id                   = module.lore.vpc_id
  subnet_id                = module.lore.private_subnet_ids[0]
  server_security_group_id = module.lore.server_security_group_id
  container_image          = var.container_image
  write_tier_dns           = module.lore.write_tier_discovery_dns
  ca_certificate_pem       = module.lore.ca_certificate_pem
  allowed_ingress_cidrs    = var.allowed_ingress_cidrs
}
```

## Architecture

- EC2 instance running Docker (not ECS) — independent lifecycle from write tier
- NVMe instance store formatted as XFS and mounted at `/srv/urc`
- Self-signed TLS server certificate generated at boot with the instance IP as SAN
- Dedicated edge-specific `clientAuth` certificate stored in Secrets Manager with least-privilege IAM
- Composite storage: local NVMe cache + mTLS replicated durable backend (`lores://` to the write tier)
- Remote mutable store: branch resolution proxied to the write tier over validated TLS

## Prerequisites

- The write tier must set `enable_internal_replication = true`; otherwise it neither starts nor
  exposes port 41340. Add each edge's `replication_client_ca_certificate_pem` output to the write
  tier's `trusted_ca_pem` bundle. Do not use a shared enterprise CA: every accepted certificate
  receives blanket internal-storage access.
- By default, each edge generates a private CA and a unique client certificate/key in two Secrets
  Manager secrets. Its IAM role can read only those two secrets, and startup stops if either cannot
  be retrieved. Custom identity inputs must name a dedicated CA and a certificate secret containing
  the client leaf plus its chain. If those secrets use a customer-managed KMS key, attach a scoped
  `kms:Decrypt` grant to the `iam_role_arn` output; generated secrets use the Secrets Manager
  service key. The generated CA private key remains in Terraform state, so protect state as
  credential material and rotate the edge identity after any disclosure. Generated certificates
  become renewable 30 days before expiry and replace the edge through a certificate-derived
  userdata token. For custom secrets, change `replication_client_material_version` on rotation.
- With custom root TLS, the generated root CA output is null; pass the public write-tier CA PEM
  independently.
- An existing edge instance is replaced when bootstrap userdata changes because cloud-init runs it
  only once. Its NVMe cache is ephemeral and refills from the write tier after replacement.
- Instance type must have instance store (NVMe) — c8gd.8xlarge recommended
- 32+ vCPU required for full internet egress bandwidth (AWS cap on <32 vCPU instances)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |
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
| [aws_iam_role_policy.replication_client_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_secretsmanager_secret.replication_client_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.replication_client_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.replication_client_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.replication_client_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_quic_grpc_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.client_quic_grpc_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_tier_from_edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_tier_from_edge_quic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.write_tier_from_edge_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.hmac](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [tls_cert_request.replication_client](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.replication_client](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.replication_client](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.replication_client_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.replication_client_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication_client_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.al2023_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | Specific CIDRs allowed to reach the edge pod (QUIC:41337, gRPC:41337, HTTP:41339). Public catch-all ranges are rejected. | `list(string)` | n/a | yes |
| <a name="input_ca_certificate_pem"></a> [ca\_certificate\_pem](#input\_ca\_certificate\_pem) | PEM-encoded CA certificate bundle for validating the write tier and completing the mTLS client chain | `string` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | ECR image URI for the Lore server. The strict format keeps userdata shell interpolation non-executable. | `string` | n/a | yes |
| <a name="input_hmac_key"></a> [hmac\_key](#input\_hmac\_key) | 64-character hexadecimal HMAC key for presigned URLs. Generated if null. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type. c8gd.8xlarge minimum for full bandwidth (32 vCPU exempts internet egress cap). | `string` | `"c8gd.8xlarge"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for all resources created by this module | `string` | `"edge"` | no |
| <a name="input_replication_client_ca_certificate_pem"></a> [replication\_client\_ca\_certificate\_pem](#input\_replication\_client\_ca\_certificate\_pem) | Optional dedicated CA PEM that issued the custom replication-client certificate. Give the effective output to the write tier as trusted\_ca\_pem. Do not use a shared enterprise CA. | `string` | `null` | no |
| <a name="input_replication_client_certificate_secret_arn"></a> [replication\_client\_certificate\_secret\_arn](#input\_replication\_client\_certificate\_secret\_arn) | Optional Secrets Manager ARN for this edge pod's clientAuth certificate chain. Set with the matching key ARN and dedicated CA PEM; null generates an edge-specific identity. | `string` | `null` | no |
| <a name="input_replication_client_material_version"></a> [replication\_client\_material\_version](#input\_replication\_client\_material\_version) | Rollout token for custom replication identity secrets. Change it whenever certificate, key, or CA contents rotate under unchanged inputs so the edge instance is replaced. Generated identities derive this automatically. | `string` | `"1"` | no |
| <a name="input_replication_client_private_key_secret_arn"></a> [replication\_client\_private\_key\_secret\_arn](#input\_replication\_client\_private\_key\_secret\_arn) | Optional Secrets Manager ARN for this edge pod's mTLS client private key. | `string` | `null` | no |
| <a name="input_replication_expected_rtt_ms"></a> [replication\_expected\_rtt\_ms](#input\_replication\_expected\_rtt\_ms) | Expected round-trip time to the tier in milliseconds, used to size the QUIC congestion window (Lore default 100). Set to the measured RTT for a pod in another region; leave null in-region. | `number` | `null` | no |
| <a name="input_replication_max_bandwidth_bytes_per_second"></a> [replication\_max\_bandwidth\_bytes\_per\_second](#input\_replication\_max\_bandwidth\_bytes\_per\_second) | Cap on the pod-to-tier replication link in bytes per second. Null leaves Lore's default. | `number` | `null` | no |
| <a name="input_server_security_group_id"></a> [server\_security\_group\_id](#input\_server\_security\_group\_id) | Security group of the Lore tier this pod forwards to, when it is in the same VPC: the pod is granted ingress to it. Null when the tier is reached across inter-region peering; allow the pod's CIDR on the tier instead (root module replication\_ingress\_cidrs). | `string` | `null` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID for the edge pod instance | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the edge pod will be deployed | `string` | n/a | yes |
| <a name="input_write_tier_dns"></a> [write\_tier\_dns](#input\_write\_tier\_dns) | DNS name of the write tier (Cloud Map). Used for both gRPC branch resolution (:41337) and mTLS QUIC replication (:41340). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | IAM role ARN for the edge instance. Attach scoped kms:Decrypt permission here when custom identity secrets use a customer-managed KMS key. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | EC2 instance ID of the edge pod |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP address of the edge pod |
| <a name="output_replication_client_ca_certificate_pem"></a> [replication\_client\_ca\_certificate\_pem](#output\_replication\_client\_ca\_certificate\_pem) | Dedicated CA PEM for this edge pod's mTLS client identity. Add it to the write tier's trusted\_ca\_pem bundle. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID of the edge pod |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->