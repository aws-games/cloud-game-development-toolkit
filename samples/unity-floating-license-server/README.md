```
terraform apply
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- END_TF_DOCS -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.73.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.89.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unity_client_instance"></a> [unity\_client\_instance](#module\_unity\_client\_instance) | ./unity-client | n/a |
| <a name="module_unity_floating_license_bucket"></a> [unity\_floating\_license\_bucket](#module\_unity\_floating\_license\_bucket) | ./s3-bucket | n/a |
| <a name="module_unity_floating_license_server"></a> [unity\_floating\_license\_server](#module\_unity\_floating\_license\_server) | ../../modules/unity/unity-floating-license-server | n/a |
| <a name="module_unity_floating_license_server_vpc"></a> [unity\_floating\_license\_server\_vpc](#module\_unity\_floating\_license\_server\_vpc) | ./vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_vpc_security_group_ingress_rule.ingress_from_client_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
