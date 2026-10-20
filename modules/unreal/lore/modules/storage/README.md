# Storage Sub-Module

Provisions S3 bucket (fragments) and 4 DynamoDB tables (fragments, fragment-metadata, mutable-typed-store, locks).

This is an internal sub-module of `terraform-aws-lore`. Do not consume directly — use the root module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

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

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_dynamodb_table.fragment_metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.locks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.mutable_store](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_role.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_bucket.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_intelligent_tiering_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.fragments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_iam_policy_document.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | n/a | yes |
| <a name="input_create_immutable_tables"></a> [create\_immutable\_tables](#input\_create\_immutable\_tables) | Create the fragments and fragment-metadata tables. Set false when they already exist in this region as Global Table replicas created by the write region. | `bool` | `true` | no |
| <a name="input_create_mutable_tables"></a> [create\_mutable\_tables](#input\_create\_mutable\_tables) | Create the mutable-typed-store and locks tables. Only the write region holds these; a regional tier sets false. | `bool` | `true` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection on DynamoDB tables | `bool` | `true` | no |
| <a name="input_enable_force_destroy"></a> [enable\_force\_destroy](#input\_enable\_force\_destroy) | Allow S3 bucket deletion when non-empty | `bool` | `false` | no |
| <a name="input_enable_replication"></a> [enable\_replication](#input\_enable\_replication) | Replicate fragments to another region's bucket (S3 Cross-Region Replication). Turns on bucket versioning, which CRR requires. A separate flag from the ARN because the destination bucket is usually created in the same apply and its ARN is unknown at plan time. | `bool` | `false` | no |
| <a name="input_immutable_table_replica_regions"></a> [immutable\_table\_replica\_regions](#input\_immutable\_table\_replica\_regions) | Regions to add as DynamoDB Global Table replicas of the two immutable-store tables (fragments, fragment-metadata). Never applied to the mutable store or locks tables, whose compare-and-swap semantics do not survive multi-region replication. | `list(string)` | `[]` | no |
| <a name="input_intelligent_tiering_archive_days"></a> [intelligent\_tiering\_archive\_days](#input\_intelligent\_tiering\_archive\_days) | Days before fragments move to Archive Access tier. 0 disables Intelligent-Tiering. | `number` | `90` | no |
| <a name="input_intelligent_tiering_deep_archive_days"></a> [intelligent\_tiering\_deep\_archive\_days](#input\_intelligent\_tiering\_deep\_archive\_days) | Days before fragments move to Deep Archive Access tier. | `number` | `180` | no |
| <a name="input_replication_destination_bucket_arn"></a> [replication\_destination\_bucket\_arn](#input\_replication\_destination\_bucket\_arn) | ARN of the fragments bucket in the other region. Required when enable\_replication is true. | `string` | `null` | no |
| <a name="input_replication_time_control"></a> [replication\_time\_control](#input\_replication\_time\_control) | Enable S3 Replication Time Control (15-minute SLA, extra per-GB fee) on the replication rule. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
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
| <a name="output_replication_role_arn"></a> [replication\_role\_arn](#output\_replication\_role\_arn) | IAM role used by S3 Cross-Region Replication (null when replication is disabled) |
| <a name="output_replication_summary"></a> [replication\_summary](#output\_replication\_summary) | How this store replicates (for tests and the example README) |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->