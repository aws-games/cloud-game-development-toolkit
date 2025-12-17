# Simple Build Pipeline

This sample demonstrates how to use the Cloud Game Development Toolkit to deploy a simple build pipeline on AWS.

## Features

- Deployment of version control with P4 Server, P4 Auth, and Code Review
- Deployment of CI/CD with Jenkins

### Step 1. Install Prerequisites

You will need the following tools to complete this tutorial:

1. [Terraform CLI](https://developer.hashicorp.com/terraform/install)
2. [Packer CLI](https://developer.hashicorp.com/packer/install)
3. [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### Step 2. Create Perforce P4 Server (formerly Helix Core) Amazon Machine Image

Prior to deploying the infrastructure for running P4 Server, we need to create an [Amazon Machine Image](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) containing the necessary software and tools. The
**Cloud Game Development Toolkit** contains a Packer template for doing just this.

**IMPORTANT:** Uploading shell scripts from Windows to Unix-based systems using Packer can sometimes fail due to line ending differences. Windows uses CRLF (`\r\n`) while Unix systems use LF (
`\n`). This discrepancy can cause issues when the script is executed on the target system. In this case, this issue can occur with the shell scripts that are used to configure Perforce on the EC2 Instance.

To avoid this, ensure you use WSL or something else similar to allow you to execute Unix commands, or use a Unix-based machine.

1. From your terminal, run the following commands from the root of the repository (this example assumes usage of `x86_64` architecture as this is the default instance architecture used in the module):

``` bash
packer init ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl
packer build ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl
```

This will use your AWS credentials to provision an [EC2 instance](https://aws.amazon.com/ec2/instance-types/) in your [Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html). This instance is only used to create the AMI and will be terminated once the AMI is successfully created. The Region, VPC, and Subnet where this instance is provisioned and the AMI is created are configurable - please consult the [
`example.pkrvars.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/perforce/p4-server/example.pkrvars.hcl) file and the [Packer documentation on assigning variables](https://developer.hashicorp.com/packer/guides/hcl/variables#assigning-variables) for more details.

> **Note:**
> The P4 Server template will default to the user's CLI configured region, if a region is not provided.

> **Note:**
> The AWS Region where this AMI is created _must_ be the same Region where you intend to deploy the Simple Build Pipeline.

### Step 3. Create Build Agent Amazon Machine Images

This section covers the creation of Amazon Machine Images used to provision Jenkins build agents. Different studios have different needs at this stage, so we'll cover the creation of three different build agent AMIs.

> **Note:**
> The Build Agent templates will default to the user's CLI configured region, if a region is not provided.

#### Amazon Linux 2023 Amazon Machine Image

This Amazon Machine Image is provisioned using the [Amazon Linux 2023](https://aws.amazon.com/linux/amazon-linux-2023/) base operating system. It is highly configurable through variables, but there is only one variable that is required: A public SSH key. This public SSH key is used by the Jenkins orchestration service to establish an initial connection to the agent.

This variable can be passed to Packer using the `-var-file` or `-var` command line flag. If you are using a variable file, please consult the [
`example.pkrvars.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/example.pkrvars.hcl) for overridable fields. You can also pass the SSH key directly at the command line:

#### There are separate ARM and x86 based Packer scripts available for Amazon Linux 2023

#### ARM Based Image

``` bash
packer build -var "public_key=<include public key here>" amazon-linux-2023-arm64.pkr.hcl
```

#### x86 Based Image

``` bash
packer build -var "public_key=<include public key here>" amazon-linux-2023-x86_64.pkr.hcl
```

> **Note:**
> The above commands assume you are running `packer` from the `/assets/packer/build-agents/linux` directory.

Then securely store the private key value as a secret in AWS Secrets Manager.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=ec2-user'
```

Take note of the output of this CLI command. You will need the ARN later.

#### Ubuntu Jammy 22.04 Amazon Machine Images

These Amazon Machine Images are provisioned using the Ubuntu Jammy 22.04 base operating system. Just like the Amazon Linux 2023 AMI above, the only required variable is a public SSH key. All Linux Packer templates use the same variables file, so if you would like to share a public key across all build nodes we recommend using a variables file. In the case you do choose to use a variable file, please consult the [
`example.pkrvars.hcl`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/assets/packer/build-agents/linux/example.pkrvars.hcl) for overridable fields.

#### There are separate AMD64 and ARM based Packer scripts available for Ubuntu Jammy 22.04

#### AMD64 Based Image

``` bash
packer build -var "public_key=<include public key here>" ubuntu-jammy-22.04-amd64-server.pkr.hcl
```

#### ARM Based Image

``` bash
packer build -var "public_key=<include public key here>" ubuntu-jammy-22.04-arm64-server.pkr.hcl
```

> **Note:**
> The above commands assume you are running `packer` from the `/assets/packer/build-agents/linux` directory.

Finally, you'll want to upload the private SSH key to AWS Secrets Manager so that the Jenkins orchestration service can use it to connect to this build agent.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=ubuntu'
```

> **Note:**
> If you have already created a secret for any of the previous Amazon Linux images, please remember to change the name of this secret to avoid a naming conflict.

Take note of the output of this CLI command. You will need the ARN later.

#### Windows 2022 X86 based Amazon Machine Image

This Amazon Machine Image is provisioned using the Windows Server 2022 base operating system. It installs all required tooling for Unreal Engine 5 compilation by default. Please consult [the release notes for Unreal Engine 5.4](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5.4-release-notes#platformsdkupgrades) for details on what tools are used for compiling this version of the engine.

Again, the only required variable for building this Amazon Machine Image is a public SSH key.

``` bash
packer build -var "public_key=<include public ssh key here>" windows.pkr.hcl
```

> **Note:**
> The above command assumes you are running `packer` from the `/assets/packer/build-agents/windows` directory.

Finally, you'll want to upload the private SSH key to AWS Secrets Manager so that the Jenkins orchestration service can use it to connect to this build agent.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=jenkins'
```

> **Note:**
> If you have already created a secret for any of the previous Amazon Linux or Ubuntu Jammy based images, please remember to change the name of this secret to avoid a naming conflict.

Take note of the output of this CLI command. You will need the ARN later.

### Step 4. Create Route53 Hosted Zone

Now that all of the required Amazon Machine Images exist we are almost ready to move on to provisioning infrastructure. However, the _Simple Build
Pipeline_ requires that we create one resource ahead of time: [A Route53 Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html). The _Simple Build
Pipeline_ creates DNS records and SSL certificates for all the applications it deploys to support secure communication over the internet. However, these certificates and DNS records rely on the existence of a public hosted zone associated with your company's route domain. Since different studios may use different DNS registrars or DNS providers, the
_Simple Build Pipeline_ requires this first step to be completed manually. Everything else will be deployed automatically in the next step.

If you do not already have a domain you can [register one with Route53.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure-section) When you register a domain with Route53 a public hosted zone is automatically created.

If you already have a domain that you would like to use for the _Simple Build
Pipeline_ please consult the documentation for [making Amazon Route 53 the DNS service for an existing domain.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html)

Once your hosted zone exists you can proceed to the next step.

### Step 5. Configure Simple Build Pipeline Variables

Configurations for the _Simple Build Pipeline_ are split between 2 files: [
`local.tf`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/local.tf) and [
`variables.tf`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/variables.tf). Variables in
`local.tf` are typically static and can be modified within the file itself. Variables in `variables.tf` tend to be more dynamic and are passed in through the
`terraform apply` command either directly through a `-var` flag or as file using the `-var-file` flag.

We'll start by walking through the required configurations in `local.tf`.

1.

`jenkins_agent_secret_arns` is a list of [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) ARNs that the Jenkins orchestration service will be granted access to. This is primarily used for providing private SSH keys to Jenkins so that the orchestration service can connect to your build agents. When you created build agent AMIs earlier you also uploaded private SSH keys to AWS Secrets Manager. The ARNs of those secrets should be added to the
`jenkins_agent_secret_arns` list so that Jenkins can connect to the provisioned build agents.

2. The
   `build_farm_compute` map contains all of the information needed to provision your Jenkins build farms. Each entry in this map corresponds to an [EC2 Auto Scaling group](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html), and requires two fields to be specified:
   `ami` and `instance_type`. The
   `local.tf` file contains an example configuration that has been commented out. Using the AMI IDs from [Step 3](#step-3-create-build-agent-amazon-machine-images), please specify the build farms you would like to provision. Selecting the right instance type for your build farm is highly dependent on your build process. Larger instances are more expensive, but provide improved performance. For example, large Unreal Engine compilation jobs will perform significantly better on [Compute Optimized](https://aws.amazon.com/ec2/instance-types/#Compute_Optimized) instances, while cook jobs tend to benefit from the increased RAM available from [Memory Optimized](https://aws.amazon.com/ec2/instance-types/#Memory_Optimized) instances. It can be a good practice to provision an EC2 instance using your custom AMI, and run your build process locally to determine the right instance size for your build farm. Once you have settled on an instance type, complete the
   `build_farm_compute` map to configure your build farms.

3. Finally, the
   `build_farm_fsx_openzfs_storage` field configures file systems used by your build agents for mounting P4 Server workspaces and shared caches. Again, an example configuration is provided but commented out. Depending on the number of builds you expect to be performing and the size of your project, you may want to adjust the size of the suggested file systems.

The variables in `variables.tf` are as follows:

.`route53_public_hosted_zone_name` must be set to the public hosted zone you created in [Step 4](#step-4-create-route53-hosted-zone). Your applications will be deployed at subdomains. For example, if
`route53_public_hosted_zone_name=example.com` then Jenkins will be available at `jenkins.example.com` and P4 Server e will be available at
`perforce.example.com`. These subdomains are configurable via `locals.tf`.

### Step 6. Deploy Simple Build Pipeline

Now we are ready to deploy your _Simple Build Pipeline_! Navigate to the `/samples/simple-build-pipeline` directory and run the following commands:

``` bash
terraform init
```

This will install the modules and required Terraform providers.

``` bash
terraform apply -var "route53_public_hosted_zone_name=<insert your root domain>"
```

This will create a Terraform plan, and wait for manual approval to deploy the proposed resources. Once approval is given the entire deployment process takes roughly 10 minutes.

### Step 7. Configure Jenkins

Now that everything is deployed, its time to configure the applications included in the _Simple Build Pipeline_. First, we will setup Jenkins.

#### Initial Access

When accessing Jenkins for the first time, an administrator's password is required. This password is auto-generated and available through the service logs.

1. Open the AWS console and navigate to the [Elastic Container Service (ECS) console](https://console.aws.amazon.com/ecs).
2. In the `Clusters` tab, select the `build-pipeline-cluster`
3. Select the `cgd-jenkins-service`
4. Select the `Logs` tab
5. Scroll through the logs until you find the password, below is an example of what the password section looks like. Note that each line is shown as its own log entry in the console.

![Jenkins Admin Password](../../docs/media/images/jenkins-admin-password.png)

Open the Jenkins console in your preferred browser by navigating to
`jenkins.<your fully qualified domain name>`, and log in using the administrator's password you just located. Install the suggested plugins and create your first admin user. For the Jenkins URL accept the default value.
This URL is provided as an output on the terminal where you ran `terraform apply`.

#### Useful Plugins

There are 2 plugins recommended for the solutions: The [EC2 Fleet](https://plugins.jenkins.io/ec2-fleet/) Plugin and the [AWS Secrets Manager Credentials Provider](https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/) Plugin. The
`EC2 Fleet` Plugin is used to integrate Jenkins with AWS and allows EC2 instances to be used as build nodes through an autoscaling group. The
`AWS Secrets Manager Credentials Provider` Plugin will allow users to store their credentials in AWS Secrets Manager and seamlessly access them in Jenkins.

1. Open the Jenkins console.
2. On the left-hand side, select the `Manage Jenkins` tab.
3. Then, under the `System Configuration` section, select `Plugins`.
4. On the left-hand side, select `Available plugins`.
5. Using the search bar at the top of the page, search for `EC2 Fleet`.
6. Select the `EC2 Fleet` plugin.
7. Using the search bar at the top of the page, search for `AWS Secrets Manager Credentials Provider`.
8. Select the `AWS Secrets Manager Credentials Provider` plugin.
9. Click `install` on the top-right corner of the page.
10. Once the installation is complete, Select `Go back to the top page` at the bottom of the page

#### Jenkins Cloud Configuration

We now need to setup our Auto Scaling groups as Jenkins build agents. To do this, we will create multiple Jenkins "Cloud" resources; one for each of the Auto Scaling groups we deployed in the previous step.

1. From the Jenkins homepage, on the left-hand side, choose `Manage Jenkins`.
2. Under the `System Configuration` section, choose `Clouds`
3. Select `New Cloud`
3. Enter a name for your cloud configuration
4. Select `Amazon EC2 Fleet`
5. Click `Create`
6. On the `New Cloud` configuration page, change the following settings.
    1. **Region** - Select the region in which you deployed the _Simple Build Pipeline_
    1. **EC2 Fleet** - Select the autoscaling group you would like to use
    1. **Launcher** - Select `Launch agents via SSH`
    1. **Launcher** -> **Credentials** - Select the credentials associated with that particular autoscaling group
    1. **Launcher** -> **Host Key Verification Strategy** - Select `Non verifying Verification Strategy`
    1. **Connect to instaces via private IP instead of public IP** - Select the `Private IP` check box
    1. **Max Idle Minutes Before Scaledown** - Set this variable to `5` (minutes). Feel free to change this based on your needs.

Repeat the process above for each of the Auto Scaling groups you specified in your
`build_farm_compute` configuration. You should now be able to reference these "Cloud" agents in your Jenkins pipeline definitions.

### Step 8. Configure P4Auth (formerly Helix Authentication Service)

The [P4Auth](https://www.perforce.com/downloads/helix-authentication-service) provides integrations with common identity providers so that end-users of P4 Server (formerly Helix Core) and P4 Code Review (formerly Helix Swarm) can use their existing credentials to access version control and code review tools.

The _Simple Build Pipeline_ deploys the P4Auth with the administrator web-based UI enabled. You should be able to navigate to
`auth.perforce.<your fully qualified domain name>/admin` to configure your external IDP. This URL is provided as an output on the terminal where you ran `terraform apply`.

With the default configuration, the deployment of the Perforce module as part of the _Simple Build
Pipeline_ creates a random administrator password and stores it in AWS Secrets Manager. You can find this password by navigating to the [AWS Secrets Manager console](https://console.aws.amazon.com/secretsmanager) and viewing the secret ending in
`-AdminUserPassword` The username is also available within the secret ending in `-AdminUsername`. Use these credentials to access the web UI and configure your identity provider.

### Step 9. Test P4 Server and P4 Code Review

Like P4Auth, an administrator's password is created for P4 Server. The username and password are available in AWS Secrets Manager under the secrets ending in
`-SuperUserPassword` and
`-SuperUserUsername`. Use these credentials to access P4 Server for the first time. The P4 server connection string and P4 Code Review URLs are provided as outputds on the terminal where you ran
`terraform apply`.

Once you have access to P4 Server you should be able to provision new users. You can do this through the P4Admin GUI or from the command line. For more information please consult the P4 Server documentation. Users provisioned with an email address that corresponds with the identity provider configured in P4Auth will be able to use their existing credentials to log in to P4 Server and P4 Code Review.

### Step 10. Cleanup

Tearing down the resources created by the _Simple Build Pipeline_ is as easy as running `terraform destroy` in the
`/samples/simple-build-pipeline` directory. However, this will not delete the secrets you've uploaded, the AMIs created with Packer, or the the Route53 hosted zone you set up initially. Those resources will need to be explicitly destroyed using the AWS console or relevant CLI commands.


<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.6 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.5 |
| <a name="requirement_netapp-ontap"></a> [netapp-ontap](#requirement\_netapp-ontap) | ~> 2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.6 |
| <a name="provider_http"></a> [http](#provider\_http) | ~> 3.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_jenkins"></a> [jenkins](#module\_jenkins) | ../../modules/jenkins | n/a |
| <a name="module_terraform-aws-perforce"></a> [terraform-aws-perforce](#module\_terraform-aws-perforce) | ../../modules/perforce | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.shared](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.shared_certificate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ecs_cluster.build_pipeline_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.providers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_eip.nat_gateway_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_lb.service_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb.web_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.internal_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.public_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.jenkins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.perforce_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.perforce_code_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.alb_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.alb_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_nat_gateway.nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_rt_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.jenkins_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.jenkins_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_server_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_server_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_web_services_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_web_services_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.shared_certificate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.private_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route_table.private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.allow_my_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.internal_shared_application_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.public_network_load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.build_pipeline_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_egress_rule.internal_alb_http_to_jenkins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.internal_alb_http_to_p4_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.internal_alb_http_to_p4_code_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.public_nlb_https_to_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_perforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.internal_alb_https_from_p4_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.internal_alb_https_from_public_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_http_from_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_auth_http_from_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_code_review_http_from_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_server_from_jenkins_build_farm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.p4_server_from_jenkins_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.ubuntu_noble_amd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The fully qualified domain name of your existing Route53 Hosted Zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_jenkins_url"></a> [jenkins\_url](#output\_jenkins\_url) | The URL for the Jenkins service. |
| <a name="output_p4_auth_admin_url"></a> [p4\_auth\_admin\_url](#output\_p4\_auth\_admin\_url) | The URL for the P4Auth service admin page. |
| <a name="output_p4_code_review_url"></a> [p4\_code\_review\_url](#output\_p4\_code\_review\_url) | The URL for the P4 Code Review service. |
| <a name="output_p4_server_connection_string"></a> [p4\_server\_connection\_string](#output\_p4\_server\_connection\_string) | The connection string for the P4 Server. Set your P4PORT environment variable to this value. |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
