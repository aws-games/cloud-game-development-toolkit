# Jenkins Module

Jenkins is an open source automation server that simplifies repeatable software development tasks such as building, testing, and deploying applications. This module deploys Jenkins on an Elastic Container Service (ECS) cluster backed by AWS Fargate using the latest Jenkins container image ([jenkins/jenkins:lts-jdk17](https://hub.docker.com/r/jenkins/jenkins)). The deployment includes an Elastic File System (EFS) volume for persisting plugins and configurations, along with an Elastic Load Balancer (ELB) deployment for TLS termination. The module also includes the deployment of an EC2 Autoscaling group to serve as a flexible pool of build nodes, however the user must configure Jenkins to use the build farm.

This module deploys the following resources:

- An Elastic Container Service (ECS) cluster backed by AWS Fargate.
- An ECS service running the latest Jenkins container ([jenkins/jenkins:lts-jdk17](https://hub.docker.com/r/jenkins/jenkins)) available.
- An Elastic File System (EFS) for the Jenkins service to use as a persistent datastore.
- A ZFS File System (FSxZ) for shared cache
- A ZFS File System (FSxZ) for shared workspaces
- An Elastic Load Balancer (ELB) for TLS termination of the Jenkins service
- A configurable number of EC2 Autoscaling groups to serve as a flexible pool of build nodes for the Jenkins service
- Supporting resources including KMS keys for encryption and IAM roles to ensure security best practices
## Architecture

![Jenkins Module Architecture](../../media/Images/jenkins-module-architecture.png)

## Prerequisites
There are two prerequisites to the deployment of Jenkins which are not directly provided in the module. The first is a public certificate used by the Jenkins ALB for SSL termination. The second is an AWS Secrets Manager secret which we use to store the private key Jenkins will use to communicate with its Agents over SSH.


### Create Public Certificate

??? note "How to Create a Public Certificate Using Amazon Route 53"

    1. Sign in to the AWS Management Console and open the Amazon Certificate Manager (ACM) [console](https://console.aws.amazon.com/acm/home) and choose Request a certificate.

    2. In the Domain names section, type your domain name.

        a. You can use a fully qualified domain name (FQDN), such as www.example.com, or a bare or apex domain name such as example.com. You can also use an asterisk (\*) as a wild card in the leftmost position to protect several site names in the same domain. For example, \*.example.com protects corp.example.com, and images.example.com. The wild-card name will appear in the Subject field and in the Subject Alternative Name extension of the ACM certificate.

        b. When you request a wild-card certificate, the asterisk (\*) must be in the leftmost position of the domain name and can protect only one subdomain level. For example, \*.example.com can protect login.example.com, and test.example.com, but it cannot protect test.login.example.com. Also note that \*.example.com protects only the subdomains of example.com, it does not protect the bare or apex domain (example.com). To protect both, see the next step.

        !!! note
            In compliance with [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280), the length of the domain name (technically, the Common Name) that you enter in this step cannot exceed 64 octets (characters), including periods. Each subsequent Subject Alternative Name (SAN) that you provide, as in the next step, can be up to 253 octets in length. 

        c. To add another name, choose Add another name to this certificate and type the name in the text box. This is useful for protecting both a bare or apex domain (such as example.com) and its subdomains such as *.example.com).
    3. In the Validation method section, choose either DNS validation – recommended or Email validation, depending on your needs.

        !!! note
            If you are able to edit your DNS configuration, we recommend that you use DNS domain validation rather than email validation. [DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html) has multiple benefits over email validation. See DNS validation. 

        a. Before ACM issues a certificate, it validates that you own or control the domain names in your certificate request. You can use either email validation or DNS validation. 

        b. If you choose email validation, ACM sends validation email to three contact addresses registered in the WHOIS database, and up to five common system administration addresses for each domain name. You or an authorized representative must reply to one of these email messages. For more information, see [Email validation](https://docs.aws.amazon.com/acm/latest/userguide/email-validation.html). 

        c. If you use DNS validation, you simply add a CNAME record provided by ACM to your DNS configuration. For more information about DNS validation, see [DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html).

    4. In the Key algorithm section, chose one of the three available algorithms:
        * RSA 2048 (default)
        * ECDSA P 256
        * ECDSA P 384

        a. For information to help you choose an algorithm, see [Key algorithms](https://docs.aws.amazon.com/acm/latest/userguide/acm-certificate.html#algorithms) and the AWS blog post [How to evaluate and use ECDSA certificates in AWS Certificate Manager](https://aws.amazon.com/blogs/security/how-to-evaluate-and-use-ecdsa-certificates-in-aws-certificate-manager/).

    5.In the Tags page, you can optionally tag your certificate. Tags are key-value pairs that serve as metadata for identifying and organizing AWS resources. For a list of ACM tag parameters and for instructions on how to add tags to certificates after creation, see [Tagging AWS Certificate Manager certificates](https://docs.aws.amazon.com/acm/latest/userguide/tags.html). When you finish adding tags, choose Request.

    6. After the request is processed, the console returns you to your certificate list, where information about the new certificate is displayed.
        a. A certificate enters status Pending validation upon being requested, unless it fails for any of the reasons given in the troubleshooting topic [Certificate request fails](https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-failed.html). ACM makes repeated attempts to validate a certificate for 72 hours and then times out. If a certificate shows status Failed or Validation timed out, delete the request, correct the issue with [DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html) or [Email validation](https://docs.aws.amazon.com/acm/latest/userguide/email-validation.html), and try again. If validation succeeds, the certificate enters status Issued. 

        !!! note
            Depending on how you have ordered the list, a certificate you are looking for might not be immediately visible. You can click the black triangle at right to change the ordering. You can also navigate through multiple pages of certificates using the page numbers at upper-right.

[Amazon Certificate Manager Documentation](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html)

### Upload Secrets to AWS Secrets Manager

AWS Secrets Manager can be used to store sensitive information such as SSH keys and access tokens, which can then be made available to Jenkins. At a minimum, we use the service to store the private key for the Jenkins agents which the Jenkins orchestrator uses to communicate over SSH.

!!! warning
    To grant Jenkins access to the secrets stored in the AWS Secrets Manager, the `AWS Secrets Manager Credentials Provider` Jenkins plugin is recommended. **There are requirements around tagging your secrets for the plugin to work properly**. See the [AWS Secrets Manager Credentials Provider Plugin Documentation](https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/) for additional details.

??? note "How to Upload Secrets to AWS Secrets Manager"

    1. Open the Secrets Manager [console](https://console.aws.amazon.com/secretsmanager/).

    2. Choose Store a new secret.

    3. On the Choose secret type page, do the following:
        1. For Secret type, choose Other type of secret.

        1. In Key/value pairs, either enter your secret in JSON Key/value pairs, or choose the Plaintext tab and enter the secret in any format (you must choose Plaintext if storing SSH keys). You can store up to 65536 bytes in the secret.

        1. For Encryption key, choose the AWS KMS key that Secrets Manager uses to encrypt the secret value. For more information, see [Secret encryption and decryption](https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html).

            - For most cases, choose aws/secretsmanager to use the AWS managed key for Secrets Manager. There is no cost for using this key.

            - If you need to access the secret from another AWS account, or if you want to use your own KMS key so that you can rotate it or apply a key policy to it, choose a customer managed key from the list or choose Add new key to create one. For information about the costs of using a customer managed key, see [Pricing](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html#asm_pricing).

            - You must have [Permissions for the KMS key](https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html#security-encryption-authz). For information about cross-account access, see [Access AWS Secrets Manager secrets from a different account](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html).

        1. Choose Next

    4. On the Configure secret page, do the following:
        1. Enter a descriptive Secret name and Description. Secret names must contain 1-512 Unicode characters.

        1. (Optional) In the Tags section, add tags to your secret. For tagging strategies, see [Tag AWS Secrets Manager secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/managing-secrets_tagging.html). Don't store sensitive information in tags because they aren't encrypted.

        1. (Optional) In Resource permissions, to add a resource policy to your secret, choose Edit permissions. For more information, see [Attach a permissions policy to an AWS Secrets Manager secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_resource-policies.html).

        1. (Optional) In Replicate secret, to replicate your secret to another AWS Region, choose Replicate secret. You can replicate your secret now or come back and replicate it later. For more information, see [Replicate secrets across Regions](https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets.html).

        1. Choose Next.



    5. (Optional) On the Configure rotation page, you can turn on automatic rotation. You can also keep rotation off for now and then turn it on later. For more information, see [Rotate secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html). Choose Next.

    6. On the Review page, review your secret details, and then choose Store.

    Secrets Manager returns to the list of secrets. If your new secret doesn't appear, choose the refresh button.


[AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html)

### (Optional) Create Amazon Machine Image (AMI) for Jenkins Agent Using Packer

The CGD Toolkit provides packer templates for generating Amazon Machine Images (AMIs) for use as Jenkins Agents. The Toolkit provides both Windows and Linux options

??? note "How to Generate SSH Keys"

    1. Open your preferred Command Line App.

    2. Paste the text below, replacing the email used in the example with your email

    ``` bash
    # This command creates a new SSH key, using the provided email as a label
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

    3. When prompted to "Enter a file in which to save the key", enter a path in which to save the generated key, or press **Enter** to accept the default location.

    4. When prompted to "Enter passphrase", enter a password for your key, or leave empty for no password.
    
    !!! warning
        If using the [AWS Secrets Manager Credentials Provider](https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/), leave the passphrase empty. The AWS Secrets Manager Credentials Provider plugin does **NOT** support passphrases.

??? note "How to Create Linux AMI using Packer"

    1. Copy the existing example Packer configuration file located at **assets/packer/build-agents/linux/example.pkvars.hcl**
    2. Replace placeholder values
        * **region** - AWS Region code to deploy the AMI into. i.e. "us-west-2"
        * **vpc_id** - The ID of the VPC you wish to use to create the AMI.
        * **subnet_id** - The ID of the subnet you wish to use to create the AMI.
        * **profile** - The name of the [AWS CLI profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) you wish to use to create the AMI.
        * **public_key** - The public ssh key to be used by Jenkins when communicating with its agents.
    3. Download the Packer dependencies
        ``` shell
        # This command will download all necessary dependencies to build the AMI
        packer init
        ```

        !!! note
            If you do not have Hashicorp Packer installed, see [Packer Installation Instructions](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli).

    4. Build the Image
        ``` shell
        # This command builds the Linux x86_64 AMI using the configurations provided in the .pkvars.hcl you created above
        packer build -var-file your-vars.pkvars.hcl amazon-linux-2023-x86_64.pkr.hcl
        ```

    5. Notate the AMI id (**ami-#################**) returned from the previous command.
        ``` shell
        ==> Wait completed after 10 minutes 23 seconds

        ==> Builds finished. The artifacts of successful builds are:
        --> jenkins-linux-packer.amazon-ebs.al2023: AMIs were created:
        us-east-1: ami-08862...e2e
        ```

## Installation
```shell
terraform init
```

## Deploy
```shell
# Review architecture to be deployed
terraform plan -var-file=deployment-variables.tfvars

# Deploy terraform module
# It is recommended that you use a .tfvars file to pass variables to the module when deploying
terraform deploy -var-file=deployment-variables.tfvars
```

## Accessing Jenkins

Once deployed, the Jenkins service can be accessed through its associated load balancer. The service is served on port 8080 by default. This behaviour can be changed by providing a new port through the `container_port` variable.

You can find the DNS address for the ALB created by the module by running the following command:

``` bash
# This command pulls the DNS address of the ALB associated with the Jenkins ECS service
terraform output jenkins_alb_dns_name
```

!!! note
    if you are accessing the load balancer directly, you may receive a `Warning: Potential Security Risk Ahead` warning. This is due to a mismatch in the certificates FQDN. To continue click `advanced` then click `Accept the Risk and Continue`.

## Configuring Jenkins

When accessing Jenkins for the first time, an administrators password is required. This password is auto-generated and available through the ECS logs. The administrative user will be replaced with a new user upon completion of the setup, see [Creating Users](README.md#creating-users).


### Retrieve the Jenkins Administrator Password

1. Open the AWS console and navigate to the [Elastic Container Service (ECS) console](https://console.aws.amazon.com/ecs).
2. In the `Clusters` tab, select the name of the cluster you created
3. Select the name of the jenkins service you created
4. Select the `Logs` tab
5. Scroll through the logs until you find the password, below is an example of what the password section looks like. Note that each line is shown as its own log entry in the console.

![Jenkins Admin Password](../../media/Images/jenkins-admin-password.png)

### Jenkins Initial Configuration

1. Open the Jenkins console on your preferred browser, see [Accessing Jenkins](README.md#accessing-jenkins) for details.
2. Paste the password you retrieved from the logs in the previous step into the text box and click **Continue**
3. You will then be prompted to select the plugins you wish to install. 
   a. If you are unsure of which plugins to install, select `Install suggested plugins`.
   b. Otherwise, select `Select plugins to install` and choose your preferred plugins.
4. You are then prompted to create your first admin user.
   a. Enter a username for your new user
   b. Enter a password
   c. Enter your full name
   d. Enter you email
   e. Click `Save and Continue`
5. For the Jenkins URL, accept the default value by clicking `Save and Finish`.
6. Click `Start using Jenkins`

### Configuring Plugins

There are 2 plugins recommended for the solutions: The [EC2 Fleet](https://plugins.jenkins.io/ec2-fleet/) Plugin and the [AWS Secrets Manager Credentials Provider](https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/) Plugin. The `EC2 Fleet` Plugin is used to integrate Jenkins with AWS and allows EC2 instances to be used as build nodes through an autoscaling group. The `AWS Secrets Manager Credentials Provider` Plugin will allow users to store their credentials in AWS Secrets Manager and seamlessly access them in Jenkins.

#### Install the Plugins

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

#### Create the Necessary Credentials

!!! note ""
    === "Using the Jenkins Console"
        1. From the Jenkins homepage, on the left-hand side, select `Manage Jenkins`
        2. Under the `Security` section, select `Credentials`
        3. Under `Stores scoped to Jenkins`, select `System`
        4. Select `Global credentials (unrestricted)`
        5. In the top right corner, click the `Add Credentials` button
        6. For the `Kind` dropdown, select `SSH Username with private key`
        7. For `ID` enter a name for your credentials
        8. For `Description` add a description of your credential
        9. For `Username`, enter the username to be used for the SSH connection
        10. For `Private Key`, select the `Enter directly` radio button.
        11. In the next section displayed, select the `Add` button
        12. Paste the Private Key created earlier into the text box.
        13. For `Passphrase` enter the Passphrase for the SSH key, if no passphrase was entered when creating the keys, leave this blank
        14. Note the `ID` of your newly created credentials. This will be referenced in the next section.
    
    === "Using the AWS Secrets Manager Plugin"
    
        1. Open the Secrets Manager [console](https://console.aws.amazon.com/secretsmanager/).
    
        2. Choose Store a new secret.
    
        3. On the Choose secret type page, do the following:
            1. For Secret type, choose Other type of secret.
    
            1. Select the `Plaintext` test tab, select all text in the textbox and delete it.
    
            1. Paste your Private key into the textbox
    
            1. Choose Next
    
        4. On the Configure secret page, do the following:
            1. Enter a descriptive Secret name and Description. Note that the name chosen here will also be used as the name of the credentials within Jenkins.
    
            1. In the Tags section, add the 2 required tags for the [AWS Secrets Manager Credentials Provider](https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/) Plugin
                * `jenkins:credentials:type` = `sshUserPrivateKey`
                * `jenkins:credentials:username` = `<username>`


                !!! info
                    The username will depend on the image being used for the build agent.
    
                    * Amazon Linux -> `ec2-user`
                    * Ubuntu -> `ubuntu`
                    * Windows -> `Administrator`


            1. Choose Next.
    
        6. On the Review page, review your secret details, and then choose Store.

#### Connect Jenkins to the Build Farm

1. From the Jenkins homepage, on the left-hand side, choose `Manage Jenkins`.
2. Under the `System Configuration` section, choose `Clouds`
3. Select `New Cloud`
3. Enter a name for your cloud configuration
4. Select `Amazon EC2 Fleet`
5. Click `Create`
6. On the `New Cloud` configuration page, change the following settings.
    1. **Region** - Select the region in which you deployed the module
    1. **EC2 Fleet** - Select the autoscaling group created by the module
    1. **Launcher** - Select `Launch agents via SSH`
    1. **Launcher** -> **Credentials** - Select the credentials created in the previous step
    1. **Launcher** -> **Host Key Verification Strategy** - Select `Non verifying Verification Strategy`
    1. **Connect to instaces via private IP instead of public IP** - Select the `Private IP` check box
    1. **Max Idle Minutes Before Scaledown** - Set this variable to `5` (minutes). Feel free to change this based on your needs.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.50 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.59.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.jenkins_build_farm_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.jenkins_service_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.jenkins_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.jenkins_cluster_fargate_rpvodiers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.jenkins_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.jenkins_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_efs_access_point.jenkins_efs_access_point](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.jenkins_efs_file_system](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.jenkins_efs_mount_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_fsx_openzfs_file_system.jenkins_build_farm_fsxz_file_system](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_openzfs_file_system) | resource |
| [aws_fsx_openzfs_volume.jenkins_build_farm_fsxz_volume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_openzfs_volume) | resource |
| [aws_iam_instance_profile.build_farm_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.build_farm_fsxz_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.build_farm_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ec2_fleet_plugin_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.jenkins_default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.build_farm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.jenkins_default_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.jenkins_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ec2_fleet_plugin_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.jenkins_build_farm_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.jenkins_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.jenkins_alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.jenkins_alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.artifact_buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.jenkins_alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.artifacts_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.artifact_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.jenkins_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.jenkins_build_farm_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.jenkins_build_storage_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.jenkins_efs_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.jenkins_service_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.jenkins_alb_outbound_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.jenkins_build_farm_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.jenkins_build_farm_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.jenkins_service_outbound_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.jenkins_service_outbound_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_build_farm_inbound_ssh_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_build_vpc_all_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_efs_inbound_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.jenkins_service_inbound_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.artifact_buckets](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.build_farm](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.fsxz](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.jenkins](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.jenkins_alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_cluster.jenkins_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.build_farm_fsxz_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.build_farm_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_fleet_plugin_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_tasks_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.jenkins_default_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.build_farm_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_artifact_buckets"></a> [artifact\_buckets](#input\_artifact\_buckets) | List of Amazon S3 buckets you wish to create to store build farm artifacts. | <pre>map(<br>    object({<br>      name                 = string<br>      enable_force_destroy = optional(bool, true)<br>      enable_versioning    = optional(bool, true)<br>      tags                 = optional(map(string), {})<br>    })<br>  )</pre> | `null` | no |
| <a name="input_build_farm_compute"></a> [build\_farm\_compute](#input\_build\_farm\_compute) | Each object in this map corresponds to an ASG used by Jenkins as build agents. | <pre>map(object(<br>    {<br>      ami = string<br>      #TODO: Support mixed instances / spot with custom policies<br>      instance_type     = string<br>      ebs_optimized     = optional(bool, true)<br>      enable_monitoring = optional(bool, true)<br>    }<br>  ))</pre> | `{}` | no |
| <a name="input_build_farm_fsx_openzfs_storage"></a> [build\_farm\_fsx\_openzfs\_storage](#input\_build\_farm\_fsx\_openzfs\_storage) | Each object in this map corresponds to an FSx OpenZFS file system used by the Jenkins build agents. | <pre>map(object(<br>    {<br>      storage_capacity    = number<br>      throughput_capacity = number<br>      storage_type        = optional(string, "SSD") # "SSD", "HDD"<br>      deployment_type     = optional(string, "SINGLE_AZ_1")<br>      route_table_ids     = optional(list(string), null)<br>      tags                = optional(map(string), null)<br>    }<br>  ))</pre> | `{}` | no |
| <a name="input_build_farm_subnets"></a> [build\_farm\_subnets](#input\_build\_farm\_subnets) | The subnets to deploy the build farms into. | `list(string)` | n/a | yes |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The TLS certificate ARN for the Jenkins service load balancer. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The ARN of the cluster to deploy the Jenkins service into. Defaults to null and a cluster will be created. | `string` | `null` | no |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | The CPU allotment for the Jenkins container. | `number` | `1024` | no |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | The memory allotment for the Jenkins container. | `number` | `4096` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | The name of the Jenkins service container. | `string` | `"jenkins-container"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The container port used by the Jenkins service container. | `number` | `8080` | no |
| <a name="input_create_ec2_fleet_plugin_policy"></a> [create\_ec2\_fleet\_plugin\_policy](#input\_create\_ec2\_fleet\_plugin\_policy) | Optional creation of IAM Policy required for Jenkins EC2 Fleet plugin. Default is set to false. | `bool` | `false` | no |
| <a name="input_create_jenkins_default_policy"></a> [create\_jenkins\_default\_policy](#input\_create\_jenkins\_default\_policy) | Optional creation of Jenkins Default IAM Policy. Default is set to true. | `bool` | `true` | no |
| <a name="input_create_jenkins_default_role"></a> [create\_jenkins\_default\_role](#input\_create\_jenkins\_default\_role) | Optional creation of Jenkins Default IAM Role. Default is set to true. | `bool` | `true` | no |
| <a name="input_custom_jenkins_role"></a> [custom\_jenkins\_role](#input\_custom\_jenkins\_role) | ARN of the custom IAM Role you wish to use with Jenkins. | `string` | `null` | no |
| <a name="input_enable_jenkins_alb_access_logs"></a> [enable\_jenkins\_alb\_access\_logs](#input\_enable\_jenkins\_alb\_access\_logs) | Enables access logging for the Jenkins ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_enable_jenkins_alb_deletion_protection"></a> [enable\_jenkins\_alb\_deletion\_protection](#input\_enable\_jenkins\_alb\_deletion\_protection) | Enables deletion protection for the Jenkins ALB. Defaults to true. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| <a name="input_existing_artifact_buckets"></a> [existing\_artifact\_buckets](#input\_existing\_artifact\_buckets) | List of ARNs of the S3 buckets used to store artifacts created by the build farm. | `list(string)` | `[]` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the Jenkins service load balancer. | `list(string)` | `null` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the Jenkins service load balancer to have a public IP. | `bool` | `false` | no |
| <a name="input_jenkins_agent_secret_arns"></a> [jenkins\_agent\_secret\_arns](#input\_jenkins\_agent\_secret\_arns) | A list of secretmanager ARNs (wildcards allowed) that contain any secrets which need to be accessed by the Jenkins service. | `list(string)` | `null` | no |
| <a name="input_jenkins_alb_access_logs_bucket"></a> [jenkins\_alb\_access\_logs\_bucket](#input\_jenkins\_alb\_access\_logs\_bucket) | ID of the S3 bucket for Jenkins ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_jenkins_alb_access_logs_prefix"></a> [jenkins\_alb\_access\_logs\_prefix](#input\_jenkins\_alb\_access\_logs\_prefix) | Log prefix for Jenkins ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_jenkins_alb_subnets"></a> [jenkins\_alb\_subnets](#input\_jenkins\_alb\_subnets) | A list of subnet ids to deploy the Jenkins load balancer into. Public subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_jenkins_cloudwatch_log_retention_in_days"></a> [jenkins\_cloudwatch\_log\_retention\_in\_days](#input\_jenkins\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the cloudwatch log group for Jenkins. | `string` | `365` | no |
| <a name="input_jenkins_efs_performance_mode"></a> [jenkins\_efs\_performance\_mode](#input\_jenkins\_efs\_performance\_mode) | The performance mode of the EFS file system used by the Jenkins service. Defaults to general purpose. | `string` | `"generalPurpose"` | no |
| <a name="input_jenkins_efs_throughput_mode"></a> [jenkins\_efs\_throughput\_mode](#input\_jenkins\_efs\_throughput\_mode) | The throughput mode of the EFS file system used by the Jenkins service. Defaults to bursting. | `string` | `"bursting"` | no |
| <a name="input_jenkins_service_desired_container_count"></a> [jenkins\_service\_desired\_container\_count](#input\_jenkins\_service\_desired\_container\_count) | The desired number of containers running the Jenkins service. | `number` | `1` | no |
| <a name="input_jenkins_service_subnets"></a> [jenkins\_service\_subnets](#input\_jenkins\_service\_subnets) | A list of subnets to deploy the Jenkins service into. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name attached to Jenkins module resources. | `string` | `"jenkins"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appeneded to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br>  "IAC_MANAGEMENT": "CGD-Toolkit",<br>  "IAC_MODULE": "Jenkins",<br>  "IAC_PROVIDER": "Terraform"<br>}</pre> | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy the Jenkins service and build farms into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_security_group"></a> [alb\_security\_group](#output\_alb\_security\_group) | Security group associated with the Jenkins load balancer |
| <a name="output_build_farm_security_group"></a> [build\_farm\_security\_group](#output\_build\_farm\_security\_group) | Security group associated with the build farm autoscaling groups |
| <a name="output_jenkins_alb_dns_name"></a> [jenkins\_alb\_dns\_name](#output\_jenkins\_alb\_dns\_name) | The DNS name of the Jenkins application load balancer. |
| <a name="output_jenkins_alb_zone_id"></a> [jenkins\_alb\_zone\_id](#output\_jenkins\_alb\_zone\_id) | The zone ID of the Jenkins ALB. |
| <a name="output_service_security_group"></a> [service\_security\_group](#output\_service\_security\_group) | Security group associated with the ECS service hosting jenkins |
<!-- END_TF_DOCS -->
