# Getting Started

Welcome to the **Cloud Game Development Toolkit**. There are a number of ways to use this repository depending on your development needs. This guide will introduce some of the key features of the project, and provide detailed instructions for deploying your game studio on AWS.

## Introduction to Repository Structure

### Assets

An _asset_ is a singular template, script, or automation document that may prove useful in isolation. Currently, the **Toolkit** contains three types of _assets_: [Ansible playbooks](./assets/ansible-playbooks/ansible-playbooks.md), [Jenkins pipelines](./assets/jenkins-pipelines/jenkins-pipelines.md), and [Packer templates](./assets/packer/index.md). Each of these _assets_ can be used in isolation. For more information about _assets_ specifically consult the [detailed documentation](./assets/index.md).

### Modules

A _module_ is a reusable [Terraform](https://www.terraform.io/) configuration encapsulating all of the resources needed to deploy a particular workload on AWS. These modules are highly configurable through variables, and provide necessary outputs for building interconnected architectures. We recommend reviewing the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules) if you are unfamiliar with this concept.

### Samples

A _sample_ is a complete reference architecture that stitches together [modules](./modules/index.md) and first-party AWS services. A _sample_ is deployed with Terraform, and is the best way to get started with the **Cloud Game Development Toolkit**.

## Step by Step Tutorial

This section will walk you through the prerequisites for deploying the [Simple Build Pipeline](./samples/simple-build-pipeline.md), the actual deployment process with Terraform, and basic configuration of Jenkins and Perforce.

### Step 1. Install Prerequisites

You will need the following tools to complete this tutorial:

1. [Terraform CLI](https://developer.hashicorp.com/terraform/install)
2. [Packer CLI](https://developer.hashicorp.com/packer/install)
3. [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### Step 2. Create Perforce Helix Core Amazon Machine Image

Prior to deploying the infrastructure for running Perforce Helix Core we need to create an [Amazon Machine Image](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) containing the necessary software and tools. The **Cloud Game Development Toolkit** contains a Packer template for doing just this.

1. From your terminal, run the following commands from the root of the repository:

``` bash
packer init ./assets/packer/perforce/helix-core/perforce.pkr.hcl
packer build ./assets/packer/perforce/helix-core/perforce.pkr.hcl
```

This will use your AWS credentials to provision an [EC2 instance](https://aws.amazon.com/ec2/instance-types/) in your [Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html). The Region, VPC, and Subnet where this instance is provisioned and the AMI is created are configurable - please consult the [`example.pkrvars.hcl`](./assets/packer/perforce/helix-core/example.pkrvars.hcl) file and the [Packer documentation on assigning variables](https://developer.hashicorp.com/packer/guides/hcl/variables#assigning-variables) for more details.

???+ Note
    The AWS Region where this AMI is created _must_ be the same Region where you intend to deploy the Simple Build Pipeline.

### Step 3. Create Build Agent Amazon Machine Images

This section covers the creation of Amazon Machine Images used to provision Jenkins build agents. Different studios have different needs at this stage, so we'll cover the creation of three different build agent AMIs.

#### Amazon Linux 2023 ARM based Amazon Machine Image

This Amazon Machine Image is provisioned using the [Amazon Linux 2023](https://aws.amazon.com/linux/amazon-linux-2023/) base operating system. It is highly configurable through variables, but there is only one variable that is required: A public SSH key. This public SSH key is used by the Jenkins orchestration service to establish an initial connection to the agent.

This variable can be passed to Packer using the `-var-file` or `-var` command line flag. If you are using a variable file, please consult the [`example.pkrvars.hcl`](./assets/packer/build-agents/linux/example.pkrvars.hcl) for overridable fields. You can also pass the SSH key directly at the command line:

``` bash
packer build amazon-linux-2023-arm64.pkr.hcl \
    -var "public_key=<include public key here>"
```

???+ Note
    The above command assumes you are running `packer` from the `/assets/packer/build-agents/linux` directory.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=ec2-user'
```

Take note of the output of this CLI command. You will need the ARN later.

#### Ubuntu Jammy 22.04 X86 based Amazon Machine Image

This Amazon Machine Image is provisioned using the Ubuntu Jammy 22.04 base operating system. Just like the Amazon Linux 2023 AMI above, the only required variable is a public SSH key. All Linux Packer templates use the same variables file, so if you would like to share a public key across all build nodes we recommend using a variables file. To build this AMI with a variables file called `linux.pkrvars.hcl` you would use the following command:

``` bash
packer build ubuntu-jammy-22.04-amd64-server.pkr.hcl \
    -var-file="linux.pkrvars.hcl"
```

???+ Note
    The above command assumes you are running `packer` from the `/assets/packer/build-agents/linux` directory.

Finally, you'll want to upload the private SSH key to AWS Secrets Manager so that the Jenkins orchestration service can use it to connect to this build agent.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=ubuntu'
```

Take note of the output of this CLI command. You will need the ARN later.

#### Windows 2022 X86 based Amazon Machine Image

This Amazon Machine Image is provisioned using the Windows Server 2022 base operating system. It installs all required tooling for Unreal Engine 5 compilation by default. Please consult [the release notes for Unreal Engine 5.4](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5.4-release-notes#platformsdkupgrades) for details on what tools are used for compiling this version of the engine.

Again, the only required variable for building this Amazon Machine Image is a public SSH key.

``` bash
packer build windows.pkr.hcl \
    -var "public_key=<include public ssh key here>"
```

???+ Note
    The above command assumes you are running `packer` from the `/assets/packer/build-agents/windows` directory.

Finally, you'll want to upload the private SSH key to AWS Secrets Manager so that the Jenkins orchestration service can use it to connect to this build agent.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=jenkins'
```

Take note of the output of this CLI command. You will need the ARN later.

### Step 4. Create Route53 Hosted Zone

Now that all of the required Amazon Machine Images exist we are almost ready to move on to provisioning infrastructure. However, the _Simple Build Pipeline_ requires that we create one resource ahead of time: [A Route53 Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html). The _Simple Build Pipeline_ creates DNS records and SSL certificates for all the applications it deploys to support secure communication over the internet. However, these certificates and DNS records rely on the existence of a public hosted zone associated with your company's route domain. Since different studios may use different DNS registrars or DNS providers, the _Simple Build Pipeline_ requires this first step to be completed manually. Everything else will be deployed automatically in the next step.

If you do not already have a domain you can [register one with Route53.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure-section) When you register a domain with Route53 a public hosted zone is automatically created.

If you already have a domain that you would like to use for the _Simple Build Pipeline_ please consult the documentation for [making Amazon Route 53 the DNS service for an existing domain.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html)

Once your hosted zone exists you can proceed to the next step.

### Step 5. Configure Simple Build Pipeline Variables

All configuration of the _Simple Build Pipeline_ occurs in the [`local.tf`](./samples/simple-build-pipeline/local.tf) file. Before you deploy this architecture you will need to provide the outputs from previous steps.

We'll walk through the required configurations in [`local.tf`](./samples/simple-build-pipeline/local.tf).

1. `fully_qualified_domain_name` must be set to the domain name you created a public hosted zone for in [Step 4](#step-4-create-route53-hosted-zone). Your applications will be deployed at subdomains. For example, if `fully_qualified_domain_name=example.com` then Jenkins will be available at `jenkins.example.com` and Perforce Helix Core will be available at `core.helix.example.com`.

2. `allowlist` grants public internet access to the various applications deployed in the _Simple Build Pipeline_. At a minimum you will need to include your own IP address to gain access to Jenkins and Perforce Helix Core for configuration following deployment. For example, if your IP address is `192.158.1.38` you would want to set `allowlist=["192.158.1.38/32"]` to grant yourself access.

???+ Note
    The `/32` suffix above is a subnet mask that specifies a single IP address. If you have different CIDR blocks that you would like to grant access to you can include those as well.

3. `jenkins_agent_secret_arns` is a list of [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) ARNs that the Jenkins orchestration service will be granted access to. This is primarily used for providing private SSH keys to Jenkins so that the orchestration service can connect to your build agents. When you created build agent AMIs earlier you also uploaded private SSH keys to AWS Secrets Manager. The ARNs of those secrets should be added to the `jenkins_agent_secret_arns` list so that Jenkins can connect to the provisioned build agents.

4. The `build_farm_compute` map contains all of the information needed to provision your Jenkins build farms. Each entry in this map corresponds to an [EC2 Auto Scaling group](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html), and requires two fields to be specified: `ami` and `instance_type`. The `local.tf` file contains an example configuration that has been commented out. Using the AMI IDs from [Step 3](#step-3-create-build-agent-amazon-machine-images), please specify the build farms you would like to provision. Selecting the right instance type for your build farm is highly dependent on your build process. Larger instances are more expensive, but provide improved performance. For example, large Unreal Engine compilation jobs will perform significantly better on [Compute Optimized](https://aws.amazon.com/ec2/instance-types/#Compute_Optimized) instances, while cook jobs tend to benefit from the increased RAM available from [Memory Optimized](https://aws.amazon.com/ec2/instance-types/#Memory_Optimized) instances. It can be a good practice to provision an EC2 instance using your custom AMI, and run your build process locally to determine the right instance size for your build farm. Once you have settled on an instance type, complete the `build_farm_compute` map to configure your build farms.

5. Finally, the `build_farm_fsx_openzfs_storage` field configures file systems used by your build agents for mounting Helix Core workspaces and shared caches. Again, an example configuration is provided but commented out. Depending on the number of builds you expect to be performing and the size of your project, you may want to adjust the size of the suggested file systems.

### Step 6. Deploy Simple Build Pipeline

Now we are ready to deploy your _Simple Build Pipeline_! Navigate to the [`/samples/simple-build-pipeline`](./samples/simple-build-pipeline/) directory and run the following commands:

``` bash
terraform init
```

This will install the modules and required Terraform providers.

``` bash
terraform apply
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

![Jenkins Admin Password](./media/images/jenkins-admin-password.png)

Open the Jenkins console in your preferred browser by navigating to `jenkins.<your fully qualified domain name>`, and log in using the administrator's password you just located. Install the suggested plugins and create your first admin user. For the Jenkins URL accept the default value.

#### Useful Plugins

There are 2 plugins recommended for the solutions: The [EC2 Fleet](https://plugins.jenkins.io/ec2-fleet/) Plugin and the [AWS Secrets Manager Credentials Provider](https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/) Plugin. The `EC2 Fleet` Plugin is used to integrate Jenkins with AWS and allows EC2 instances to be used as build nodes through an autoscaling group. The `AWS Secrets Manager Credentials Provider` Plugin will allow users to store their credentials in AWS Secrets Manager and seamlessly access them in Jenkins.

1. Open the Jenkins console.
2. On the left-hand side, select the `Manage Jenkins` tab.
3. Then, under the `System Configuration` section, select `Plugins`.
4. On the left-hand side, select ` Available plugins`.
5. Using the search bar at the top of the page, search for `EC2 Fleet`.
6. Select the `EC2 Fleet` plugin.
7. Using the search bar at the top of the page, search for `AWS Secret Manager Credentials Provider`.
8. Select the `AWS Secret Manager Credentials Provider` plugin.
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

Repeat the process above for each of the Auto Scaling groups you specified in your `build_farm_compute` configuration. You should now be able to reference these "Cloud" agents in your Jenkins pipeline definitions.


### Step 8. Configure Helix Authentication Service

The [Helix Authentication Service](https://www.perforce.com/downloads/helix-authentication-service) provides integrations with common identity providers so that end-users of Helix Core and Helix Swarm can use their existing credentials to access version control and code review tools.

The _Simple Build Pipeline_ deploys the Helix Authentication Service with the administrator web-based UI enabled. You should be able to navigate to `auth.helix.<your fully qualified domain name>/admin` to configure your external IDP.

The deployment of the Helix Authentication Service module as part of the _Simple Build Pipeline_ creates a random administrator password and stores it in AWS Secrets Manager. You can find this password by navigating to the [AWS Secrets Manager console](https://console.aws.amazon.com/secretsmanager) and viewing the `helixAuthServiceAdminUserPassword` secret. The username is also available under `helixAuthServiceAdminUsername`. Use these credentials to access the web UI and configure your identity provider.

### Step 9. Test Helix Core and Helix Swarm

Like Helix Authentication Service, a random administrator's password is created for Helix Core and Helix Swarm. The username and password are available in AWS Secrets Manager under the secrets named `perforceHelixCoreSuperUserPassword` and `perforceHelixCoreSuperUserUsername`. Use these credentials to access Helix Core and Helix Swarm for the first time.

Once you have access to Helix Core you should be able to provision new users. You can do this through the P4Admin GUI or from the command line. For more information please conuslt the Perforce Helix Core documentation. Users provisioned with an email address that corresponds with the identity provider configured in Helix Authentication Service will be able to use their existing credentials to log in to Helix Core and Helix Swarm.

### Step 10. Cleanup

Tearing down the resources created by the _Simple Build Pipeline_ is as easy as running `terraform destroy` in the `/samples/simple-build-pipeline` directory. However, this will not delete the secrets you've uploaded, the AMIs created with Packer, or the the Route53 hosted zone you set up initially. Those resources will need to be explicitly destroyed using the AWS console or relevant CLI commands.
