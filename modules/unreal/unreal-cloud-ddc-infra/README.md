<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.38 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.38 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.unreal_cluster_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_cluster.unreal_cloud_ddc_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_identity_provider_config.eks_cluster_oidc_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_identity_provider_config) | resource |
| [aws_eks_node_group.nvme_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_node_group.system_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_node_group.worker_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_instance_profile.scylla_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.monitoring_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.nvme_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scylla_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.worker_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_instance.scylla_ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.nvme_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.system_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.worker_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_route53_record.scylla_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.scylla_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_s3_bucket.unreal_ddc_logging_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.unreal_ddc_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_logging.unreal-log-s3-log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_logging.unreal-s3-log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_public_access_block.unreal_ddc_log_s3_acls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.unreal_ddc_s3_acls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.unreal-s3-bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.unreal-s3-logging-bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_security_group.nvme_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.system_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.worker_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.peer_cidr_blocks_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.peer_cidr_blocks_scylla_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.scylla_to_nvme_group_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.scylla_to_nvme_group_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.scylla_to_worker_group_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.scylla_to_worker_group_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.self_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.self_scylla_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ssm_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ssm_association.scylla_config_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.config_scylla](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_ami.scylla_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ssm_parameter.eks_ami_latest_release](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [tls_certificate.eks_tls_certificate](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eks_cluster_access_cidr"></a> [eks\_cluster\_access\_cidr](#input\_eks\_cluster\_access\_cidr) | List of the CIDR Ranges you want to grant public access to the EKS Cluster. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_nvme_managed_node_desired_size"></a> [nvme\_managed\_node\_desired\_size](#input\_nvme\_managed\_node\_desired\_size) | Desired number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_instance_type"></a> [nvme\_managed\_node\_instance\_type](#input\_nvme\_managed\_node\_instance\_type) | Nvme managed node group instance type | `string` | `"i3en.xlarge"` | no |
| <a name="input_nvme_managed_node_max_size"></a> [nvme\_managed\_node\_max\_size](#input\_nvme\_managed\_node\_max\_size) | Max number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_peer_cidr_blocks"></a> [peer\_cidr\_blocks](#input\_peer\_cidr\_blocks) | The peered cidr blocks you want your vpc to communicate with if you have a multi region ddc. | `list(string)` | `[]` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Private subnets you want scylla and the worker nodes to be installed into. | `list(string)` | `[]` | no |
| <a name="input_scylla_ami_name"></a> [scylla\_ami\_name](#input\_scylla\_ami\_name) | Name of the Scylla AMI to be used to get the AMI ID | `string` | `"ScyllaDB 6.0.1"` | no |
| <a name="input_scylla_architecture"></a> [scylla\_architecture](#input\_scylla\_architecture) | The chip architecture to use when finding the scylla image. Valid | `string` | `"x86_64"` | no |
| <a name="input_scylla_db_storage"></a> [scylla\_db\_storage](#input\_scylla\_db\_storage) | Size of gp3 ebs volumes attached to Scylla DBs | `number` | `100` | no |
| <a name="input_scylla_db_throughput"></a> [scylla\_db\_throughput](#input\_scylla\_db\_throughput) | Throughput of gp3 ebs volumes attached to Scylla DBs | `number` | `200` | no |
| <a name="input_scylla_dns"></a> [scylla\_dns](#input\_scylla\_dns) | The local private dns name that you want Scylla to be queryable on. | `string` | `null` | no |
| <a name="input_scylla_instance_type"></a> [scylla\_instance\_type](#input\_scylla\_instance\_type) | The type and size of the Scylla instance. | `string` | `"i4i.2xlarge"` | no |
| <a name="input_scylla_private_subnets"></a> [scylla\_private\_subnets](#input\_scylla\_private\_subnets) | The subnets you want Scylla to be installed into. Can repeat subnet ids to install into the same subnet/az. This will also determine how many Scylla instances are deployed. | `list(string)` | `[]` | no |
| <a name="input_system_managed_node_desired_size"></a> [system\_managed\_node\_desired\_size](#input\_system\_managed\_node\_desired\_size) | Desired number of monitoring managed node group instances. | `number` | `1` | no |
| <a name="input_system_managed_node_instance_type"></a> [system\_managed\_node\_instance\_type](#input\_system\_managed\_node\_instance\_type) | Monitoring managed node group instance type. | `string` | `"m5.large"` | no |
| <a name="input_system_managed_node_max_size"></a> [system\_managed\_node\_max\_size](#input\_system\_managed\_node\_max\_size) | Max number of monitoring managed node group instances. | `number` | `2` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | String for VPC ID | `string` | n/a | yes |
| <a name="input_worker_managed_node_desired_size"></a> [worker\_managed\_node\_desired\_size](#input\_worker\_managed\_node\_desired\_size) | Desired number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_instance_type"></a> [worker\_managed\_node\_instance\_type](#input\_worker\_managed\_node\_instance\_type) | Worker managed node group instance type. | `string` | `"c5.xlarge"` | no |
| <a name="input_worker_managed_node_max_size"></a> [worker\_managed\_node\_max\_size](#input\_worker\_managed\_node\_max\_size) | Max number of worker managed node group instances. | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | n/a |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | n/a |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | n/a |
| <a name="output_oidc_provider_identity"></a> [oidc\_provider\_identity](#output\_oidc\_provider\_identity) | n/a |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.73.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.77.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.6 |

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
| [aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.nvme_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scylla_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.system_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.worker_node_group_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachments_exclusive.eks_cluster_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.nvme_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.scylla_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.system_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_iam_role_policy_attachments_exclusive.worker_policy_attachement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachments_exclusive) | resource |
| [aws_instance.scylla_ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.nvme_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.system_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.worker_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_s3_bucket.unreal_ddc_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.unreal_ddc_s3_acls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.unreal-s3-bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_security_group.nvme_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.scylla_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.system_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.worker_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_association.scylla_config_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.config_scylla](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_security_group_egress_rule.nvme_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.self_scylla_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ssm_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.system_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.worker_egress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self_ingress_sg_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.scylla_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [tls_certificate.eks_tls_certificate](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eks_cluster_cloudwatch_log_group_prefix"></a> [eks\_cluster\_cloudwatch\_log\_group\_prefix](#input\_eks\_cluster\_cloudwatch\_log\_group\_prefix) | Prefix to be used for the EKS cluster CloudWatch log group. | `string` | `"/aws/eks/unreal-cloud-ddc/cluster"` | no |
| <a name="input_eks_cluster_logging_types"></a> [eks\_cluster\_logging\_types](#input\_eks\_cluster\_logging\_types) | List of EKS cluster log types to be enabled. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_eks_cluster_private_access"></a> [eks\_cluster\_private\_access](#input\_eks\_cluster\_private\_access) | Allows private access of the EKS Control Plane from subnets attached to EKS Cluster | `bool` | `true` | no |
| <a name="input_eks_cluster_public_access"></a> [eks\_cluster\_public\_access](#input\_eks\_cluster\_public\_access) | Allows public access of EKS Control Plane should be used with | `bool` | `false` | no |
| <a name="input_eks_cluster_public_endpoint_access_cidr"></a> [eks\_cluster\_public\_endpoint\_access\_cidr](#input\_eks\_cluster\_public\_endpoint\_access\_cidr) | List of the CIDR Ranges you want to grant public access to the EKS Cluster's public endpoint. | `list(string)` | `null` | no |
| <a name="input_eks_node_group_private_subnets"></a> [eks\_node\_group\_private\_subnets](#input\_eks\_node\_group\_private\_subnets) | A list of private subnets ids you want the EKS nodes to be installed into. | `list(string)` | `[]` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to be used by the EKS cluster. | `string` | `"1.31"` | no |
| <a name="input_name"></a> [name](#input\_name) | Unreal Cloud DDC Workload Name | `string` | `"unreal-cloud-ddc"` | no |
| <a name="input_nvme_managed_node_desired_size"></a> [nvme\_managed\_node\_desired\_size](#input\_nvme\_managed\_node\_desired\_size) | Desired number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_instance_type"></a> [nvme\_managed\_node\_instance\_type](#input\_nvme\_managed\_node\_instance\_type) | Nvme managed node group instance type | `string` | `"i3en.large"` | no |
| <a name="input_nvme_managed_node_max_size"></a> [nvme\_managed\_node\_max\_size](#input\_nvme\_managed\_node\_max\_size) | Max number of nvme managed node group instances | `number` | `2` | no |
| <a name="input_nvme_managed_node_min_size"></a> [nvme\_managed\_node\_min\_size](#input\_nvme\_managed\_node\_min\_size) | Min number of nvme managed node group instances | `number` | `1` | no |
| <a name="input_scylla_ami_name"></a> [scylla\_ami\_name](#input\_scylla\_ami\_name) | Name of the Scylla AMI to be used to get the AMI ID | `string` | `"ScyllaDB 6.0.1"` | no |
| <a name="input_scylla_architecture"></a> [scylla\_architecture](#input\_scylla\_architecture) | The chip architecture to use when finding the scylla image. Valid | `string` | `"x86_64"` | no |
| <a name="input_scylla_db_storage"></a> [scylla\_db\_storage](#input\_scylla\_db\_storage) | Size of gp3 ebs volumes attached to Scylla DBs | `number` | `100` | no |
| <a name="input_scylla_db_throughput"></a> [scylla\_db\_throughput](#input\_scylla\_db\_throughput) | Throughput of gp3 ebs volumes attached to Scylla DBs | `number` | `200` | no |
| <a name="input_scylla_instance_type"></a> [scylla\_instance\_type](#input\_scylla\_instance\_type) | The type and size of the Scylla instance. | `string` | `"i4i.2xlarge"` | no |
| <a name="input_scylla_private_subnets"></a> [scylla\_private\_subnets](#input\_scylla\_private\_subnets) | A list of private subnets ids you want Scylla to be installed into. | `list(string)` | `[]` | no |
| <a name="input_system_managed_node_desired_size"></a> [system\_managed\_node\_desired\_size](#input\_system\_managed\_node\_desired\_size) | Desired number of system managed node group instances. | `number` | `1` | no |
| <a name="input_system_managed_node_instance_type"></a> [system\_managed\_node\_instance\_type](#input\_system\_managed\_node\_instance\_type) | Monitoring managed node group instance type. | `string` | `"m5.large"` | no |
| <a name="input_system_managed_node_max_size"></a> [system\_managed\_node\_max\_size](#input\_system\_managed\_node\_max\_size) | Max number of system managed node group instances. | `number` | `2` | no |
| <a name="input_system_managed_node_min_size"></a> [system\_managed\_node\_min\_size](#input\_system\_managed\_node\_min\_size) | Min number of system managed node group instances. | `number` | `1` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | String for VPC ID | `string` | n/a | yes |
| <a name="input_worker_managed_node_desired_size"></a> [worker\_managed\_node\_desired\_size](#input\_worker\_managed\_node\_desired\_size) | Desired number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_instance_type"></a> [worker\_managed\_node\_instance\_type](#input\_worker\_managed\_node\_instance\_type) | Worker managed node group instance type. | `string` | `"c5.large"` | no |
| <a name="input_worker_managed_node_max_size"></a> [worker\_managed\_node\_max\_size](#input\_worker\_managed\_node\_max\_size) | Max number of worker managed node group instances. | `number` | `1` | no |
| <a name="input_worker_managed_node_min_size"></a> [worker\_managed\_node\_min\_size](#input\_worker\_managed\_node\_min\_size) | Min number of worker managed node group instances. | `number` | `0` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the EKS Cluster |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Public key for the EKS Cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS Cluster Endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS Cluster |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | OIDC provider for the EKS Cluster |
| <a name="output_peer_security_group_id"></a> [peer\_security\_group\_id](#output\_peer\_security\_group\_id) | ID of the Peer Security Group |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | Bucket to be used for the Unreal Cloud DDC assets |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | IPs of the Scylla EC2 instances |
<!-- END_TF_DOCS -->
