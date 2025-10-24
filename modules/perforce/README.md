# Perforce on AWS Terraform Module

For a video walkthrough demonstrating how to use this module, see this YouTube Video:

[![Watch the video](https://img.youtube.com/vi/4UEoX-oP918/0.jpg)](https://youtu.be/4UEoX-oP918)

## Features

- Dynamic creation and configuration of [P4 Server (formerly Helix Core)](https://www.perforce.com/products/helix-core)
- Dynamic creation and configuration
  of [P4 Code Review (formerly Helix Swarm)](https://www.perforce.com/products/helix-swarm)
- Dynamic creation and configuration
  of [P4Auth (formerly Helix Authentication Service)](https://help.perforce.com/helix-core/integrations-plugins/helix-auth-svc/current/Content/HAS/overview-of-has.html)

## Architecture

### Full example using AWS Route53 Public Hosted Zone

<!-- ![perforce-complete-arch](https://github.com/aws-games/cloud-game-development-toolkit/raw/main/docs/media/diagrams/perforce-arch-cdg-toolkit-terraform-aws-perforce-full-arch-route53-dns.png) -->
![perforce-complete-arch](./assets/media/diagrams/perforce-arch-cdg-toolkit-terraform-aws-perforce-full-arch-route53-dns.png)

## Prerequisites

- **Existing DNS Configured**
    - To use this module, you must have an existing domain and related DNS configuration. The example at
      `/examples/create-resources-complete` demonstrates how to provision resources while using Amazon Route53 (
      recommended) as the DNS provider. This will make deployment and management easier.
    - You may optionally use a 3rd party DNS provider, however you must create records in your DNS provider to route to
      the endpoints that you will create for each component when using the module (e.g. `perforce.example.com`,
      `review.perforce.example.com`, `auth.perforce.example.com`). The module has variables that you can use to
      customize the subdomains for the services (P4 Server, P4 Code Review, P4Auth), however if not set, the defaults
      mentioned above will be used. Ensure you create these records to allow users to connect to the services once
      provisioned in AWS.
    - **Note:** When using either of the two options mentioned above, by default the module will create a **Route53
      Private Hosted Zone**. This is used for internal communication and routing of traffic between P4 Server, P4 Code
      Review, and P4Auth.
- **SSL TLS Certificate**
    - You must have an existing SSL/TLS certificate, or create one during deployment alongside the other resources the
      module will create. This is used to provide secure connectivity to the Perforce resources that will be running in
      AWS. The certificate will be used by the Application Load Balancer (ALB) that the module will deploy for you. If
      using Amazon Route53, see the example at `/examples/create-resources-complete` to see how to create the related
      certificate in Amazon Certificate Manager (ACM). Using a Route53 as the DNS provider makes this process a bit
      easier, as ACM can automatically create the required CNAME records needed for DNS validation (a process required
      to verify DNS ownership) if you are also using Amazon Route53.
    - If using an 3rd party DNS provider, you must add these CNAME records manually (in addition to the other records
      mentioned above for general DNS purposes). If you would prefer to use a 3rd party to create the SSL/TLS
      certificate, the module allows you to import this into ACM to be used for the other components that will be
      deployed (such as the internal ALB). You may also use Email validation to validate DNS ownership.

- **Existing Perforce Amazon Machine Image (AMI)**
    - As mentioned in the architecture, an Amazon EC2 instance is used for the P4 Server, and this instance must be be
      provisioned using an AMI that is configured for Perforce. To expedite this process, we have
      sample [HashiCorp Packer](https://www.packer.io/) templates provided in
      the [AWS Cloud Game Development Toolkit repository](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/assets/packer/perforce/p4-server)
      that you can use to create a Perforce AMI in your AWS Account. **Note:** You must also reference the
      `p4_configure.sh` and `p4_setup.sh` files that are in this directory, as these are used to configure the P4 Commit
      Server. These are already referenced in the `perforce_arm64.pkr.hcl` and `perforce_x86.pkr.hcl` packer templates
      that are available for use.

## Examples

For example configurations, please see the [examples](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce/examples).

## Deployment Instructions

1. Create the Perforce AMI in your AWS account using one of the supplied Packer templates. Ensure you use the Packer
   template that aligns with the architecture type (e.g. arm64) of the EC2 instance you wish to create. On the Terraform
   side, you may also set this using the `instance_architecture` variable. Ensure your `instance_type` is supported for
   your desired `instance_architecture`. For a full list of this mapping, see
   the [AWS Docs for EC2 Naming Conventions](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html).
   You can also use the interactive chart on Instances by [Vantage](https://instances.vantage.sh/).

**IMPORTANT:** By default, the module will create compute resources with `x86_64` architecture. Ensure you use this
corresponding Packer template unless you set the `instance_architecture` variable to `arm64` or the deployment will
fail. Also, unless explicitly set, the Packer templates are configured to build the AMI in whichever AWS region your
current credentials are set to (e.g. `us-east-1`) which will also be the same AWS region your Terraform resources are
deployed to unless you explicitly set this. Ensure the AMI is available in the AWS Region you will use the module to
deploy resources into.

To deploy the template (`x86_64`) with Packer, do the following (while in the `/assets/perforce/p4-server directory`)

```sh
packer init perforce_x86.pkr.hcl
```

```sh
packer validate perforce_x86.pkr.hcl
```

```sh
packer build perforce_x86.pkr.hcl
```

2. Reference your existing fully qualified domain name within each related Perforce service you would like to
   provision (e.g. `p4_server_config`, `p4_auth_config`, `p4_code_review_config`) using the
   `fully_qualified_domain_name` variable. We recommend abstracting this t a local value such as
   `local.fully_qualified_domain_name` to ensure this value is consistent across the modules. The module will
   automatically configure Perforce using default subdomains of `perforce.<your-domain-name>` for P4 Server,
   `auth.perforce.<your-domain-name` for P4 Auth, and `review.perforce.<your-domain-name` for P4 Code Review. You will
   also need to create DNS records that will route traffic destined for these domains in the following manner:
    - Traffic destined for **P4 Server** will need to route to the **Elastic IP (EIP)** that is associated with the P4
      Server EC2 Instance. By default, this will be using a subdomain named `perforce`. In your DNS provider, create an
      A record named `perforce.<your-domain-name>` and have it route traffic to the EIP. This value is available as a
      Terraform output for your convenience.
    - Traffic destined for `*.perforce.<your-domain-name>` will need to route to the DNS name of the Network Load
      Balancer (NLB) that the module creates. In your DNS provider, create a CNAME record that routes traffic to NLB.
      This value is available as a Terraform output for your convenience.
    - **Note:** If using Amazon Route53 as your DNS provider, the example at  `/examples/create-resources-complete`
      shows you have to leverage Terraform to automatically create these records in an existing Route53 Public Hosted
      Zone, as well as how to create the certificate in Amazon Certificate Manager (ACM).

3. Make any other modifications as desired (such as referencing existing VPC resources) and run `terraform init` to
   initialize Terraform in the current working directory, `terraform plan` to create and validate the execution plan of
   the resources that will be created, and finally `terraform apply` to create the resources in your AWS Account.
4. Once the resources have finished provisioning successfully, you will need to modify your inbound Security Group Rules
   on the P4 Commit Server Instance to allow TCP traffic from your public IP on port 1666 (the perforce default port).
   This is necessary to allow your local machine(s) to connect to the P4 Commit Server. Optionally, you can pass in an entire security group to also add to the resource. The [complete example](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce/examples/create-resources-complete) demonstrates how to use the `existing_security_groups` variable to accomplish this.
    - **Note:** You may use other means to allow traffic to reach this EC2 Instance (Customer-managed prefix list, VPN
      to the VPC that the instance is running in, etc.) but regardless, it is essential that you have the security group
      rules set configured correctly to allow access.
5. Next, modify your inbound Security Group rules for the Perforce Network Load Balancer (NLB) to allow traffic from
   HTTPS (port 443) from your public IP address/ This is to provide access to the P4 Code Review and P4Auth services
   that are running behind the Application Load Balancer (ALB). Optionally, you can pass in an entire security group to also add to the resource. The [complete example](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce/examples/create-resources-complete) demonstrates how to use the `existing_security_groups` variable to accomplish this.
    - **Note:** You may use other means to allow traffic to reach this the Network Load Balancer (Customer-managed
      prefix list, VPN to the VPC that the instance is running in, etc.) but regardless, it is essential that you have
      the security group rules set configured correctly to allow access.
    - **IMPORTANT:** Ensure your networking configuration is correct, especially in terms of any public or private
      subnets that you reference. This is very important for the internal routing between the P4 resources, as well as
      the related Security Groups. Failure to set these correctly may cause a variety of connectivity issues such as web
      pages not loading, NLB health checks failing, etc.
6. Use the provided Terraform outputs to quickly find the URL for P4Auth, P4 Code Review. If you haven't modified the
   default values, relevant values for the P4 Server default username/password, and the P4 Code Review default
   username/password were created for you and are stored in AWS Secrets Manager.
7. In P4V, use the url of `ssl:<your-supplied-root-domain>:1666` and the username and password stored in AWS Secrets
   Manager to gain access to the commit server.
8. At this point, you should be able to access your P4 Commit Server (P4), and visit the URLs for P4 Code Review (P4
   Code Review) and P4Auth (P4Auth).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.6.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | 1.50.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.5.3 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.6.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_p4_auth"></a> [p4\_auth](#module\_p4\_auth) | ./modules/p4-auth | n/a |
| <a name="module_p4_code_review"></a> [p4\_code\_review](#module\_p4\_code\_review) | ./modules/p4-code-review | n/a |
| <a name="module_p4_server"></a> [p4\_server](#module\_p4\_server) | ./modules/p4-server | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ecs_cluster.perforce_web_services_cluster](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.providers](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_lb.perforce](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb) | resource |
| [aws_lb.perforce_web_services](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb) | resource |
| [aws_lb_listener.perforce](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener.perforce_web_services](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener.perforce_web_services_http_listener](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.p4_code_review](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.perforce_p4_auth](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.perforce](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.perforce](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/lb_target_group_attachment) | resource |
| [aws_route53_record.internal_p4_server](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route53_record.internal_perforce_web_services](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route53_zone.perforce_private_hosted_zone](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_zone) | resource |
| [aws_s3_bucket.shared_lb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.shared_access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.shared_lb_access_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/s3_bucket_policy) | resource |
| [aws_security_group.perforce_network_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_security_group.perforce_web_services_alb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.p4_code_review_outbound_to_p4_server](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.perforce_alb_outbound_to_p4_auth](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.perforce_alb_outbound_to_p4_code_review](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.perforce_nlb_outbound_to_perforce_web_services_alb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_auth_inbound_from_perforce_web_services_alb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_code_review_inbound_from_perforce_web_services_alb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_server_inbound_from_p4_code_review](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.perforce_web_services_inbound_from_p4_server](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.perforce_web_services_inbound_from_perforce_nlb](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [null_resource.parent_module_certificate](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [random_string.shared_lb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/string) | resource |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.shared_lb_access_logs_bucket_lb_write](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The ARN of the ACM certificate to be used with the HTTPS listener for the NLB. | `string` | `null` | no |
| <a name="input_create_default_sgs"></a> [create\_default\_sgs](#input\_create\_default\_sgs) | Whether to create default security groups for the Perforce resources. | `bool` | `true` | no |
| <a name="input_create_route53_private_hosted_zone"></a> [create\_route53\_private\_hosted\_zone](#input\_create\_route53\_private\_hosted\_zone) | Whether to create a private Route53 Hosted Zone for the Perforce resources. This private hosted zone is used for internal communication between the P4 Server, P4 Auth Service, and P4 Code Review Service. | `bool` | `true` | no |
| <a name="input_create_shared_application_load_balancer"></a> [create\_shared\_application\_load\_balancer](#input\_create\_shared\_application\_load\_balancer) | Whether to create a shared Application Load Balancer for the Perforce resources. | `bool` | `true` | no |
| <a name="input_create_shared_network_load_balancer"></a> [create\_shared\_network\_load\_balancer](#input\_create\_shared\_network\_load\_balancer) | Whether to create a shared Network Load Balancer for the Perforce resources. | `bool` | `true` | no |
| <a name="input_enable_shared_alb_deletion_protection"></a> [enable\_shared\_alb\_deletion\_protection](#input\_enable\_shared\_alb\_deletion\_protection) | Enables deletion protection for the shared Application Load Balancer for the Perforce resources. | `bool` | `false` | no |
| <a name="input_enable_shared_lb_access_logs"></a> [enable\_shared\_lb\_access\_logs](#input\_enable\_shared\_lb\_access\_logs) | Enables access logging for both the shared NLB and shared ALB. Defaults to false. | `bool` | `false` | no |
| <a name="input_existing_ecs_cluster_name"></a> [existing\_ecs\_cluster\_name](#input\_existing\_ecs\_cluster\_name) | The name of an existing ECS cluster to use for the Perforce server. If omitted a new cluster will be created. | `string` | `null` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the shared network load balancer. | `list(string)` | `[]` | no |
| <a name="input_p4_auth_config"></a> [p4\_auth\_config](#input\_p4\_auth\_config) | # General<br/>    name: "The string including in the naming of resources related to P4Auth. Default is 'p4-auth'."<br/><br/>    project\_prefix : "The project prefix for the P4Auth service. Default is 'cgd'."<br/><br/>    environment : "The environment where the P4Auth service will be deployed. Default is 'dev'."<br/><br/>    enable\_web\_based\_administration: "Whether to de enable web based administration. Default is 'true'."<br/><br/>    debug : "Whether to enable debug mode for the P4Auth service. Default is 'false'."<br/><br/>    fully\_qualified\_domain\_name : "The FQDN for the P4Auth Service. This is used for the P4Auth's Perforce configuration."<br/><br/><br/>    # Compute<br/>    cluster\_name : "The name of the ECS cluster where the P4Auth service will be deployed. Cluster is not created if this variable is null."<br/><br/>    container\_name : "The name of the P4Auth service container. Default is 'p4-auth-container'."<br/><br/>    container\_port : "The port on which the P4Auth service will be listening. Default is '3000'."<br/><br/>    container\_cpu : "The number of CPU units to reserve for the P4Auth service container. Default is '1024'."<br/><br/>    container\_memory : "The number of CPU units to reserve for the P4Auth service container. Default is '4096'."<br/><br/>    pd4\_port : "The full URL you will use to access the P4 Depot in clients such P4V and P4Admin. Note, this typically starts with 'ssl:' and ends with the default port of ':1666'."<br/><br/><br/>    # Storage & Logging<br/>    cloudwatch\_log\_retention\_in\_days : "The number of days to retain the P4Auth service logs in CloudWatch. Default is 365 days."<br/><br/><br/>    # Networking<br/>    create\_defaults\_sgs : "Whether to create default security groups for the P4Auth service."<br/><br/>    internal : "Set this flag to true if you do not want the P4Auth service to have a public IP."<br/><br/>    create\_default\_role : "Whether to create the P4Auth default IAM Role. Default is set to true."<br/><br/>    custom\_role : "ARN of a custom IAM Role you wish to use with P4Auth."<br/><br/>    admin\_username\_secret\_arn : "Optionally provide the ARN of an AWS Secret for the P4Auth Administrator username."<br/><br/>    admin\_password\_secret\_arn : "Optionally provide the ARN of an AWS Secret for the P4Auth Administrator password."<br/><br/><br/>    # - SCIM -<br/>    p4d\_super\_user\_arn : "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the super user username for p4d."<br/><br/>    p4d\_super\_user\_password\_arn : "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the super user password for p4d."<br/><br/>    scim\_bearer\_token\_arn : "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the bearer token." | <pre>object({<br/>    # - General -<br/>    name                            = optional(string, "p4-auth")<br/>    project_prefix                  = optional(string, "cgd")<br/>    environment                     = optional(string, "dev")<br/>    enable_web_based_administration = optional(bool, true)<br/>    debug                           = optional(bool, false)<br/>    fully_qualified_domain_name     = string<br/><br/>    # - Compute -<br/>    container_name   = optional(string, "p4-auth-container")<br/>    container_port   = optional(number, 3000)<br/>    container_cpu    = optional(number, 1024)<br/>    container_memory = optional(number, 4096)<br/>    p4d_port         = optional(string, null)<br/><br/>    # - Storage & Logging -<br/>    cloudwatch_log_retention_in_days = optional(number, 365)<br/><br/>    # - Networking & Security -<br/>    service_subnets          = optional(list(string), null)<br/>    create_default_sgs       = optional(bool, true)<br/>    existing_security_groups = optional(list(string), [])<br/>    internal                 = optional(bool, false)<br/><br/>    certificate_arn           = optional(string, null)<br/>    create_default_role       = optional(bool, true)<br/>    custom_role               = optional(string, null)<br/>    admin_username_secret_arn = optional(string, null)<br/>    admin_password_secret_arn = optional(string, null)<br/><br/>    # SCIM<br/>    p4d_super_user_arn          = optional(string, null)<br/>    p4d_super_user_password_arn = optional(string, null)<br/>    scim_bearer_token_arn       = optional(string, null)<br/>  })</pre> | `null` | no |
| <a name="input_p4_code_review_config"></a> [p4\_code\_review\_config](#input\_p4\_code\_review\_config) | # General<br/>    name: "The string including in the naming of resources related to P4 Code Review. Default is 'p4-code-review'."<br/><br/>    project\_prefix : "The project prefix for the P4 Code Review service. Default is 'cgd'."<br/><br/>    environment : "The environment where the P4 Code Review service will be deployed. Default is 'dev'."<br/><br/>    debug : "Whether to enable debug mode for the P4 Code Review service. Default is 'false'."<br/><br/>    fully\_qualified\_domain\_name : "The FQDN for the P4 Code Review Service. This is used for the P4 Code Review's Perforce configuration."<br/><br/><br/>    # Compute<br/>    container\_name : "The name of the P4 Code Review service container. Default is 'p4-code-review-container'."<br/><br/>    container\_port : "The port on which the P4 Code Review service will be listening. Default is '3000'."<br/><br/>    container\_cpu : "The number of CPU units to reserve for the P4 Code Review service container. Default is '1024'."<br/><br/>    container\_memory : "The number of CPU units to reserve for the P4 Code Review service container. Default is '4096'."<br/><br/>    pd4\_port : "The full URL you will use to access the P4 Depot in clients such P4V and P4Admin. Note, this typically starts with 'ssl:' and ends with the default port of ':1666'."<br/><br/>    p4charset : "The P4CHARSET environment variable to set in the P4 Code Review container."<br/><br/>    existing\_redis\_connection : "The existing Redis connection for the P4 Code Review service."<br/><br/><br/>    # Storage & Logging<br/>    cloudwatch\_log\_retention\_in\_days : "The number of days to retain the P4 Code Review service logs in CloudWatch. Default is 365 days."<br/><br/><br/>    # Networking & Security<br/>    create\_default\_sgs : "Whether to create default security groups for the P4 Code Review service."<br/><br/>    internal : "Set this flag to true if you do not want the P4 Code Review service to have a public IP."<br/><br/>    create\_default\_role : "Whether to create the P4 Code Review default IAM Role. Default is set to true."<br/><br/>    custom\_role : "ARN of a custom IAM Role you wish to use with P4 Code Review."<br/><br/>    super\_user\_password\_secret\_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review Administrator username."<br/><br/>    super\_user\_username\_secret\_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review Administrator password."<br/><br/>    p4d\_p4\_code\_review\_user\_secret\_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review user's username."<br/><br/>    p4d\_p4\_code\_review\_password\_secret\_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review user's password."<br/><br/>    p4d\_p4\_code\_review\_user\_password\_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review user's password."<br/><br/>    enable\_sso : "Whether to enable SSO for the P4 Code Review service. Default is set to false."<br/><br/><br/>    # Caching<br/>    elasticache\_node\_count : "The number of Elasticache nodes to create for the P4 Code Review service. Default is '1'."<br/><br/>    elasticache\_node\_type : "The type of Elasticache node to create for the P4 Code Review service. Default is 'cache.t4g.micro'." | <pre>object({<br/>    # General<br/>    name                        = optional(string, "p4-code-review")<br/>    project_prefix              = optional(string, "cgd")<br/>    environment                 = optional(string, "dev")<br/>    debug                       = optional(bool, false)<br/>    fully_qualified_domain_name = string<br/><br/>    # Compute<br/>    container_name   = optional(string, "p4-code-review-container")<br/>    container_port   = optional(number, 80)<br/>    container_cpu    = optional(number, 1024)<br/>    container_memory = optional(number, 4096)<br/>    p4d_port         = optional(string, null)<br/>    p4charset        = optional(string, null)<br/>    existing_redis_connection = optional(object({<br/>      host = string<br/>      port = number<br/>    }), null)<br/><br/>    # Storage & Logging<br/>    cloudwatch_log_retention_in_days = optional(number, 365)<br/><br/>    # Networking & Security<br/>    create_default_sgs       = optional(bool, true)<br/>    existing_security_groups = optional(list(string), [])<br/>    internal                 = optional(bool, false)<br/>    service_subnets          = optional(list(string), null)<br/><br/>    create_default_role = optional(bool, true)<br/>    custom_role         = optional(string, null)<br/><br/>    super_user_password_secret_arn          = optional(string, null)<br/>    super_user_username_secret_arn          = optional(string, null)<br/>    p4_code_review_user_password_secret_arn = optional(string, null)<br/>    p4_code_review_user_username_secret_arn = optional(string, null)<br/>    enable_sso                              = optional(string, true)<br/><br/>    # Caching<br/>    elasticache_node_count = optional(number, 1)<br/>    elasticache_node_type  = optional(string, "cache.t4g.micro")<br/>  })</pre> | `null` | no |
| <a name="input_p4_server_config"></a> [p4\_server\_config](#input\_p4\_server\_config) | # - General -<br/>    name: "The string including in the naming of resources related to P4 Server. Default is 'p4-server'"<br/><br/>    project\_prefix: "The project prefix for this workload. This is appended to the beginning of most resource names."<br/><br/>    environment: "The current environment (e.g. dev, prod, etc.)"<br/><br/>    auth\_service\_url: "The URL for the P4Auth Service."<br/><br/>    fully\_qualified\_domain\_name = "The FQDN for the P4 Server. This is used for the P4 Server's Perforce configuration."<br/><br/><br/>    # - Compute -<br/>    lookup\_existing\_ami : "Whether to lookup the existing Perforce P4 Server AMI."<br/><br/>    ami\_prefix: "The AMI prefix to use for the AMI that will be created for P4 Server."<br/><br/>    instance\_type: "The instance type for Perforce P4 Server. Defaults to c6g.large."<br/><br/>    instance\_architecture: "The architecture of the P4 Server instance. Allowed values are 'arm64' or 'x86\_64'."<br/><br/>    IMPORTANT: "Ensure the instance family of the instance type you select supports the instance\_architecture you select. For example, 'c6in' instance family only works for 'x86\_64' architecture, not 'arm64'. For a full list of this mapping, see the AWS Docs for EC2 Naming Conventions: https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html"<br/><br/>    p4\_server\_type: "The Perforce P4 Server server type. Valid values are 'p4d\_commit' or 'p4d\_replica'."<br/><br/>    unicode: "Whether to enable Unicode configuration for P4 Server the -xi flag for p4d. Set to true to enable Unicode support."<br/><br/>    selinux: "Whether to apply SELinux label updates for P4 Server. Don't enable this if SELinux is disabled on your target operating system."<br/><br/>    case\_sensitive: "Whether or not the server should be case insensitive (Server will run '-C1' mode), or if the server will run with case sensitivity default of the underlying platform. False enables '-C1' mode. Default is set to true."<br/><br/>    plaintext: "Whether to enable plaintext authentication for P4 Server. This is not recommended for production environments unless you are using a load balancer for TLS termination. Default is set to false."<br/><br/><br/>    # - Storage -<br/>    storage\_type: "The type of backing store. Valid values are either 'EBS' or 'FSxN'"<br/><br/>    depot\_volume\_size: "The size of the depot volume in GiB. Defaults to 128 GiB."<br/><br/>    metadata\_volume\_size: "The size of the metadata volume in GiB. Defaults to 32 GiB."<br/><br/>    logs\_volume\_size: "The size of the logs volume in GiB. Defaults to 32 GiB."<br/><br/><br/>    # - Networking & Security -<br/>    instance\_subnet\_id: "The subnet where the P4 Server instance will be deployed."<br/><br/>    instance\_private\_ip: "The private IP address to assign to the P4 Server."<br/><br/>    create\_default\_sg : "Whether to create a default security group for the P4 Server instance."<br/><br/>    existing\_security\_groups: "A list of existing security group IDs to attach to the P4 Server load balancer."<br/><br/>    internal: "Set this flag to true if you do not want the P4 Server instance to have a public IP."<br/><br/>    super\_user\_password\_secret\_arn: "If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's username here. Otherwise, the default of 'perforce' will be used."<br/><br/>    super\_user\_username\_secret\_arn: "If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's password here."<br/><br/>    create\_default\_role: "Optional creation of P4 Server default IAM Role with SSM managed instance core policy attached. Default is set to true."<br/><br/>    custom\_role: "ARN of a custom IAM Role you wish to use with P4 Server." | <pre>object({<br/>    # General<br/>    name                        = optional(string, "p4-server")<br/>    project_prefix              = optional(string, "cgd")<br/>    environment                 = optional(string, "dev")<br/>    auth_service_url            = optional(string, null)<br/>    fully_qualified_domain_name = string<br/><br/>    # Compute<br/>    lookup_existing_ami = optional(bool, true)<br/>    ami_prefix          = optional(string, "p4_al2023")<br/><br/>    instance_type         = optional(string, "c6i.large")<br/>    instance_architecture = optional(string, "x86_64")<br/>    p4_server_type        = optional(string, null)<br/><br/>    unicode        = optional(bool, false)<br/>    selinux        = optional(bool, false)<br/>    case_sensitive = optional(bool, true)<br/>    plaintext      = optional(bool, false)<br/><br/>    # Storage<br/>    storage_type         = optional(string, "EBS")<br/>    depot_volume_size    = optional(number, 128)<br/>    metadata_volume_size = optional(number, 32)<br/>    logs_volume_size     = optional(number, 32)<br/><br/>    # Networking & Security<br/>    instance_subnet_id       = optional(string, null)<br/>    instance_private_ip      = optional(string, null)<br/>    create_default_sg        = optional(bool, true)<br/>    existing_security_groups = optional(list(string), [])<br/>    internal                 = optional(bool, false)<br/><br/>    super_user_password_secret_arn = optional(string, null)<br/>    super_user_username_secret_arn = optional(string, null)<br/><br/>    create_default_role = optional(bool, true)<br/>    custom_role         = optional(string, null)<br/><br/>    # FSxN<br/>    fsxn_password                     = optional(string, null)<br/>    fsxn_filesystem_security_group_id = optional(string, null)<br/>    protocol                          = optional(string, null)<br/>    fsxn_region                       = optional(string, null)<br/>    fsxn_management_ip                = optional(string, null)<br/>    fsxn_svm_name                     = optional(string, null)<br/>    amazon_fsxn_svm_id                = optional(string, null)<br/>    fsxn_aws_profile                  = optional(string, null)<br/>  })</pre> | `null` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_route53_private_hosted_zone_name"></a> [route53\_private\_hosted\_zone\_name](#input\_route53\_private\_hosted\_zone\_name) | The name of the private Route53 Hosted Zone for the Perforce resources. | `string` | `null` | no |
| <a name="input_s3_enable_force_destroy"></a> [s3\_enable\_force\_destroy](#input\_s3\_enable\_force\_destroy) | Enables force destroy for the S3 bucket for both the shared NLB and shared ALB access log storage. Defaults to true. | `bool` | `true` | no |
| <a name="input_shared_alb_access_logs_prefix"></a> [shared\_alb\_access\_logs\_prefix](#input\_shared\_alb\_access\_logs\_prefix) | Log prefix for shared ALB access logs. | `string` | `"perforce-alb-"` | no |
| <a name="input_shared_alb_subnets"></a> [shared\_alb\_subnets](#input\_shared\_alb\_subnets) | A list of subnets to attach to the shared application load balancer. | `list(string)` | `null` | no |
| <a name="input_shared_application_load_balancer_name"></a> [shared\_application\_load\_balancer\_name](#input\_shared\_application\_load\_balancer\_name) | The name of the shared Application Load Balancer for the Perforce resources. | `string` | `"p4alb"` | no |
| <a name="input_shared_ecs_cluster_name"></a> [shared\_ecs\_cluster\_name](#input\_shared\_ecs\_cluster\_name) | The name of the ECS cluster to use for the shared ECS Cluster. | `string` | `"perforce-cluster"` | no |
| <a name="input_shared_lb_access_logs_bucket"></a> [shared\_lb\_access\_logs\_bucket](#input\_shared\_lb\_access\_logs\_bucket) | ID of the S3 bucket for both the shared NLB and shared ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_shared_network_load_balancer_name"></a> [shared\_network\_load\_balancer\_name](#input\_shared\_network\_load\_balancer\_name) | The name of the shared Network Load Balancer for the Perforce resources. | `string` | `"p4nlb"` | no |
| <a name="input_shared_nlb_access_logs_prefix"></a> [shared\_nlb\_access\_logs\_prefix](#input\_shared\_nlb\_access\_logs\_prefix) | Log prefix for shared NLB access logs. | `string` | `"perforce-nlb-"` | no |
| <a name="input_shared_nlb_subnets"></a> [shared\_nlb\_subnets](#input\_shared\_nlb\_subnets) | A list of subnets to attach to the shared network load balancer. | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "terraform-aws-perforce",<br/>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce/terraform-aws-perforce",<br/>  "RootModuleName": "-"<br/>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC ID where the Perforce resources will be deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_p4_auth_alb_dns_name"></a> [p4\_auth\_alb\_dns\_name](#output\_p4\_auth\_alb\_dns\_name) | The DNS name of the P4Auth ALB. |
| <a name="output_p4_auth_alb_security_group_id"></a> [p4\_auth\_alb\_security\_group\_id](#output\_p4\_auth\_alb\_security\_group\_id) | Security group associated with the P4Auth load balancer. |
| <a name="output_p4_auth_alb_zone_id"></a> [p4\_auth\_alb\_zone\_id](#output\_p4\_auth\_alb\_zone\_id) | The hosted zone ID of the P4Auth ALB. |
| <a name="output_p4_auth_perforce_cluster_name"></a> [p4\_auth\_perforce\_cluster\_name](#output\_p4\_auth\_perforce\_cluster\_name) | Name of the ECS cluster hosting P4Auth. |
| <a name="output_p4_auth_service_security_group_id"></a> [p4\_auth\_service\_security\_group\_id](#output\_p4\_auth\_service\_security\_group\_id) | Security group associated with the ECS service running P4Auth. |
| <a name="output_p4_auth_target_group_arn"></a> [p4\_auth\_target\_group\_arn](#output\_p4\_auth\_target\_group\_arn) | The service target group for the P4Auth. |
| <a name="output_p4_code_review_alb_dns_name"></a> [p4\_code\_review\_alb\_dns\_name](#output\_p4\_code\_review\_alb\_dns\_name) | The DNS name of the P4 Code Review ALB. |
| <a name="output_p4_code_review_alb_security_group_id"></a> [p4\_code\_review\_alb\_security\_group\_id](#output\_p4\_code\_review\_alb\_security\_group\_id) | Security group associated with the P4 Code Review load balancer. |
| <a name="output_p4_code_review_alb_zone_id"></a> [p4\_code\_review\_alb\_zone\_id](#output\_p4\_code\_review\_alb\_zone\_id) | The hosted zone ID of the P4 Code Review ALB. |
| <a name="output_p4_code_review_perforce_cluster_name"></a> [p4\_code\_review\_perforce\_cluster\_name](#output\_p4\_code\_review\_perforce\_cluster\_name) | Name of the ECS cluster hosting P4 Code Review. |
| <a name="output_p4_code_review_service_security_group_id"></a> [p4\_code\_review\_service\_security\_group\_id](#output\_p4\_code\_review\_service\_security\_group\_id) | Security group associated with the ECS service running P4 Code Review. |
| <a name="output_p4_code_review_target_group_arn"></a> [p4\_code\_review\_target\_group\_arn](#output\_p4\_code\_review\_target\_group\_arn) | The service target group for the P4 Code Review. |
| <a name="output_p4_server_eip_id"></a> [p4\_server\_eip\_id](#output\_p4\_server\_eip\_id) | The ID of the Elastic IP associated with your P4 Server instance. |
| <a name="output_p4_server_eip_public_ip"></a> [p4\_server\_eip\_public\_ip](#output\_p4\_server\_eip\_public\_ip) | The public IP of your P4 Server instance. |
| <a name="output_p4_server_instance_id"></a> [p4\_server\_instance\_id](#output\_p4\_server\_instance\_id) | Instance ID for the P4 Server instance |
| <a name="output_p4_server_lambda_link_name"></a> [p4\_server\_lambda\_link\_name](#output\_p4\_server\_lambda\_link\_name) | The name of the Lambda link for the P4 Server instance to use with FSxN. |
| <a name="output_p4_server_private_ip"></a> [p4\_server\_private\_ip](#output\_p4\_server\_private\_ip) | Private IP for the P4 Server instance |
| <a name="output_p4_server_security_group_id"></a> [p4\_server\_security\_group\_id](#output\_p4\_server\_security\_group\_id) | The default security group of your P4 Server instance. |
| <a name="output_p4_server_super_user_password_secret_arn"></a> [p4\_server\_super\_user\_password\_secret\_arn](#output\_p4\_server\_super\_user\_password\_secret\_arn) | The ARN of the AWS Secrets Manager secret holding your P4 Server super user's username. |
| <a name="output_p4_server_super_user_username_secret_arn"></a> [p4\_server\_super\_user\_username\_secret\_arn](#output\_p4\_server\_super\_user\_username\_secret\_arn) | The ARN of the AWS Secrets Manager secret holding your P4 Server super user's password. |
| <a name="output_shared_application_load_balancer_arn"></a> [shared\_application\_load\_balancer\_arn](#output\_shared\_application\_load\_balancer\_arn) | The ARN of the shared application load balancer. |
| <a name="output_shared_network_load_balancer_arn"></a> [shared\_network\_load\_balancer\_arn](#output\_shared\_network\_load\_balancer\_arn) | The ARN of the shared network load balancer. |
<!-- END_TF_DOCS -->
