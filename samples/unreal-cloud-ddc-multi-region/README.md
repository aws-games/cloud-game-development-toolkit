# Unreal Cloud DDC Multi Region

The Unreal Cloud DDC Multi Region is a comprehensive solution that leverages several AWS services to create a robust and efficient data caching system. It uses a well-designed Virtual Private Cloud (VPC) to ensure network isolation and security. The solution employs an Amazon Elastic Kubernetes Service (EKS) Cluster with Node Groups to manage and orchestrate containerized applications.

At the heart of the system is an instance of ScyllaDB, a high-performance NoSQL database, running on specially optimized Amazon EC2 instances. The Unreal Cloud Derived Data Cache Container is managed by Helm, a package manager for Kubernetes, and uses Amazon S3 for durable storage.


### Predeployment - Set Up Github Content Repository Credentials

The [Unreal Cloud DDC Inter Cluster module](../modules/unreal/unreal-cloud-ddc-intra-cluster) utilizes a pull through cache to access the [Unreal Cloud DDC image](https://github.com/orgs/EpicGames/packages/container/package/unreal-cloud-ddc). This requires a secret in [Secrets Manager](https://aws.amazon.com/secrets-manager/) in each region. The secret needs to be prefixed with ````ecr-pullthroughcache/````. Additionally, the secret is required to be in the following format:
```json
{
  "username":"GITHUB-USER-NAME-PLACEHOLDER",
  "accessToken":"GITHUB-ACCESS-TOKEN-PLACEHOLDER"
}
```

## Deployment

Once you've completed the prerequisites and set your variables, you can deploy the solution by running:

``` bash
terraform apply
```

The deployment can take close to 30 minutes. Creating the EKS Node Groups and EKS Cluster take around 20 minutes to fully deploy.
## Postdeployment
The sample deploys a Route53 dns record that you can use to access your Unreal DDC cluster. This record points to an NLB which may take more time to become fully available when the deployment is complete. You can view the provisioning status of this NLB on the EC2 load balncing screen.

The Unreal Cloud DDC module creates a Service Account and valid bearer token for testing. This bearer token is stored in AWS Secrets Manager and is replicated to your second AWS region. The ARN of this secret is provided as a Terraform output (`"unreal_cloud_ddc_bearer_token_arn"`) on the console following deployment. To fetch the bearer token you can use the aws CLI:
```bash
aws secretsmanager get-secret-value --secret-id <"unreal_cloud_ddc_bearer_token_arn">
```

To validate you can put an object you can run:
```bash
curl http://<unreal_ddc_url>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa -X PUT --data 'test' -H 'content-type: application/octet-stream' -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' -i -H 'Authorization: ServiceAccount <secret-manager-token>'
```
After running this you should get a response that looks as the following:
```
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 29 Jan 2025 19:15:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server-Timing: blob.put.FileSystemStore;dur=0.1451;desc="PUT to store: 'FileSystemStore'",blob.put.AmazonS3Store;dur=267.0449;desc="PUT to store: 'AmazonS3Store'",blob.get-metadata.FileSystemStore;dur=0.0406;desc="Blob GET Metadata from: 'FileSystemStore'",ref.finalize;dur=7.1407;desc="Finalizing the ref",ref.put;dur=25.2064;desc="Inserting ref"

{"needs":[]}%
```

You can then access the same chunk with the following command:
```bash
curl http://<unreal_ddc_url>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json -i -H 'Authorization: ServiceAccount <unreal-cloud-ddc-bearer-token-multi-region>'
```

The response should look like the following:
```
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 29 Jan 2025 19:16:46 GMT
Content-Type: application/json
Content-Length: 66
Connection: keep-alive
X-Jupiter-IoHash: 7D873DCC262F62FBAA871FE61B2B52D715A1171E
X-Jupiter-LastAccess: 01/29/2025 19:16:46
Server-Timing: ref.get;dur=0.0299;desc="Fetching Ref from DB"

{"RawHash":"4878ca0425c739fa427f7eda20fe845f6b2e46ba","RawSize":4}%
```
For a more comprehensive test of your deployment, we recommend using the [bench marking tools](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Benchmarks). To do so we used a x2idn.32xlarge as it matched Epic's benchmarking instance to test their configuration.

With the benchmarking tools we ran the following command after compiling the docker image:
```bash
docker run --network host jupiter_benchmark --seed --seed-remote --host http://<unreal_ddc_url> --namespace ddc \
--header="Authorization: ServiceAccount <unreal-cloud-ddc-bearer-token-multi-region>" all
```
Just a note here, you will have to specify the namespace to be DDC as the token only has access to that namespace.

**It is recommended that if you are using this in a production capacity you change the authentication mode from Service Account to Bearer and use an IDP to authenticate and TLS termination.**


This sample also deploys a ScyllaDB monitoring stack, enabling real-time insights into the status and performance of your ScyllaDB nodes. The monitoring stack includes Prometheus for metrics collection, Alertmanager for handling alerts, and Grafana for visualization. You can access the Grafana dashboard by using the `"monitoring_url"` provided in the sample outputs. To learn more about the ScyllaDB monitoring stack, refer to the [ScyllaDB Monitoring Stack Documentation](https://monitoring.docs.scylladb.com/branch-4.10/intro.html).

## Deletion
For the cleanest deletion, it is best to first do a targeted destroy for the `module.unreal_cloud_ddc_intra_cluster_region_1` and `module.unreal_cloud_ddc_intra_cluster_region_2`.
```bash
terraform destroy -target module.unreal_cloud_ddc_intra_cluster_region_1 -target module.unreal_cloud_ddc_intra_cluster_region_2
```
Note: If the previous command fails the first time with an error for context deadline exceeded, run the command again.

Once the resources are successfully destroyed, you can do a full destroy.
```bash
terraform destroy
```


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=6.2.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.26.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.17.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.5 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.24.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >=3.2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.5.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.2.0 |
| <a name="provider_awscc.region-1"></a> [awscc.region-1](#provider\_awscc.region-1) | 1.51.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc_infra_region_1"></a> [unreal\_cloud\_ddc\_infra\_region\_1](#module\_unreal\_cloud\_ddc\_infra\_region\_1) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_infra_region_2"></a> [unreal\_cloud\_ddc\_infra\_region\_2](#module\_unreal\_cloud\_ddc\_infra\_region\_2) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster_region_1"></a> [unreal\_cloud\_ddc\_intra\_cluster\_region\_1](#module\_unreal\_cloud\_ddc\_intra\_cluster\_region\_1) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster_region_2"></a> [unreal\_cloud\_ddc\_intra\_cluster\_region\_2](#module\_unreal\_cloud\_ddc\_intra\_cluster\_region\_2) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_vpc_region_1"></a> [unreal\_cloud\_ddc\_vpc\_region\_1](#module\_unreal\_cloud\_ddc\_vpc\_region\_1) | ./vpc | n/a |
| <a name="module_unreal_cloud_ddc_vpc_region_2"></a> [unreal\_cloud\_ddc\_vpc\_region\_2](#module\_unreal\_cloud\_ddc\_vpc\_region\_2) | ./vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route.vpc_region_1_to_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.vpc_region_2_to_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.scylla_monitoring_cert_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_association.unreal_cloud_ddc_scylla_db_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.unreal_cloud_ddc_scylla_update_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_peering_connection.vpc_connection_region_1_to_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |
| [aws_vpc_peering_connection_accepter.region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_accepter) | resource |
| [aws_vpc_peering_connection_options.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_options) | resource |
| [aws_vpc_peering_connection_options.requester](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_options) | resource |
| [aws_vpc_security_group_egress_rule.unreal_ddc_load_balancer_egress_sg_rules_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_ddc_load_balancer_egress_sg_rules_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_db_region_1_to_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_db_region_2_to_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_1_to_lb_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_1_to_lb_region_2_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_2_to_lb_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_2_to_lb_region_1_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http2_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http2_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_https_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_https_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [awscc_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_availability_zones.available_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_availability_zones.available_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_authorization_token.token_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_ecr_authorization_token.token_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_region.region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [http_http.public_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_my_ip"></a> [allow\_my\_ip](#input\_allow\_my\_ip) | Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers | `bool` | `true` | no |
| <a name="input_github_credential_arn_region_1"></a> [github\_credential\_arn\_region\_1](#input\_github\_credential\_arn\_region\_1) | ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub | `string` | n/a | yes |
| <a name="input_github_credential_arn_region_2"></a> [github\_credential\_arn\_region\_2](#input\_github\_credential\_arn\_region\_2) | ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | List of regions to deploy the solution | `list(string)` | <pre>[<br/>  "us-west-2",<br/>  "us-east-2"<br/>]</pre> | no |
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_monitoring_url_region_1"></a> [monitoring\_url\_region\_1](#output\_monitoring\_url\_region\_1) | n/a |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | n/a |
| <a name="output_unreal_cloud_ddc_bearer_token_arn"></a> [unreal\_cloud\_ddc\_bearer\_token\_arn](#output\_unreal\_cloud\_ddc\_bearer\_token\_arn) | n/a |
| <a name="output_unreal_ddc_url"></a> [unreal\_ddc\_url](#output\_unreal\_ddc\_url) | n/a |
<!-- END_TF_DOCS -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=6.2.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.26.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.17.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.5 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.24.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >=3.2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.5.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.2.0 |
| <a name="provider_awscc.region-1"></a> [awscc.region-1](#provider\_awscc.region-1) | 1.51.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc_infra_region_1"></a> [unreal\_cloud\_ddc\_infra\_region\_1](#module\_unreal\_cloud\_ddc\_infra\_region\_1) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_infra_region_2"></a> [unreal\_cloud\_ddc\_infra\_region\_2](#module\_unreal\_cloud\_ddc\_infra\_region\_2) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster_region_1"></a> [unreal\_cloud\_ddc\_intra\_cluster\_region\_1](#module\_unreal\_cloud\_ddc\_intra\_cluster\_region\_1) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster_region_2"></a> [unreal\_cloud\_ddc\_intra\_cluster\_region\_2](#module\_unreal\_cloud\_ddc\_intra\_cluster\_region\_2) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_vpc_region_1"></a> [unreal\_cloud\_ddc\_vpc\_region\_1](#module\_unreal\_cloud\_ddc\_vpc\_region\_1) | ./vpc | n/a |
| <a name="module_unreal_cloud_ddc_vpc_region_2"></a> [unreal\_cloud\_ddc\_vpc\_region\_2](#module\_unreal\_cloud\_ddc\_vpc\_region\_2) | ./vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route.vpc_region_1_to_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.vpc_region_2_to_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.scylla_monitoring_cert_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_peering_connection.vpc_connection_region_1_to_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |
| [aws_vpc_peering_connection_accepter.region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_accepter) | resource |
| [aws_vpc_peering_connection_options.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_options) | resource |
| [aws_vpc_peering_connection_options.requester](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_options) | resource |
| [aws_vpc_security_group_egress_rule.unreal_ddc_load_balancer_egress_sg_rules_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_ddc_load_balancer_egress_sg_rules_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_db_region_1_to_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_db_region_2_to_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_1_to_lb_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_1_to_lb_region_2_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_2_to_lb_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_2_to_lb_region_1_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http2_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http2_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_https_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_https_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [awscc_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_availability_zones.available_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_availability_zones.available_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_authorization_token.token_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_ecr_authorization_token.token_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_region.region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [http_http.public_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_my_ip"></a> [allow\_my\_ip](#input\_allow\_my\_ip) | Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers | `bool` | `true` | no |
| <a name="input_github_credential_arn_region_1"></a> [github\_credential\_arn\_region\_1](#input\_github\_credential\_arn\_region\_1) | Github Credential ARN | `string` | n/a | yes |
| <a name="input_github_credential_arn_region_2"></a> [github\_credential\_arn\_region\_2](#input\_github\_credential\_arn\_region\_2) | Github Credential ARN | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | List of regions to deploy the solution | `list(string)` | <pre>[<br/>  "us-west-2",<br/>  "us-east-2"<br/>]</pre> | no |
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_monitoring_url_region_1"></a> [monitoring\_url\_region\_1](#output\_monitoring\_url\_region\_1) | n/a |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | n/a |
| <a name="output_unreal_cloud_ddc_bearer_token_arn"></a> [unreal\_cloud\_ddc\_bearer\_token\_arn](#output\_unreal\_cloud\_ddc\_bearer\_token\_arn) | n/a |
| <a name="output_unreal_ddc_url"></a> [unreal\_ddc\_url](#output\_unreal\_ddc\_url) | n/a |
<!-- END_TF_DOCS -->
