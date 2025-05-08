# Perforce on AWS Terraform Module

## Features
- Dynamic creation and configuration of [P4 Server (formerly Helix Core)](https://www.perforce.com/products/helix-core)
- Dynamic creation and configuration of [P4 Code Review (formerly Helix Swarm)](https://www.perforce.com/products/helix-swarm)
- Dynamic creation and configuration of [P4Auth (formerly Helix Authentication Service)](https://help.perforce.com/helix-core/integrations-plugins/helix-auth-svc/current/Content/HAS/overview-of-has.html)


## Architecture
### Full example using AWS Route53 Public Hosted Zone
![perforce-complete-arch](./assets/media/diagrams/perforce-arch-cdg-toolkit-terraform-aws-perforce-full-arch-route53-dns.png)


## Prerequisites
- **Existing DNS Configured**
  - To use this module, you must have an existing domain and related DNS configuration. The example at `/examples/create-resources-complete` demonstrates how to provision resources while using Amazon Route53 (recommended) as the DNS provider. This will make deployment and management easier.
  - You may optionally use a 3rd party DNS provider, however you must create records in your DNS provider to route to the endpoints that you will create for each component when using the module (e.g. `perforce.example.com`, `review.perforce.example.com`, `auth.perforce.example.com`). The module has variables that you can use to customize the subdomains for the services (P4 Server, P4 Code Review, P4Auth), however if not set, the defaults mentioned above will be used. Ensure you create these records to allow users to connect to the services once provisioned in AWS.
  - **Note:** When using either of the two options mentioned above, by default the module will create a **Route53 Private Hosted Zone**. This is used for internal communication and routing of traffic between P4 Server, P4 Code Review, and P4Auth.
- **SSL TLS Certificate**
  - You must have an existing SSL/TLS certificate, or create one during deployment alongside the other resources the module will create. This is used to provide secure connectivity to the Perforce resources that will be running in AWS. The certificate will be used by the Application Load Balancer (ALB) that the module will deploy for you. If using Amazon Route53, see the example at `/examples/create-resources-complete` to see how to create the related certificate in Amazon Certificate Manager (ACM). Using a Route53 as the DNS provider makes this process a bit easier, as ACM can automatically create the required CNAME records needed for DNS validation (a process required to verify DNS ownership) if you are also using Amazon Route53.
  - If using an 3rd party DNS provider, you must add these CNAME records manually (in addition to the other records mentioned above for general DNS purposes). If you would prefer to use a 3rd party to create the SSL/TLS certificate, the module allows you to import this into ACM to be used for the other components that will be deployed (such as the internal ALB). You may also use Email validation to validate DNS ownership.

- **Existing Perforce Amazon Machine Image (AMI)**
  - As mentioned in the architecture, an Amazon EC2 instance is used for the P4 Server, and this instance must be be provisioned using an AMI that is configured for Perforce. To expedite this process, we have sample [HashiCorp Packer](https://www.packer.io/) templates provided in the [AWS Cloud Game Development Toolkit repository](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/assets/packer/perforce/p4-server) that you can use to create a Perforce AMI in your AWS Account. **Note:** You must also reference the `p4_configure.sh` and `p4_setup.sh` files that are in this directory, as these are used to configure the P4 Commit Server. These are already referenced in the `perforce_arm64.pkr.hcl` and `perforce_x86.pkr.hcl` packer templates that are available for use.


## Deployment Instructions
1. Create the Perforce AMI in your AWS account using one of the supplied Packer templates. Ensure you use the Packer template that aligns with the architecture type (e.g. arm64) of the EC2 instance you wish to create. On the Terraform side, you may also set this using the `instance_architecture` variable. Ensure your `instance_type` is supported for your desired `instance_architecture`. For a full list of this mapping, see the [AWS Docs for EC2 Naming Conventions](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html). You can also use the interactive chart on Instances by [Vantage](https://instances.vantage.sh/).

**IMPORTANT:** By default, the module will create compute resources with `x86_64` architecture. Ensure you use this corresponding Packer template unless you set the `instance_architecture` variable to `arm64` or the deployment will fail. Also, unless explicitly set, the Packer templates are configured to build the AMI in whichever AWS region your current credentials are set to (e.g. `us-east-1`) which will also be the same AWS region your Terraform resources are deployed to unless you explicitly set this. Ensure the AMI is available in the AWS Region you will use the module to deploy resources into.

To deploy the template (`x86_64`) with Packer, do the following (while in the `/assets/perforce/p4-server directory`)
```
packer init perforce_x86.pkr.hcl
```
```
packer validate perforce_x86.pkr.hcl
```
```
packer build perforce_x86.pkr.hcl
```

2. Reference your existing fully qualified domain name within each related Perforce service you would like to provision (e.g. `p4_server_config`, `p4_auth_config`, `p4_code_review_config`) using the `fully_qualified_domain_name` variable. We recommend abstracting this t a local value such as `local.fully_qualified_domain_name` to ensure this value is consistent across the modules. The module will automatically configure Perforce using default subdomains of `perforce.<your-domain-name>` for P4 Server, `auth.perforce.<your-domain-name` for P4 Auth, and `review.perforce.<your-domain-name` for P4 Code Review. You will also need to create DNS records that will route traffic destined for these domains in the following manner:
    - Traffic destined for **P4 Server** will need to route to the **Elastic IP (EIP)** that is associated with the P4 Server EC2 Instance. By default, this will be using a subdomain named `perforce`. In your DNS provider, create an A record named `perforce.<your-domain-name>` and have it route traffic to the EIP. This value is available as a Terraform output for your convenience.
    - Traffic destined for `*.perforce.<your-domain-name>` will need to route to the DNS name of the Network Load Balancer (NLB) that the module creates. In your DNS provider, create a CNAME record that routes traffic to NLB. This value is available as a Terraform output for your convenience.
    - **Note:** If using Amazon Route53 as your DNS provider, the example at  `/examples/create-resources-complete` shows you have to leverage Terraform to automatically create these records in an existing Route53 Public Hosted Zone, as well as how to create the certificate in Amazon Certificate Manager (ACM).

3. Make any other modifications as desired (such as referencing existing VPC resources) and run `terraform init` to initialize Terraform in the current working directory, `terraform plan` to create and validate the execution plan of the resources that will be created, and finally `terraform apply` to create the resources in your AWS Account.
4. Once the resources have finished provisioning successfully, you will need to modify your inbound Security Group Rules on the P4 Commit Server Instance to allow TCP traffic from your public IP on port 1666 (the perforce default port). This is necessary to allow your local machine(s) to connect to the P4 Commit Server.
    - **Note:** You may use other means to allow traffic to reach this EC2 Instance (Customer-managed prefix list, VPN to the VPC that the instance is running in, etc.) but regardless, it is essential that you have the security group rules set configured correctly to allow access.
5. Next, modify your inbound Security Group rules for the Perforce Network Load Balancer (NLB) to allow traffic from HTTPS (port 443) from your public IP address/ This is to provide access to the P4 Code Review and P4Auth services that are running behind the Application Load Balancer (ALB).
    - **Note:** You may use other means to allow traffic to reach this the Network Load Balancer (Customer-managed prefix list, VPN to the VPC that the instance is running in, etc.) but regardless, it is essential that you have the security group rules set configured correctly to allow access.
    - **IMPORTANT:** Ensure your networking configuration is correct, especially in terms of any public or private subnets that you reference. This is very important for the internal routing between the P4 resources, as well as the related Security Groups. Failure to set these correctly may cause a variety of connectivity issues such as web pages not loading, NLB health checks failing, etc.
6. Use the provided Terraform outputs to quickly find the URL for P4Auth, P4 Code Review. If you haven't modified the default values, relevant values for the P4 Server default username/password, and the P4 Code Review default username/password were created for you and are stored in AWS Secrets Manager.
7. In P4V, use the url of `ssl:<your-supplied-root-domain>:1666` and the username and password stored in AWS Secrets Manager to gain access to the commit server.
8. At this point, you should be able to access your P4 Commit Server (P4), and visit the URLs for P4 Code Review (P4 Code Review) and P4Auth (P4Auth).


## Examples
For example configurations, please see the examples at `/examples`.

<!-- BEGIN_TF_DOCS -->
