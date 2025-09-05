# Unreal Cloud DDC Infra Module

[Unreal Cloud Derived Data Cache](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine) ([source code](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)) is a caching system that stores additional data required to use assets, such as compiled shaders. This allows the engine to quickly retrieve this data instead of having to regenerate it, saving time and disk space for the development team. For distributed teams, a cloud-hosted DDC enables efficient collaboration by ensuring all team members have access to the same cached data regardless of their location. This module deploys the core infrastructure for Unreal Engine's Cloud Derived Data Cache (DDC) on AWS. It creates a scalable, secure, and high-performance environment that optimizes asset processing and distribution throughout your game development pipeline, reducing build times and improving team collaboration.

The Unreal Cloud Derived Data Cache (DDC) infrastructure module implements Epic's recommended architecture using ScyllaDB, a high-performance Cassandra-compatible database. This module provisions the following AWS resources:

1. ScyllaDB Database Layer:
    - Deployed on EC2 instances
    - Supports both single-node and multi-node cluster configurations
    - Optimized for high-throughput DDC operations
    - Configured with AWS Systems Manager Session Manager to provide secure shell access without requiring SSH or bastion hosts

2. ScyllaDB Monitoring Stack:
    - Deployed on an EC2 instance
    - Uses Prometheus for metrics collection, Alertmanager for handling alerts, and Grafana for visualization
    - Creates a Application Load Balancer for accessing the Grafana UI for real-time insights into ScyllaDB node performance

3. Amazon EKS Cluster with specialized node groups:
    - System node group: Handles core Kubernetes components and system workloads
    - NVME node group: Optimized for high-performance storage operations
    - Worker node group: Manages regional data replication and distribution
    - Configured with AWS Systems Manager Session Manager to provide secure shell access without requiring SSH or bastion hosts

3. S3 Bucket:
    - Provides durable storage for cached assets
    - Enables cross-region asset availability
    - Serves as a persistent backup layer


## Deployment Architecture

<br/>

![Unreal Engine Cloud DDC Infra Module Architecture](./assets/media/diagrams/unreal-cloud-ddc-infra.png)

<br/>

## Prerequisites

#### Network Infrastructure Requirements

At a minimum, the Cloud DDC Module requires a Virtual Private Cloud (VPC) with a specific subnet configuration. The suggested configuration includes:

- 2 public subnets
- 2 private subnets
- Coverage across 2 Availability Zones
- An S3 interface endpoint

This architecture ensures high availability and secure communication patterns for your DDC infrastructure.

<br/>

<!-- ## Examples

For example configurations, please see the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra/examples). -->

<!-- TODO -->
<!-- ## Deployment Instructions -->


#### Configuring Node Groups and ScyllaDB Deployment

The footprint of your Cloud DDC deployment can be configured through 2 variables:

<br/>

EKS Node Group Configuration: `eks_node_group_subnets`

The `eks_node_group_subnets` variable defines the subnet distribution for your EKS node groups. Each specified subnet serves as a potential target for node placement, providing granular control over the geographical distribution of your EKS infrastructure. Adding more subnets to this configuration increases deployment flexibility and enables broader availability zone coverage for your workloads at the cost of increased network complexity and potential inter-AZ data transfer charges.


<br/>

ScyllaDB Instance Distribution: `scylla_subnets`

