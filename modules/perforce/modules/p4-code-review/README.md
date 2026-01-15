# P4 Code Review Submodule

[P4 Code Review](https://www.perforce.com/products/helix-swarm) is a free code review tool for projects hosted in [P4 Server](https://www.perforce.com/products/helix-core/aws). This module deploys P4 Code Review on an EC2 Auto Scaling Group using a custom AMI built with [Packer](../../../../assets/packer/perforce/p4-code-review/README.md).

P4 Code Review also relies on a Redis cache. The module provisions a single node AWS Elasticache Redis OSS cluster and configures connectivity for the P4 Code Review service.

This module deploys the following resources:

- An EC2 Auto Scaling Group running the P4 Code Review AMI (built using the [Packer template](../../../../assets/packer/perforce/p4-code-review/README.md)).
- A persistent EBS volume for P4 Code Review data that survives instance replacement.
- An Application Load Balancer for TLS termination of the P4 Code Review service.
- A single node [AWS Elasticache Redis OSS](https://aws.amazon.com/elasticache/redis/) cluster.
- Supporting resources such as CloudWatch log groups, IAM roles, and security groups.

## Architecture

![P4 Code Review Architecture](../../assets/media/diagrams/p4-code-review-architecture.png)

## Prerequisites

P4 Code Review needs to be able to connect to a P4 Server. P4 Code Review leverages the same authentication mechanism as P4 Server, and needs to install required plugins on the upstream P4 Server instance during setup. This happens automatically, but P4 Code Review requires an administrative user's credentials to be able to initially connect. These credentials are provided to the module through variables specifying AWS Secrets Manager secrets, and then pulled into the P4 Code Review instance during startup. See the `p4d_super_user_arn`, `p4d_super_user_password_arn`, `p4d_swarm_user_arn`, and `p4d_swarm_password_arn` variables below for more details.

The [P4 Server submodule](../p4-server/README.md) creates an administrative user on initial deployment, and stores the credentials in AWS Secrets manager. The ARN of the credentials secret is then made available as a Terraform output from the module, and can be referenced elsewhere. The is done by default by the parent Perforce module.

Should you need to manually create the administrative user secret the following AWS CLI command may prove useful:

```bash
aws secretsmanager create-secret \
    --name P4CodeReviewSuperUser \
    --description "P4 Code Review Super User" \
    --secret-string "{\"username\":\"swarm\",\"password\":\"EXAMPLE-PASSWORD\"}"
```

You can then provide these credentials as variables when you define the P4 Code Review module in your Terraform configurations (the parent Perforce module does this for you):

```hcl
module "p4_code_review" {
    source = "modules/perforce/modules/p4-code-review"
    ...
    p4d_super_user_arn = "arn:aws:secretsmanager:<your-aws-region>:<your-aws-account-id>:secret:P4CodeReviewSuperUser-a1b2c3:username::"
    p4d_super_user_password_arn = "arn:aws:secretsmanager:<your-aws-region>:<your-aws-account-id>:secret:P4CodeReviewSuperUser-a1b2c3:password::"
}
```

## Debugging

If you're running into issues with P4 Code Review, here are some common log files to investigate:

- `/var/log/apache2/swarm.error_log`: any PHP / configuration related errors
- `/opt/perforce/swarm/data/configure-swarm.log`: errors coming from p4cr configuration
- `/opt/perforce/swarm/data/log`: errors from the p4cr runtime

## Custom Configuration

The `custom_config` variable allows you to pass additional configuration to P4 Code Review as a JSON string. This configuration is merged with the generated `config.php` using PHP's `array_replace_recursive` function at instance startup.

This can be used to configure:

- SSO/SAML authentication
- Email notifications
- Jira integration
- Project settings
- And any other [Swarm configuration option](https://www.perforce.com/manuals/swarm/Content/Swarm/admin.configuration.html)

### Example: SSO/SAML with Auth0

SSO/SAML configuration requires two parts:

1. **`p4.sso`** - Enables the SSO login option. Values:
   - `"disabled"` - No SSO, only password login (default)
   - `"optional"` - Both SSO and password login available
   - `"enabled"` - SSO only, no password login

2. **`saml`** - The SAML technical configuration (IdP/SP settings, certificates)

```hcl
module "p4_code_review" {
  source = "modules/perforce/modules/p4-code-review"
  # ... other required variables ...

  custom_config = jsonencode({
    # Enable SSO login option
    p4 = {
      sso = "optional"
    }
    # SAML configuration
    saml = {
      header = "Log in with SSO"
      sp = {
        entityId                  = "https://swarm.example.com"
        assertionConsumerService = {
          url = "https://swarm.example.com/saml/acs"
        }
        singleLogoutService = {
          url = "https://swarm.example.com/saml/sls"
        }
        NameIDFormat = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      }
      idp = {
        entityId                 = "urn:your-auth0-domain"
        singleSignOnService = {
          url = "https://your-auth0-domain/samlp/YOUR_CLIENT_ID"
        }
        singleLogoutService = {
          url = "https://your-auth0-domain/samlp/YOUR_CLIENT_ID/logout"
        }
        x509cert = "YOUR_IDP_CERTIFICATE_HERE"
      }
    }
  })
}
```

### Example: Email Notifications

```hcl
module "p4_code_review" {
  source = "modules/perforce/modules/p4-code-review"
  # ... other required variables ...

  custom_config = jsonencode({
    mail = {
      transport = {
        host = "smtp.example.com"
        port = 587
        security = "tls"
      }
      sender = "swarm@example.com"
    }
  })
}
```

### Example: Jira Integration

```hcl
module "p4_code_review" {
  source = "modules/perforce/modules/p4-code-review"
  # ... other required variables ...

  custom_config = jsonencode({
    jira = {
      host     = "https://your-company.atlassian.net"
      user     = "jira-user@example.com"
      password = "your-api-token"
      job_field = "customfield_10001"
    }
  })
}
```

### Combining Multiple Configurations

You can combine multiple configuration sections in a single `custom_config`:

```hcl
custom_config = jsonencode({
  saml = {
    # SSO configuration...
  }
  mail = {
    # Email configuration...
  }
  jira = {
    # Jira configuration...
  }
})
```

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.6 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.6 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.7 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.swarm_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.application_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.redis_service_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ebs_volume.swarm_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_elasticache_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_cluster) | resource |
| [aws_elasticache_subnet_group.subnet_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_instance_profile.ec2_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.ebs_attachment_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ec2_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ec2_instance_role_ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ec2_instance_role_secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ec2_instance_role_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.swarm_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.alb_https_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.alb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.alb_access_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.alb_access_logs_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs_bucket_public_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.elasticache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.alb_outbound_to_application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.application_outbound_to_internet_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.application_outbound_to_internet_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ec2_instance_outbound_to_internet_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ec2_instance_outbound_to_internet_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_inbound_from_application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.application_inbound_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.elasticache_inbound_from_application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.alb_access_logs_bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.p4_code_review](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ami.p4_code_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.access_logs_bucket_alb_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ebs_attachment_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_instance_trust_relationship](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets_manager_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.instance_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_subnet_id"></a> [instance\_subnet\_id](#input\_instance\_subnet\_id) | The subnet ID where the EC2 instance will be launched. Should be a private subnet for security. | `string` | n/a | yes |
| <a name="input_p4_code_review_user_password_secret_arn"></a> [p4\_code\_review\_user\_password\_secret\_arn](#input\_p4\_code\_review\_user\_password\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the p4d P4 Code Review password. | `string` | n/a | yes |
| <a name="input_p4_code_review_user_username_secret_arn"></a> [p4\_code\_review\_user\_username\_secret\_arn](#input\_p4\_code\_review\_user\_username\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the p4d P4 Code Review username. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of subnets for ElastiCache Redis deployment. Private subnets are recommended. | `list(string)` | n/a | yes |
| <a name="input_super_user_password_secret_arn"></a> [super\_user\_password\_secret\_arn](#input\_super\_user\_password\_secret\_arn) | Optionally provide the ARN of an AWS Secret for the p4d super user password. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the existing VPC you would like to deploy P4 Code Review into. | `string` | n/a | yes |
| <a name="input_alb_access_logs_bucket"></a> [alb\_access\_logs\_bucket](#input\_alb\_access\_logs\_bucket) | ID of the S3 bucket for P4 Code Review ALB access log storage. If access logging is enabled and this is null the module creates a bucket. | `string` | `null` | no |
| <a name="input_alb_access_logs_prefix"></a> [alb\_access\_logs\_prefix](#input\_alb\_access\_logs\_prefix) | Log prefix for P4 Code Review ALB access logs. If null the project prefix and module name are used. | `string` | `null` | no |
| <a name="input_alb_subnets"></a> [alb\_subnets](#input\_alb\_subnets) | A list of subnets to deploy the load balancer into. Public subnets are recommended. | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | Optional AMI ID for P4 Code Review. If not provided, will use the latest Packer-built AMI with name pattern 'p4\_code\_review\_ubuntu-*'. | `string` | `null` | no |
| <a name="input_application_load_balancer_name"></a> [application\_load\_balancer\_name](#input\_application\_load\_balancer\_name) | The name of the P4 Code Review ALB. Defaults to the project prefix and module name. | `string` | `null` | no |
| <a name="input_application_port"></a> [application\_port](#input\_application\_port) | The port that P4 Code Review listens on. Used for ALB target group configuration. | `number` | `80` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The TLS certificate ARN for the P4 Code Review service load balancer. | `string` | `null` | no |
| <a name="input_cloudwatch_log_retention_in_days"></a> [cloudwatch\_log\_retention\_in\_days](#input\_cloudwatch\_log\_retention\_in\_days) | The log retention in days of the cloudwatch log group for P4 Code Review. | `string` | `365` | no |
| <a name="input_create_application_load_balancer"></a> [create\_application\_load\_balancer](#input\_create\_application\_load\_balancer) | This flag controls the creation of an application load balancer as part of the module. | `bool` | `true` | no |
| <a name="input_custom_config"></a> [custom\_config](#input\_custom\_config) | JSON string with additional Swarm configuration to merge with the generated config.php. Use this for SSO/SAML setup, notifications, Jira integration, etc. See README for examples. | `string` | `null` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | The amount of time to wait for in-flight requests to complete while deregistering a target. The range is 0-3600 seconds. | `number` | `30` | no |
| <a name="input_ebs_availability_zone"></a> [ebs\_availability\_zone](#input\_ebs\_availability\_zone) | Availability zone for the EBS volume. Must match the EC2 instance AZ. If not provided, will use the AZ of the instance\_subnet\_id. | `string` | `null` | no |
| <a name="input_ebs_volume_encrypted"></a> [ebs\_volume\_encrypted](#input\_ebs\_volume\_encrypted) | Enable encryption for the EBS volume storing P4 Code Review data. | `bool` | `true` | no |
| <a name="input_ebs_volume_size"></a> [ebs\_volume\_size](#input\_ebs\_volume\_size) | Size in GB for the EBS volume that stores P4 Code Review data (/opt/perforce/swarm/data). This volume persists across instance replacement. | `number` | `20` | no |
| <a name="input_ebs_volume_type"></a> [ebs\_volume\_type](#input\_ebs\_volume\_type) | EBS volume type for P4 Code Review data storage. | `string` | `"gp3"` | no |
| <a name="input_elasticache_node_count"></a> [elasticache\_node\_count](#input\_elasticache\_node\_count) | Number of cache nodes to provision in the Elasticache cluster. | `number` | `1` | no |
| <a name="input_elasticache_node_type"></a> [elasticache\_node\_type](#input\_elasticache\_node\_type) | The type of nodes provisioned in the Elasticache cluster. | `string` | `"cache.t4g.micro"` | no |
| <a name="input_enable_alb_access_logs"></a> [enable\_alb\_access\_logs](#input\_enable\_alb\_access\_logs) | Enables access logging for the P4 Code Review ALB. Defaults to false. | `bool` | `false` | no |
| <a name="input_enable_alb_deletion_protection"></a> [enable\_alb\_deletion\_protection](#input\_enable\_alb\_deletion\_protection) | Enables deletion protection for the P4 Code Review ALB. Defaults to true. | `bool` | `false` | no |
| <a name="input_existing_redis_connection"></a> [existing\_redis\_connection](#input\_existing\_redis\_connection) | The connection specifications to use for an existing Redis deployment. | <pre>object({<br/>    host = string<br/>    port = number<br/>  })</pre> | `null` | no |
| <a name="input_existing_security_groups"></a> [existing\_security\_groups](#input\_existing\_security\_groups) | A list of existing security group IDs to attach to the P4 Code Review load balancer. | `list(string)` | `[]` | no |
| <a name="input_fully_qualified_domain_name"></a> [fully\_qualified\_domain\_name](#input\_fully\_qualified\_domain\_name) | The fully qualified domain name that P4 Code Review should use for internal URLs. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for running P4 Code Review. Swarm requires persistent storage and runs natively on EC2. | `string` | `"m5.large"` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Set this flag to true if you do not want the P4 Code Review service load balancer to have a public IP. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The name attached to P4 Code Review module resources. | `string` | `"p4-code-review"` | no |
| <a name="input_p4charset"></a> [p4charset](#input\_p4charset) | The P4CHARSET environment variable to set for the P4 Code Review instance. | `string` | `"none"` | no |
| <a name="input_p4d_port"></a> [p4d\_port](#input\_p4d\_port) | The P4D\_PORT environment variable where P4 Code Review should look for P4 Server. Defaults to 'ssl:perforce:1666' | `string` | `"ssl:perforce:1666"` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The project prefix for this workload. This is appended to the beginning of most resource names. | `string` | `"cgd"` | no |
| <a name="input_s3_enable_force_destroy"></a> [s3\_enable\_force\_destroy](#input\_s3\_enable\_force\_destroy) | Enables force destroy for the S3 bucket for P4 Code Review access log storage. Defaults to true. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources. | `map(any)` | <pre>{<br/>  "IaC": "Terraform",<br/>  "ModuleBy": "CGD-Toolkit",<br/>  "ModuleName": "p4-code-review",<br/>  "ModuleSource": "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce",<br/>  "RootModuleName": "terraform-aws-perforce"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | The DNS name of the P4 Code Review ALB |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group associated with the P4 Code Review load balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | The hosted zone ID of the P4 Code Review ALB |
| <a name="output_application_security_group_id"></a> [application\_security\_group\_id](#output\_application\_security\_group\_id) | Security group associated with the P4 Code Review application |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | The name of the Auto Scaling Group for P4 Code Review |
| <a name="output_ebs_volume_id"></a> [ebs\_volume\_id](#output\_ebs\_volume\_id) | The ID of the EBS volume storing P4 Code Review persistent data |
| <a name="output_instance_profile_arn"></a> [instance\_profile\_arn](#output\_instance\_profile\_arn) | The ARN of the IAM instance profile for P4 Code Review EC2 instances |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | The ID of the launch template for P4 Code Review instances |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | The target group ARN for P4 Code Review |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
