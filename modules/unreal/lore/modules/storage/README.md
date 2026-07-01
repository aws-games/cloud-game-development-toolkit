# Storage Sub-Module

Provisions S3 bucket (fragments) and 4 DynamoDB tables (fragments, fragment-metadata, mutable-typed-store, locks).

This is an internal sub-module of `terraform-aws-lore`. Do not consume directly — use the root module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.fragment_metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.locks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.mutable_store](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_s3_bucket.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_intelligent_tiering_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | n/a | yes |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection on DynamoDB tables | `bool` | `true` | no |
| <a name="input_enable_force_destroy"></a> [enable\_force\_destroy](#input\_enable\_force\_destroy) | Allow S3 bucket deletion when non-empty | `bool` | `false` | no |
| <a name="input_intelligent_tiering_archive_days"></a> [intelligent\_tiering\_archive\_days](#input\_intelligent\_tiering\_archive\_days) | Days before fragments move to Archive Access tier. 0 disables Intelligent-Tiering. | `number` | `90` | no |
| <a name="input_intelligent_tiering_deep_archive_days"></a> [intelligent\_tiering\_deep\_archive\_days](#input\_intelligent\_tiering\_deep\_archive\_days) | Days before fragments move to Deep Archive Access tier. | `number` | `180` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_fragment_bucket_arn"></a> [fragment\_bucket\_arn](#output\_fragment\_bucket\_arn) | S3 bucket ARN |
| <a name="output_fragment_bucket_name"></a> [fragment\_bucket\_name](#output\_fragment\_bucket\_name) | S3 bucket name |
| <a name="output_fragment_metadata_table_arn"></a> [fragment\_metadata\_table\_arn](#output\_fragment\_metadata\_table\_arn) | DynamoDB fragment metadata table ARN |
| <a name="output_fragment_metadata_table_name"></a> [fragment\_metadata\_table\_name](#output\_fragment\_metadata\_table\_name) | DynamoDB fragment metadata table name |
| <a name="output_fragments_table_arn"></a> [fragments\_table\_arn](#output\_fragments\_table\_arn) | DynamoDB fragments table ARN |
| <a name="output_fragments_table_name"></a> [fragments\_table\_name](#output\_fragments\_table\_name) | DynamoDB fragments table name |
| <a name="output_locks_table_arn"></a> [locks\_table\_arn](#output\_locks\_table\_arn) | DynamoDB locks table ARN |
| <a name="output_locks_table_name"></a> [locks\_table\_name](#output\_locks\_table\_name) | DynamoDB locks table name |
| <a name="output_mutable_store_table_arn"></a> [mutable\_store\_table\_arn](#output\_mutable\_store\_table\_arn) | DynamoDB mutable store table ARN |
| <a name="output_mutable_store_table_name"></a> [mutable\_store\_table\_name](#output\_mutable\_store\_table\_name) | DynamoDB mutable store table name |
<!-- END_TF_DOCS -->