The `scylla_subnets` variable determines the deployment topology of your ScyllaDB instances. Each specified subnet receives a dedicated ScyllaDB instance, with multiple subnet configurations automatically establishing a distributed cluster architecture. Configurations of two or more subnets enable high availability and data resilience through native ScyllaDB clustering at the cost of increased infrastructure complexity and proportionally higher operational expenses.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.89.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.10.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.unreal_cluster_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_cluster.unreal_cloud_ddc_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.nvme_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_node_group.system_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_node_group.worker_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_instance_profile.scylla_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_instance_profile.scylla_monitoring_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.nvme_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scylla_monitoring_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scylla_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.system_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.worker_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.scylla_monitoring_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachments_exclusive.eks_cluster_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.nvme_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.scylla_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.system_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.worker_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_instance.scylla_ec2_instance_other_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.scylla_ec2_instance_seed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.scylla_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.nvme_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.system_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.worker_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.scylla_monitoring_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.scylla_monitoring_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.scylla_monitoring_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.scylla_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.unreal_ddc_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.alb_access_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.unreal_ddc_s3_acls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.cluster_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.nvme_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_monitoring_lb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_monitoring_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.system_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.worker_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.cluster_egress_sg_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.nvme_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.scylla_monitoring_lb_sg_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.scylla_monitoring_sg_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.self_scylla_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ssm_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.system_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.worker_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.cluster_lb_ingress_sg_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_monitoring_ingress_node_exporter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_monitoring_ingress_prometheus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_monitoring_lb_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self_ingress_cluster_sg_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.scylla_monitoring_lb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/string) | resource |
| [aws_ami.amazon_linux](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.scylla_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.access_logs_bucket_alb_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scylla_monitoring_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scylla_monitoring_policy_doc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [tls_certificate.eks_tls_certificate](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | The ARN of the certificate to use on the ALB | `string` | `null` | no |
| <a name="input_create_application_load_balancer"></a> [create\_application\_load\_balancer](#input\_create\_application\_load\_balancer) | Whether to create an application load balancer for the Scylla monitoring dashboard. | `bool` | `true` | no |
| <a name="input_create_scylla_monitoring_stack"></a> [create\_scylla\_monitoring\_stack](#input\_create\_scylla\_monitoring\_stack) | Whether to create the Scylla monitoring stack | `bool` | `true` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | Enable debug mode | `bool` | `false` | no |
| <a name="input_eks_cluster_cloudwatch_log_group_prefix"></a> [eks\_cluster\_cloudwatch\_log\_group\_prefix](#input\_eks\_cluster\_cloudwatch\_log\_group\_prefix) | Prefix to be used for the EKS cluster CloudWatch log group. | `string` | `"/aws/eks/unreal-cloud-ddc/cluster"` | no |
| <a name="input_eks_cluster_logging_types"></a> [eks\_cluster\_logging\_types](#input\_eks\_cluster\_logging\_types) | List of EKS cluster log types to be enabled. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_eks_cluster_private_access"></a> [eks\_cluster\_private\_access](#input\_eks\_cluster\_private\_access) | Allows private access of the EKS Control Plane from subnets attached to EKS Cluster | `bool` | `true` | no |
| <a name="input_eks_cluster_public_access"></a> [eks\_cluster\_public\_access](#input\_eks\_cluster\_public\_access) | Allows public access of EKS Control Plane should be used with | `bool` | `false` | no |
| <a name="input_eks_cluster_public_endpoint_access_cidr"></a> [eks\_cluster\_public\_endpoint\_access\_cidr](#input\_eks\_cluster\_public\_endpoint\_access\_cidr) | List of the CIDR Ranges you want to grant public access to the EKS Cluster's public endpoint. | `list(string)` | `[]` | no |
| <a name="input_eks_node_group_subnets"></a> [eks\_node\_group\_subnets](#input\_eks\_node\_group\_subnets) | A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended. | `list(string)` | `[]` | no |
| <a name="input_enable_scylla_monitoring_lb_access_logs"></a> [enable\_scylla\_monitoring\_lb\_access\_logs](#input\_enable\_scylla\_monitoring\_lb\_access\_logs) | Whether to enable access logs for the Scylla monitoring load balancer. | `bool` | `false` | no |
| <a name="input_enable_scylla_monitoring_lb_deletion_protection"></a> [enable\_scylla\_monitoring\_lb\_deletion\_protection](#input\_enable\_scylla\_monitoring\_lb\_deletion\_protection) | Whether to enable deletion protection for the Scylla monitoring load balancer. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | List of existing security groups to add to the monitoring and Unreal DDC load balancers | `list(string)` | `[]` | no |
| <a name="input_internal_facing_application_load_balancer"></a> [internal\_facing\_application\_load\_balancer](#input\_internal\_facing\_application\_load\_balancer) | Whether the application load balancer should be internal-facing. | `bool` | `false` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to be used by the EKS cluster. | `string` | `"1.31"` | no |
| <a name="input_monitoring_application_load_balancer_subnets"></a> [monitoring\_application\_load\_balancer\_subnets](#input\_monitoring\_application\_load\_balancer\_subnets) | The subnets in which the ALB will be deployed | `list(string)` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_nvme_managed_node_desired_size"></a> [nvme\_managed\_node\_desired\_size](#input\_nvme\_managed\_node\_desired\_size) | Desired number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_instance_type"></a> [nvme\_managed\_node\_instance\_type](#input\_nvme\_managed\_node\_instance\_type) | Nvme managed node group instance type | `string` | `"i3en.large"` | no |
| <a name="input_nvme_managed_node_max_size"></a> [nvme\_managed\_node\_max\_size](#input\_nvme\_managed\_node\_max\_size) | Max number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_min_size"></a> [nvme\_managed\_node\_min\_size](#input\_nvme\_managed\_node\_min\_size) | Min number of nvme managed node group instances | `number` | `1` | no |
| <a name="input_nvme_node_group_label"></a> [nvme\_node\_group\_label](#input\_nvme\_node\_group\_label) | Label applied to nvme node group. These will need to be matched in values for taints and tolerations for the worker pod definition. | `map(string)` | <pre>{<br/>  "unreal-cloud-ddc/node-type": "nvme"<br/>}</pre> | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region to deploy to | `string` | `"us-west-2"` | no |
| <a name="input_scylla_ami_name"></a> [scylla\_ami\_name](#input\_scylla\_ami\_name) | Name of the Scylla AMI to be used to get the AMI ID | `string` | `"ScyllaDB 6.0.1"` | no |
| <a name="input_scylla_architecture"></a> [scylla\_architecture](#input\_scylla\_architecture) | The chip architecture to use when finding the scylla image. Valid | `string` | `"x86_64"` | no |
| <a name="input_scylla_db_storage"></a> [scylla\_db\_storage](#input\_scylla\_db\_storage) | Size of gp3 ebs volumes attached to Scylla DBs | `number` | `100` | no |
| <a name="input_scylla_db_throughput"></a> [scylla\_db\_throughput](#input\_scylla\_db\_throughput) | Throughput of gp3 ebs volumes attached to Scylla DBs | `number` | `200` | no |
| <a name="input_scylla_instance_type"></a> [scylla\_instance\_type](#input\_scylla\_instance\_type) | The type and size of the Scylla instance. | `string` | `"i4i.2xlarge"` | no |
| <a name="input_scylla_monitoring_instance_storage"></a> [scylla\_monitoring\_instance\_storage](#input\_scylla\_monitoring\_instance\_storage) | Size of gp3 ebs volumes in GB attached to Scylla monitoring instance | `number` | `20` | no |
| <a name="input_scylla_monitoring_instance_type"></a> [scylla\_monitoring\_instance\_type](#input\_scylla\_monitoring\_instance\_type) | The type and size of the Scylla monitoring instance. | `string` | `"t3.xlarge"` | no |
| <a name="input_scylla_monitoring_lb_access_logs_bucket"></a> [scylla\_monitoring\_lb\_access\_logs\_bucket](#input\_scylla\_monitoring\_lb\_access\_logs\_bucket) | Name of the S3 bucket to store the access logs for the Scylla monitoring load balancer. | `string` | `null` | no |
| <a name="input_scylla_monitoring_lb_access_logs_prefix"></a> [scylla\_monitoring\_lb\_access\_logs\_prefix](#input\_scylla\_monitoring\_lb\_access\_logs\_prefix) | Prefix to use for the access logs for the Scylla monitoring load balancer. | `string` | `null` | no |
| <a name="input_scylla_subnets"></a> [scylla\_subnets](#input\_scylla\_subnets) | A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended. | `list(string)` | `[]` | no |
| <a name="input_system_managed_node_desired_size"></a> [system\_managed\_node\_desired\_size](#input\_system\_managed\_node\_desired\_size) | Desired number of system managed node group instances. | `number` | `1` | no |
| <a name="input_system_managed_node_instance_type"></a> [system\_managed\_node\_instance\_type](#input\_system\_managed\_node\_instance\_type) | Monitoring managed node group instance type. | `string` | `"m5.large"` | no |
| <a name="input_system_managed_node_max_size"></a> [system\_managed\_node\_max\_size](#input\_system\_managed\_node\_max\_size) | Max number of system managed node group instances. | `number` | `2` | no |
| <a name="input_system_managed_node_min_size"></a> [system\_managed\_node\_min\_size](#input\_system\_managed\_node\_min\_size) | Min number of system managed node group instances. | `number` | `1` | no |
| <a name="input_system_node_group_label"></a> [system\_node\_group\_label](#input\_system\_node\_group\_label) | Label applied to system node group | `map(string)` | <pre>{<br/>  "pool": "system-pool"<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "Unreal DDC"<br/>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | String for VPC ID | `string` | n/a | yes |
| <a name="input_worker_managed_node_desired_size"></a> [worker\_managed\_node\_desired\_size](#input\_worker\_managed\_node\_desired\_size) | Desired number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_instance_type"></a> [worker\_managed\_node\_instance\_type](#input\_worker\_managed\_node\_instance\_type) | Worker managed node group instance type. | `string` | `"c5.large"` | no |
| <a name="input_worker_managed_node_max_size"></a> [worker\_managed\_node\_max\_size](#input\_worker\_managed\_node\_max\_size) | Max number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_min_size"></a> [worker\_managed\_node\_min\_size](#input\_worker\_managed\_node\_min\_size) | Min number of worker managed node group instances. | `number` | `0` | no |
| <a name="input_worker_node_group_label"></a> [worker\_node\_group\_label](#input\_worker\_node\_group\_label) | Label applied to worker node group. These will need to be matched in values for taints and tolerations for the worker pod definition. | `map(string)` | <pre>{<br/>  "unreal-cloud-ddc/node-type": "worker"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the EKS Cluster |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Public key for the EKS Cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS Cluster Endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS Cluster |
| <a name="output_external_alb_dns_name"></a> [external\_alb\_dns\_name](#output\_external\_alb\_dns\_name) | DNS endpoint of Application Load Balancer (ALB) |
| <a name="output_external_alb_zone_id"></a> [external\_alb\_zone\_id](#output\_external\_alb\_zone\_id) | Zone ID for internet facing load balancer |
| <a name="output_nvme_node_group_label"></a> [nvme\_node\_group\_label](#output\_nvme\_node\_group\_label) | Label for the NVME node group |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | OIDC provider for the EKS Cluster |
| <a name="output_peer_security_group_id"></a> [peer\_security\_group\_id](#output\_peer\_security\_group\_id) | ID of the Peer Security Group |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | Bucket to be used for the Unreal Cloud DDC assets |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | IPs of the Scylla EC2 instances |
| <a name="output_system_node_group_label"></a> [system\_node\_group\_label](#output\_system\_node\_group\_label) | Label for the System node group |
| <a name="output_worker_node_group_label"></a> [worker\_node\_group\_label](#output\_worker\_node\_group\_label) | Label for the Worker node group |
<!-- END_TF_DOCS -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.89.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.4.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.unreal_cluster_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_cluster.unreal_cloud_ddc_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.nvme_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_node_group.system_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_node_group.worker_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_instance_profile.scylla_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_instance_profile.scylla_monitoring_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.nvme_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scylla_monitoring_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scylla_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.system_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.worker_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.scylla_monitoring_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachments_exclusive.eks_cluster_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.nvme_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.scylla_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.system_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.worker_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_instance.scylla_ec2_instance_other_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.scylla_ec2_instance_seed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.scylla_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.nvme_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.system_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.worker_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.scylla_monitoring_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.scylla_monitoring_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.scylla_monitoring_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.scylla_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.unreal_ddc_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.alb_access_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.unreal_ddc_s3_acls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.cluster_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.nvme_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_monitoring_lb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_monitoring_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.system_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.worker_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.cluster_egress_sg_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.nvme_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.scylla_monitoring_lb_sg_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.scylla_monitoring_sg_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.self_scylla_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ssm_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.system_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.worker_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.cluster_lb_ingress_sg_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_monitoring_ingress_node_exporter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_monitoring_ingress_prometheus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_monitoring_lb_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self_ingress_cluster_sg_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.scylla_monitoring_lb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/string) | resource |
| [aws_ami.amazon_linux](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.scylla_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.access_logs_bucket_alb_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scylla_monitoring_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scylla_monitoring_policy_doc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [tls_certificate.eks_tls_certificate](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | The ARN of the certificate to use on the ALB | `string` | `null` | no |
| <a name="input_create_application_load_balancer"></a> [create\_application\_load\_balancer](#input\_create\_application\_load\_balancer) | Whether to create an application load balancer for the Scylla monitoring dashboard. | `bool` | `true` | no |
| <a name="input_create_scylla_monitoring_stack"></a> [create\_scylla\_monitoring\_stack](#input\_create\_scylla\_monitoring\_stack) | Whether to create the Scylla monitoring stack | `bool` | `true` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | Enable debug mode | `bool` | `false` | no |
| <a name="input_eks_cluster_cloudwatch_log_group_prefix"></a> [eks\_cluster\_cloudwatch\_log\_group\_prefix](#input\_eks\_cluster\_cloudwatch\_log\_group\_prefix) | Prefix to be used for the EKS cluster CloudWatch log group. | `string` | `"/aws/eks/unreal-cloud-ddc/cluster"` | no |
| <a name="input_eks_cluster_logging_types"></a> [eks\_cluster\_logging\_types](#input\_eks\_cluster\_logging\_types) | List of EKS cluster log types to be enabled. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_eks_cluster_private_access"></a> [eks\_cluster\_private\_access](#input\_eks\_cluster\_private\_access) | Allows private access of the EKS Control Plane from subnets attached to EKS Cluster | `bool` | `true` | no |
| <a name="input_eks_cluster_public_access"></a> [eks\_cluster\_public\_access](#input\_eks\_cluster\_public\_access) | Allows public access of EKS Control Plane should be used with | `bool` | `false` | no |
| <a name="input_eks_cluster_public_endpoint_access_cidr"></a> [eks\_cluster\_public\_endpoint\_access\_cidr](#input\_eks\_cluster\_public\_endpoint\_access\_cidr) | List of the CIDR Ranges you want to grant public access to the EKS Cluster's public endpoint. | `list(string)` | `[]` | no |
| <a name="input_eks_node_group_subnets"></a> [eks\_node\_group\_subnets](#input\_eks\_node\_group\_subnets) | A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended. | `list(string)` | `[]` | no |
| <a name="input_enable_scylla_monitoring_lb_access_logs"></a> [enable\_scylla\_monitoring\_lb\_access\_logs](#input\_enable\_scylla\_monitoring\_lb\_access\_logs) | Whether to enable access logs for the Scylla monitoring load balancer. | `bool` | `false` | no |
| <a name="input_enable_scylla_monitoring_lb_deletion_protection"></a> [enable\_scylla\_monitoring\_lb\_deletion\_protection](#input\_enable\_scylla\_monitoring\_lb\_deletion\_protection) | Whether to enable deletion protection for the Scylla monitoring load balancer. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | List of existing security groups to add to the monitoring and Unreal DDC load balancers | `list(string)` | `[]` | no |
| <a name="input_internal_facing_application_load_balancer"></a> [internal\_facing\_application\_load\_balancer](#input\_internal\_facing\_application\_load\_balancer) | Whether the application load balancer should be internal-facing. | `bool` | `false` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to be used by the EKS cluster. | `string` | `"1.31"` | no |
| <a name="input_monitoring_application_load_balancer_subnets"></a> [monitoring\_application\_load\_balancer\_subnets](#input\_monitoring\_application\_load\_balancer\_subnets) | The subnets in which the ALB will be deployed | `list(string)` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_nvme_managed_node_desired_size"></a> [nvme\_managed\_node\_desired\_size](#input\_nvme\_managed\_node\_desired\_size) | Desired number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_instance_type"></a> [nvme\_managed\_node\_instance\_type](#input\_nvme\_managed\_node\_instance\_type) | Nvme managed node group instance type | `string` | `"i3en.large"` | no |
| <a name="input_nvme_managed_node_max_size"></a> [nvme\_managed\_node\_max\_size](#input\_nvme\_managed\_node\_max\_size) | Max number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_min_size"></a> [nvme\_managed\_node\_min\_size](#input\_nvme\_managed\_node\_min\_size) | Min number of nvme managed node group instances | `number` | `1` | no |
| <a name="input_nvme_node_group_label"></a> [nvme\_node\_group\_label](#input\_nvme\_node\_group\_label) | Label applied to nvme node group. These will need to be matched in values for taints and tolerations for the worker pod definition. | `map(string)` | <pre>{<br/>  "unreal-cloud-ddc/node-type": "nvme"<br/>}</pre> | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region to deploy to | `string` | `"us-west-2"` | no |
| <a name="input_scylla_ami_name"></a> [scylla\_ami\_name](#input\_scylla\_ami\_name) | Name of the Scylla AMI to be used to get the AMI ID | `string` | `"ScyllaDB 6.0.1"` | no |
| <a name="input_scylla_architecture"></a> [scylla\_architecture](#input\_scylla\_architecture) | The chip architecture to use when finding the scylla image. Valid | `string` | `"x86_64"` | no |
| <a name="input_scylla_db_storage"></a> [scylla\_db\_storage](#input\_scylla\_db\_storage) | Size of gp3 ebs volumes attached to Scylla DBs | `number` | `100` | no |
| <a name="input_scylla_db_throughput"></a> [scylla\_db\_throughput](#input\_scylla\_db\_throughput) | Throughput of gp3 ebs volumes attached to Scylla DBs | `number` | `200` | no |
| <a name="input_scylla_instance_type"></a> [scylla\_instance\_type](#input\_scylla\_instance\_type) | The type and size of the Scylla instance. | `string` | `"i4i.2xlarge"` | no |
| <a name="input_scylla_monitoring_instance_storage"></a> [scylla\_monitoring\_instance\_storage](#input\_scylla\_monitoring\_instance\_storage) | Size of gp3 ebs volumes in GB attached to Scylla monitoring instance | `number` | `20` | no |
| <a name="input_scylla_monitoring_instance_type"></a> [scylla\_monitoring\_instance\_type](#input\_scylla\_monitoring\_instance\_type) | The type and size of the Scylla monitoring instance. | `string` | `"t3.xlarge"` | no |
| <a name="input_scylla_monitoring_lb_access_logs_bucket"></a> [scylla\_monitoring\_lb\_access\_logs\_bucket](#input\_scylla\_monitoring\_lb\_access\_logs\_bucket) | Name of the S3 bucket to store the access logs for the Scylla monitoring load balancer. | `string` | `null` | no |
| <a name="input_scylla_monitoring_lb_access_logs_prefix"></a> [scylla\_monitoring\_lb\_access\_logs\_prefix](#input\_scylla\_monitoring\_lb\_access\_logs\_prefix) | Prefix to use for the access logs for the Scylla monitoring load balancer. | `string` | `null` | no |
| <a name="input_scylla_subnets"></a> [scylla\_subnets](#input\_scylla\_subnets) | A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended. | `list(string)` | `[]` | no |
| <a name="input_system_managed_node_desired_size"></a> [system\_managed\_node\_desired\_size](#input\_system\_managed\_node\_desired\_size) | Desired number of system managed node group instances. | `number` | `1` | no |
| <a name="input_system_managed_node_instance_type"></a> [system\_managed\_node\_instance\_type](#input\_system\_managed\_node\_instance\_type) | Monitoring managed node group instance type. | `string` | `"m5.large"` | no |
| <a name="input_system_managed_node_max_size"></a> [system\_managed\_node\_max\_size](#input\_system\_managed\_node\_max\_size) | Max number of system managed node group instances. | `number` | `2` | no |
| <a name="input_system_managed_node_min_size"></a> [system\_managed\_node\_min\_size](#input\_system\_managed\_node\_min\_size) | Min number of system managed node group instances. | `number` | `1` | no |
| <a name="input_system_node_group_label"></a> [system\_node\_group\_label](#input\_system\_node\_group\_label) | Label applied to system node group | `map(string)` | <pre>{<br/>  "pool": "system-pool"<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "Unreal DDC"<br/>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | String for VPC ID | `string` | n/a | yes |
| <a name="input_worker_managed_node_desired_size"></a> [worker\_managed\_node\_desired\_size](#input\_worker\_managed\_node\_desired\_size) | Desired number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_instance_type"></a> [worker\_managed\_node\_instance\_type](#input\_worker\_managed\_node\_instance\_type) | Worker managed node group instance type. | `string` | `"c5.large"` | no |
| <a name="input_worker_managed_node_max_size"></a> [worker\_managed\_node\_max\_size](#input\_worker\_managed\_node\_max\_size) | Max number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_min_size"></a> [worker\_managed\_node\_min\_size](#input\_worker\_managed\_node\_min\_size) | Min number of worker managed node group instances. | `number` | `0` | no |
| <a name="input_worker_node_group_label"></a> [worker\_node\_group\_label](#input\_worker\_node\_group\_label) | Label applied to worker node group. These will need to be matched in values for taints and tolerations for the worker pod definition. | `map(string)` | <pre>{<br/>  "unreal-cloud-ddc/node-type": "worker"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the EKS Cluster |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Public key for the EKS Cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS Cluster Endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS Cluster |
| <a name="output_external_alb_dns_name"></a> [external\_alb\_dns\_name](#output\_external\_alb\_dns\_name) | DNS endpoint of Application Load Balancer (ALB) |
| <a name="output_external_alb_zone_id"></a> [external\_alb\_zone\_id](#output\_external\_alb\_zone\_id) | Zone ID for internet facing load balancer |
| <a name="output_nvme_node_group_label"></a> [nvme\_node\_group\_label](#output\_nvme\_node\_group\_label) | Label for the NVME node group |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | OIDC provider for the EKS Cluster |
| <a name="output_peer_security_group_id"></a> [peer\_security\_group\_id](#output\_peer\_security\_group\_id) | ID of the Peer Security Group |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | Bucket to be used for the Unreal Cloud DDC assets |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | IPs of the Scylla EC2 instances |
| <a name="output_system_node_group_label"></a> [system\_node\_group\_label](#output\_system\_node\_group\_label) | Label for the System node group |
| <a name="output_worker_node_group_label"></a> [worker\_node\_group\_label](#output\_worker\_node\_group\_label) | Label for the Worker node group |
<!-- END_TF_DOCS -->
