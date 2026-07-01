# Compute Sub-Module

Provisions ECS cluster, ASG, task definition, service, IAM roles, Cognito (optional), TLS certs, and secrets.

This is an internal sub-module of `terraform-aws-lore`. Do not consume directly — use the root module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | ~> 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.loreserver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_capacity_provider.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.loreserver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.loreserver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_instance_profile.ecs_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ecs_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.xray_smoke_test](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.otel](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.xray_smoke_test_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ecs_instance_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_instance_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.xray_smoke_test_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachments_exclusive.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_lambda_function.xray_smoke_test](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_launch_template.ecs_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_secretsmanager_secret.hmac_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.tls_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.tls_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.tls_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.hmac_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.tls_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.tls_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.tls_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_bytes.hmac_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/bytes) | resource |
| [tls_cert_request.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [archive_file.xray_smoke_test](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.ec2_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.otel_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.xray_smoke_test_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.xray_smoke_test_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.ecs_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Loreserver container image URI | `string` | n/a | yes |
| <a name="input_dynamodb_table_arns"></a> [dynamodb\_table\_arns](#input\_dynamodb\_table\_arns) | List of DynamoDB table ARNs for IAM policy | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod) — used for ASG defaults | `string` | n/a | yes |
| <a name="input_fragment_bucket_arn"></a> [fragment\_bucket\_arn](#input\_fragment\_bucket\_arn) | ARN of the S3 fragment bucket | `string` | n/a | yes |
| <a name="input_fragment_bucket_name"></a> [fragment\_bucket\_name](#input\_fragment\_bucket\_name) | S3 fragment bucket name (for LORE\_\_* env vars) | `string` | n/a | yes |
| <a name="input_fragment_metadata_table_name"></a> [fragment\_metadata\_table\_name](#input\_fragment\_metadata\_table\_name) | DynamoDB fragment metadata table name | `string` | n/a | yes |
| <a name="input_fragments_table_name"></a> [fragments\_table\_name](#input\_fragments\_table\_name) | DynamoDB fragments table name | `string` | n/a | yes |
| <a name="input_locks_table_arn"></a> [locks\_table\_arn](#input\_locks\_table\_arn) | ARN of the locks DynamoDB table (for GSI access) | `string` | n/a | yes |
| <a name="input_locks_table_name"></a> [locks\_table\_name](#input\_locks\_table\_name) | DynamoDB locks table name | `string` | n/a | yes |
| <a name="input_mutable_store_table_name"></a> [mutable\_store\_table\_name](#input\_mutable\_store\_table\_name) | DynamoDB mutable store table name | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for ASG instances | `list(string)` | n/a | yes |
| <a name="input_server_security_group_id"></a> [server\_security\_group\_id](#input\_server\_security\_group\_id) | Security group ID for Lore server instances | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | n/a | yes |
| <a name="input_write_tier_dns_name"></a> [write\_tier\_dns\_name](#input\_write\_tier\_dns\_name) | Cloud Map DNS name (included in self-signed cert SAN) | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID override. If null, uses latest ECS-optimized AL2023. | `string` | `null` | no |
| <a name="input_asg_desired_size"></a> [asg\_desired\_size](#input\_asg\_desired\_size) | ASG desired capacity. Null = environment-aware default (dev:0, staging:1, prod:1) | `number` | `null` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | ASG maximum size. Null = environment-aware default (dev:1, staging:1, prod:3) | `number` | `null` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | ASG minimum size. Null = environment-aware default (dev:0, staging:0, prod:1) | `number` | `null` | no |
| <a name="input_auth_jwk_endpoint"></a> [auth\_jwk\_endpoint](#input\_auth\_jwk\_endpoint) | JWK endpoint URL (required when auth\_mode = 'external') | `string` | `null` | no |
| <a name="input_auth_jwt_audience"></a> [auth\_jwt\_audience](#input\_auth\_jwt\_audience) | JWT audience values the server accepts | `list(string)` | `[]` | no |
| <a name="input_auth_jwt_issuer"></a> [auth\_jwt\_issuer](#input\_auth\_jwt\_issuer) | JWT issuer string (required when auth\_mode = 'external') | `string` | `null` | no |
| <a name="input_auth_mode"></a> [auth\_mode](#input\_auth\_mode) | Authentication mode: 'none' (open access), 'cognito' (AWS-native M2M), 'external' (bring your own IdP) | `string` | `"none"` | no |
| <a name="input_cache_max_size_bytes"></a> [cache\_max\_size\_bytes](#input\_cache\_max\_size\_bytes) | NVMe cache maximum size in bytes. 0 = auto-size to 80% of instance store capacity. | `number` | `0` | no |
| <a name="input_container_memory_reservation"></a> [container\_memory\_reservation](#input\_container\_memory\_reservation) | Soft memory reservation (MiB) for the loreserver container. If null, auto-sizes based on instance type. | `number` | `null` | no |
| <a name="input_container_user"></a> [container\_user](#input\_container\_user) | User/group for the container process (e.g., '65534', '1000:1000'). Must be numeric UID or UID:GID. | `string` | `"65534"` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Upper limit on running tasks during deployment (% of desired\_count). | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Lower limit on running tasks during deployment (% of desired\_count). Default 66 allows single-task services to deploy without ENI deadlock. | `number` | `66` | no |
| <a name="input_enable_otel_sidecar"></a> [enable\_otel\_sidecar](#input\_enable\_otel\_sidecar) | Deploy ADOT sidecar for OpenTelemetry collection (CloudWatch + X-Ray) | `bool` | `true` | no |
| <a name="input_enable_replication"></a> [enable\_replication](#input\_enable\_replication) | Enable the QUIC internal replication endpoint (port 41340). Required for multi-server cache topologies. | `bool` | `false` | no |
| <a name="input_enable_xray_smoke_test"></a> [enable\_xray\_smoke\_test](#input\_enable\_xray\_smoke\_test) | Deploy X-Ray pipeline smoke test Lambda (validates trace delivery + IAM) | `bool` | `true` | no |
| <a name="input_hmac_key_secret_arn"></a> [hmac\_key\_secret\_arn](#input\_hmac\_key\_secret\_arn) | Secrets Manager ARN for HMAC signing key. If null, a random 32-byte key is generated. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for ECS instances. Unknown types fall back to 28 GiB memory reservation and 937 GB cache size. | `string` | `"i4i.xlarge"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log group retention in days. Valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653. | `number` | `30` | no |
| <a name="input_otel_collector_image"></a> [otel\_collector\_image](#input\_otel\_collector\_image) | ADOT collector image URI. Override to use a private ECR mirror. | `string` | `"public.ecr.aws/aws-observability/aws-otel-collector:latest"` | no |
| <a name="input_replication_peers"></a> [replication\_peers](#input\_replication\_peers) | List of peer addresses for fixed topology replication. Each entry is a host:port string (e.g., '10.0.1.50:41340'). | `list(string)` | `[]` | no |
| <a name="input_service_discovery_registry_arn"></a> [service\_discovery\_registry\_arn](#input\_service\_discovery\_registry\_arn) | Cloud Map service ARN for ECS service registration. Null when service discovery is disabled. | `string` | `null` | no |
| <a name="input_tls_certificate_secret_arn"></a> [tls\_certificate\_secret\_arn](#input\_tls\_certificate\_secret\_arn) | Secrets Manager ARN for server TLS certificate. If null, a self-signed cert is generated. | `string` | `null` | no |
| <a name="input_tls_private_key_secret_arn"></a> [tls\_private\_key\_secret\_arn](#input\_tls\_private\_key\_secret\_arn) | Secrets Manager ARN for server TLS private key. If null, generated with self-signed cert. | `string` | `null` | no |
| <a name="input_tls_san_dns_names"></a> [tls\_san\_dns\_names](#input\_tls\_san\_dns\_names) | Additional DNS SANs for the self-signed TLS certificate (e.g., custom domain names) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cache_max_size_bytes"></a> [cache\_max\_size\_bytes](#output\_cache\_max\_size\_bytes) | Auto-calculated NVMe cache size in bytes (80% of instance store) |
| <a name="output_capacity_provider_name"></a> [capacity\_provider\_name](#output\_capacity\_provider\_name) | Name of the EC2 capacity provider |
| <a name="output_cpu_architecture"></a> [cpu\_architecture](#output\_cpu\_architecture) | CPU architecture for ECS tasks (ARM64 or X86\_64) |
| <a name="output_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#output\_ecs\_cluster\_arn) | ARN of the ECS cluster |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | Name of the ECS cluster |
| <a name="output_effective_asg_config"></a> [effective\_asg\_config](#output\_effective\_asg\_config) | Resolved ASG sizing after environment-aware defaults |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN of the ECS execution IAM role |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS service |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the loreserver task definition |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN of the ECS task IAM role |
| <a name="output_tls_ca_cert_pem"></a> [tls\_ca\_cert\_pem](#output\_tls\_ca\_cert\_pem) | CA certificate PEM for client trust configuration. Null when using external certs. |
<!-- END_TF_DOCS -->
