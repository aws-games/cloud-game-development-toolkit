# Unreal Horde

[Unreal Engine Horde](https://github.com/EpicGames/UnrealEngine/tree/5.4/Engine/Source/Programs/Horde) is a set of services supporting workflows Epic uses to develop Fortnite, Unreal Engine, and other titles. This module deploys the Unreal Engine Horde server on AWS Elastic Container Service using the [image available from the Epic Games Github organization.](https://github.com/orgs/EpicGames/packages/container/package/horde-server). Unreal Engine Horde relies on a Redis cache and a MongoDB compatible database. This module provides these services by provisioning an [Amazon Elasticache with Redis OSS Compatibility](https://aws.amazon.com/elasticache/redis/) cluster and an [Amazon DocumentDB](https://aws.amazon.com/documentdb/) cluster.

Check out this video from Unreal Fest 2024 to learn more about the Unreal Horde module:

[![Watch the video](https://img.youtube.com/vi/kIP4wsVprYY/0.jpg)](https://www.youtube.com/watch?v=kIP4wsVprYY)

## Deployment Architecture
![Unreal Engine Horde Module Architecture](./assets/media/diagrams/unreal-engine-horde-architecture.png)

## Prerequisites
Unreal Engine Horde is only available through the Epic Games Github organization's package registry or the Unreal Engine source code. In order to get access to this software you will need to [join the Epic Games organization](https://github.com/EpicGames/Signup) on Github and accept the Unreal Engine EULA.

## Examples

For example configurations, please see the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/horde/examples).

<!-- TODO -->
<!-- ## Deployment Instructions -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.unreal_horde_agent_asg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.unreal_horde_log_group](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/cloudwatch_log_group) | resource |
| [aws_docdb_cluster.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/docdb_cluster) | resource |
| [aws_docdb_cluster_instance.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/docdb_cluster_instance) | resource |
| [aws_docdb_cluster_parameter_group.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/docdb_cluster_parameter_group) | resource |
| [aws_docdb_subnet_group.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/docdb_subnet_group) | resource |
| [aws_ecs_cluster.unreal_horde_cluster](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.unreal_horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.unreal_horde_task_definition](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_task_definition) | resource |
| [aws_elasticache_cluster.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/elasticache_cluster) | resource |
| [aws_elasticache_replication_group.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.horde](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_instance_profile.unreal_horde_agent_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.horde_agents_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.unreal_horde_default_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.unreal_horde_elasticache_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.unreal_horde_secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.unreal_horde_agent_default_role](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role) | resource |
| [aws_iam_role.unreal_horde_default_role](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role) | resource |
| [aws_iam_role.unreal_horde_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.unreal_horde_default_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.unreal_horde_elasticache_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.unreal_horde_secrets_manager_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.unreal_horde_task_execution_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.unreal_horde_agent_template](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/launch_template) | resource |
| [aws_lb.unreal_horde_external_alb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb) | resource |
| [aws_lb.unreal_horde_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb) | resource |
| [aws_lb_listener.unreal_horde_external_alb_http_listener](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener.unreal_horde_external_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener.unreal_horde_internal_alb_http_listener](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener.unreal_horde_internal_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.unreal_horde_external_alb_grpc_rule](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.unreal_horde_internal_alb_grpc_rule](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.unreal_horde_api_target_group_external](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.unreal_horde_api_target_group_internal](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.unreal_horde_grpc_target_group_external](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.unreal_horde_grpc_target_group_internal](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.ansible_playbooks](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.unreal_horde_alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.alb_access_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.ansible_playbooks_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.ansible_playbooks_versioning](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.unreal_horde_agent_playbook](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_object) | resource |
| [aws_s3_object.unreal_horde_agent_service](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_object) | resource |
| [aws_security_group.unreal_horde_agent_sg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_security_group.unreal_horde_docdb_sg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_security_group.unreal_horde_elasticache_sg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_security_group.unreal_horde_external_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_security_group.unreal_horde_internal_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_security_group.unreal_horde_sg](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_ssm_association.configure_unreal_horde_agent](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ssm_association) | resource |
| [aws_ssm_document.ansible_run_document](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ssm_document) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_agents_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_agents_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_external_alb_outbound_service_api](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_external_alb_outbound_service_grpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_internal_alb_outbound_service_api](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_internal_alb_outbound_service_grpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_horde_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_agents_inbound_agents](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_docdb_ingress](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_elasticache_ingress](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_inbound_external_alb_api](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_inbound_external_alb_grpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_inbound_internal_alb_api](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_inbound_internal_alb_grpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_horde_service_inbound_agents](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.unreal_horde](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/string) | resource |
| [random_string.unreal_horde_alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/string) | resource |
| [random_string.unreal_horde_ansible_playbooks_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/string) | resource |
| [aws_ecs_cluster.unreal_horde_cluster](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/ecs_cluster) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.access_logs_bucket_alb_write](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_tasks_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.horde_agents_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.unreal_horde_default_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.unreal_horde_elasticache_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.unreal_horde_secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_claim_type"></a> [admin\_claim\_type](#input\_admin\_claim\_type) | The claim type for administrators. | `string` | `null` | no |
| <a name="input_admin_claim_value"></a> [admin\_claim\_value](#input\_admin\_claim\_value) | The claim value for administrators. | `string` | `null` | no |
| <a name="input_agent_dotnet_runtime_version"></a> [agent\_dotnet\_runtime\_version](#input\_agent\_dotnet\_runtime\_version) | The dotnet-runtime-{} package to install (see your engine version's release notes for supported version) | `string` | `"6.0"` | no |
| <a name="input_agents"></a> [agents](#input\_agents) | Configures autoscaling groups to be used as build agents by Unreal Engine Horde. | <pre>map(object({<br/>    ami           = string<br/>    instance_type = string<br/>    block_device_mappings = list(<br/>      object({<br/>        device_name = string<br/>        ebs = object({<br/>          volume_size = number<br/>        })<br/>      })<br/>    )<br/>    min_size = optional(number, 0)<br/>    max_size = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_auth_method"></a> [auth\_method](#input\_auth\_method) | The authentication method for the Horde server. | `string` | `null` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The TLS certificate ARN for the Unreal Horde load balancer. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster to deploy the Unreal Horde into. Defaults to null and a cluster will be created. | `string` | `null` | no |
| <a name="input_container_api_port"></a> [container\_api\_port](#input\_container\_api\_port) | The container port for the Unreal Horde web server. | `number` | `5000` | no |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | The CPU allotment for the Unreal Horde container. | `number` | `1024` | no |
| <a name="input_container_grpc_port"></a> [container\_grpc\_port](#input\_container\_grpc\_port) | The container port for the Unreal Horde GRPC channel. | `number` | `5002` | no |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | The memory allotment for the Unreal Horde container. | `number` | `4096` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the Unreal Horde container. | `string` | `"unreal-horde-container"` | no |
| <a name="input_create_external_alb"></a> [create\_external\_alb](#input\_create\_external\_alb) | Set this flag to true to create an external load balancer for Unreal Horde. | `bool` | `true` | no |
| <a name="input_create_internal_alb"></a> [create\_internal\_alb](#input\_create\_internal\_alb) | Set this flag to true to create an internal load balancer for Unreal Horde. | `bool` | `true` | no |
| <a name="input_create_unreal_horde_default_policy"></a> [create\_unreal\_horde\_default\_policy](#input\_create\_unreal\_horde\_default\_policy) | Optional creation of Unreal Horde default IAM Policy. Default is set to true. | `bool` | `true` | no |
| <a name="input_create_unreal_horde_default_role"></a> [create\_unreal\_horde\_default\_role](#input\_create\_unreal\_horde\_default\_role) | Optional creation of Unreal Horde default IAM Role. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_cache_connection_config"></a> [custom\_cache\_connection\_config](#input\_custom\_cache\_connection\_config) | The redis-compatible connection configuration that Horde should use. | `string` | `null` | no |
| <a name="input_custom_unreal_horde_role"></a> [custom\_unreal\_horde\_role](#input\_custom\_unreal\_horde\_role) | ARN of the custom IAM Role you wish to use with Unreal Horde. | `string` | `null` | no |
| <a name="input_database_connection_string"></a> [database\_connection\_string](#input\_database\_connection\_string) | The database connection string that Horde should use. | `string` | `null` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | Set this flag to enable ECS execute permissions on the Unreal Horde container and force new service deployments on Terraform apply. | `bool` | `false` | no |
| <a name="input_desired_container_count"></a> [desired\_container\_count](#input\_desired\_container\_count) | The desired number of containers running Unreal Horde. | `number` | `1` | no |
| <a name="input_docdb_backup_retention_period"></a> [docdb\_backup\_retention\_period](#input\_docdb\_backup\_retention\_period) | Number of days to retain backups for DocumentDB cluster. | `number` | `7` | no |
| <a name="input_docdb_instance_class"></a> [docdb\_instance\_class](#input\_docdb\_instance\_class) | The instance class for the Horde DocumentDB cluster. | `string` | `"db.t4g.medium"` | no |
| <a name="input_docdb_instance_count"></a> [docdb\_instance\_count](#input\_docdb\_instance\_count) | The number of instances to provision for the Horde DocumentDB cluster. | `number` | `2` | no |
| <a name="input_docdb_master_password"></a> [docdb\_master\_password](#input\_docdb\_master\_password) | Master password created for DocumentDB cluster. | `string` | `"mustbeeightchars"` | no |
| <a name="input_docdb_master_username"></a> [docdb\_master\_username](#input\_docdb\_master\_username) | Master username created for DocumentDB cluster. | `string` | `"horde"` | no |
| <a name="input_docdb_preferred_backup_window"></a> [docdb\_preferred\_backup\_window](#input\_docdb\_preferred\_backup\_window) | The preferred window for DocumentDB backups to be created. | `string` | `"07:00-09:00"` | no |
| <a name="input_docdb_skip_final_snapshot"></a> [docdb\_skip\_final\_snapshot](#input\_docdb\_skip\_final\_snapshot) | Flag for whether a final snapshot should be created when the cluster is destroyed. | `bool` | `true` | no |
| <a name="input_docdb_storage_encrypted"></a> [docdb\_storage\_encrypted](#input\_docdb\_storage\_encrypted) | Configure DocumentDB storage at rest. | `bool` | `true` | no |
| <a name="input_elasticache_cluster_count"></a> [elasticache\_cluster\_count](#input\_elasticache\_cluster\_count) | Number of cache cluster to provision in the Elasticache cluster. | `number` | `2` | no |
| <a name="input_elasticache_engine"></a> [elasticache\_engine](#input\_elasticache\_engine) | The engine to use for ElastiCache (redis or valkey) | `string` | `"redis"` | no |
| <a name="input_elasticache_node_count"></a> [elasticache\_node\_count](#input\_elasticache\_node\_count) | Number of cache nodes to provision in the Elasticache cluster. | `number` | `1` | no |
| <a name="input_elasticache_node_type"></a> [elasticache\_node\_type](#input\_elasticache\_node\_type) | The type of nodes provisioned in the Elasticache cluster. | `string` | `"cache.t4g.micro"` | no |
| <a name="input_elasticache_port"></a> [elasticache\_port](#input\_elasticache\_port) | The port for the ElastiCache cluster. | `number` | `6379` | no |
| <a name="input_elasticache_redis_engine_version"></a> [elasticache\_redis\_engine\_version](#input\_elasticache\_redis\_engine\_version) | The version of the Redis engine to use. | `string` | `"7.0"` | no |
| <a name="input_elasticache_redis_parameter_group_name"></a> [elasticache\_redis\_parameter\_group\_name](#input\_elasticache\_redis\_parameter\_group\_name) | The name of the Redis parameter group to use. | `string` | `"default.redis7"` | no |
| <a name="input_elasticache_snapshot_retention_limit"></a> [elasticache\_snapshot\_retention\_limit](#input\_elasticache\_snapshot\_retention\_limit) | The number of Elasticache snapshots to retain. | `number` | `5` | no |
| <a name="input_elasticache_valkey_engine_version"></a> [elasticache\_valkey\_engine\_version](#input\_elasticache\_valkey\_engine\_version) | The version of the ElastiCache engine to use. | `string` | `"7.2"` | no |
| <a name="input_elasticache_valkey_parameter_group_name"></a> [elasticache\_valkey\_parameter\_group\_name](#input\_elasticache\_valkey\_parameter\_group\_name) | The name of the Valkey parameter group to use. | `string` | `"default.valkey7"` | no |
| <a name="input_enable_new_agents_by_default"></a> [enable\_new\_agents\_by\_default](#input\_enable\_new\_agents\_by\_default) | Set this flag to automatically enable new agents that enroll with the Horde Server. | `bool` | `false` | no |
| <a name="input_enable_unreal_horde_alb_access_logs"></a> [enable\_unreal\_horde\_alb\_access\_logs](#input\_enable\_unreal\_horde\_alb\_access\_logs) | Enables access logging for the Unreal Horde ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_enable_unreal_horde_alb_deletion_protection"></a> [enable\_unreal\_horde\_alb\_deletion\_protection](#input\_enable\_unreal\_horde\_alb\_deletion\_protection) | Enables deletion protection for the Unreal Horde ALB. Defaults to true. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. Development, Staging, Production, etc.). This will tag ressources and set ASPNETCORE\_ENVIRONMENT variable. | `string` | `"Development"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Unreal Horde load balancer. | `list(string)` | `[]` | no |
| <a name="input_fully_qualified_domain_name"></a> [fully\_qualified\_domain\_name](#input\_fully\_qualified\_domain\_name) | The fully qualified domain name where your Unreal Engine Horde server will be available. This agents will use this to enroll. | `string` | n/a | yes |
| <a name="input_github_credentials_secret_arn"></a> [github\_credentials\_secret\_arn](#input\_github\_credentials\_secret\_arn) | A secret containing the Github username and password with permissions to the EpicGames organization. | `string` | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | The Horde Server image to use in the ECS service. | `string` | `"ghcr.io/epicgames/horde-server:latest-bundled"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to Unreal Engine Horde module resources. | `string` | `"unreal-horde"` | no |
| <a name="input_oidc_audience"></a> [oidc\_audience](#input\_oidc\_audience) | The audience used for validating externally issued tokens. | `string` | `null` | no |
| <a name="input_oidc_authority"></a> [oidc\_authority](#input\_oidc\_authority) | The authority for the OIDC authentication provider used. | `string` | `null` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | The client ID used for authenticating with the OIDC provider. | `string` | `null` | no |
| <a name="input_oidc_client_secret"></a> [oidc\_client\_secret](#input\_oidc\_client\_secret) | The client secret used for authenticating with the OIDC provider. | `string` | `null` | no |
| <a name="input_oidc_signin_redirect"></a> [oidc\_signin\_redirect](#input\_oidc\_signin\_redirect) | The sign-in redirect URL for the OIDC provider. | `string` | `null` | no |
| <a name="input_p4_port"></a> [p4\_port](#input\_p4\_port) | The Perforce server to connect to. | `string` | `null` | no |
| <a name="input_p4_super_user_password_secret_arn"></a> [p4\_super\_user\_password\_secret\_arn](#input\_p4\_super\_user\_password\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the p4d super user password. | `string` | `null` | no |
| <a name="input_p4_super_user_username_secret_arn"></a> [p4\_super\_user\_username\_secret\_arn](#input\_p4\_super\_user\_username\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the p4d super user username. | `string` | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "iac-management": "CGD-Toolkit",<br/>  "iac-module": "unreal-horde",<br/>  "iac-provider": "Terraform"<br/>}</pre> | no |
| <a name="input_unreal_horde_alb_access_logs_bucket"></a> [unreal\_horde\_alb\_access\_logs\_bucket](#input\_unreal\_horde\_alb\_access\_logs\_bucket) | ID of the S3 bucket for Unreal Horde ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_unreal_horde_alb_access_logs_prefix"></a> [unreal\_horde\_alb\_access\_logs\_prefix](#input\_unreal\_horde\_alb\_access\_logs\_prefix) | Log prefix for Unreal Horde ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_unreal_horde_cloudwatch_log_retention_in_days"></a> [unreal\_horde\_cloudwatch\_log\_retention\_in\_days](#input\_unreal\_horde\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the cloudwatch log group for Unreal Horde. | `string` | `365` | no |
| <a name="input_unreal_horde_external_alb_subnets"></a> [unreal\_horde\_external\_alb\_subnets](#input\_unreal\_horde\_external\_alb\_subnets) | A list of subnets to deploy the Unreal Horde load balancer into. Public subnets are recommended. | `list(string)` | `[]` | no |
| <a name="input_unreal_horde_internal_alb_subnets"></a> [unreal\_horde\_internal\_alb\_subnets](#input\_unreal\_horde\_internal\_alb\_subnets) | A list of subnets to deploy the Unreal Horde internal load balancer into. Private subnets are recommended. | `list(string)` | `[]` | no |
| <a name="input_unreal_horde_service_subnets"></a> [unreal\_horde\_service\_subnets](#input\_unreal\_horde\_service\_subnets) | A list of subnets to deploy the Unreal Horde service into. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy Unreal Horde into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_security_group_id"></a> [agent\_security\_group\_id](#output\_agent\_security\_group\_id) | n/a |
| <a name="output_external_alb_dns_name"></a> [external\_alb\_dns\_name](#output\_external\_alb\_dns\_name) | n/a |
| <a name="output_external_alb_sg_id"></a> [external\_alb\_sg\_id](#output\_external\_alb\_sg\_id) | n/a |
| <a name="output_external_alb_zone_id"></a> [external\_alb\_zone\_id](#output\_external\_alb\_zone\_id) | n/a |
| <a name="output_internal_alb_dns_name"></a> [internal\_alb\_dns\_name](#output\_internal\_alb\_dns\_name) | n/a |
| <a name="output_internal_alb_sg_id"></a> [internal\_alb\_sg\_id](#output\_internal\_alb\_sg\_id) | n/a |
| <a name="output_internal_alb_zone_id"></a> [internal\_alb\_zone\_id](#output\_internal\_alb\_zone\_id) | n/a |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | n/a |
<!-- END_TF_DOCS -->
