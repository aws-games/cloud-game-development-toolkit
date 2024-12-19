---
title: Simple Build Pipeline Sample
description: Game build pipeline sample implementation on AWS
---

# Simple Build Pipeline Sample

The Simple Build Pipeline is the best place to get started when first exploring the Cloud Game Development Toolkit. It encapsulates many of the available modules alongside best practice deployments of core AWS services. The Simple Build Pipeline provisions a well-architected Virtual Private Cloud ([VPC](https://aws.amazon.com/vpc/)), a skeleton for managing DNS and SSL certificates with [Route 53](https://aws.amazon.com/route53/) and AWS Certificate Manager([ACM](https://aws.amazon.com/certificate-manager/)), [Jenkins](https://www.jenkins.io/) for continuous integration and deployment, [Perforce Helix Core](https://www.perforce.com/products/helix-core/aws) for version control, [Perforce Helix Swarm](https://www.perforce.com/products/helix-swarm) for code review, and [Perforce Helix Authentication Service](https://github.com/perforce/helix-authentication-service) for external identity provider integrations.

## Predeployment

There are a few prerequisites that need to be completed **prior** to deploying this sample architecture. We'll walk through those here.

### 1. Domain Name System (DNS) Resolution

The Simple Build Pipeline will deploy a number of web-based applications into your AWS account. The Cloud Game Development Toolkit attempts to follow a "secure-by-default" design pattern, so HTTPS is the standard protocol for all applications deployed by the Toolkit.

All applications deployed by the Simple Build Pipeline use Route 53, Amazon's highly available and scalable DNS service, for routing traffic from the internet. All you need to provide is the root hosted zone you would like the Simple Build Pipeline to use, and your Jenkins and Perforce applications will be provisioned as sub-domains. Route53 will need to be able to validate ownership of this domain, so make sure you are using a domain that you have complete control over.

If you do not have a domain yet you can [register one through Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure-section).

If you already have a domain with a different domain registrar you can leverage Route53 for DNS services. [Please review the documentation for migrating to Route53 as your DNS provider.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html)

Regardless, the Simple Build Pipeline requires the **fully qualified domain name (FQDN)** that you would like resources to be provisioned under. If you own the domain: "example.com" the simple build pipeline would deploy Jenkins to "jenkins.example.com" and Helix Swarm to "swarm.helix.example.com" - this can be modified from the `dns.tf` file.

### 2. Jenkins Build Farm

The [Jenkins module](../modules/jenkins/jenkins.md) provisions the Jenkins coordinator as a service on Amazon Elastic Container Service ([ECS](https://aws.amazon.com/ecs)). It also provisions any number of [EC2 autoscaling groups](https://aws.amazon.com/ec2/autoscaling/) to be used as build nodes by Jenkins, and any number of [Amazon FSx for OpenZFS filesystems](https://aws.amazon.com/fsx/openzfs/) to be used as shared storage by those build nodes.

By default, the Simple Build Pipelines will not provision any autoscaling groups or any filesystems. These are configured through the [`local.tf`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/local.tf) file.

To add an autoscaling group you need to specify an [instance type](https://aws.amazon.com/ec2/instance-types/) and an Amazon Machine Image ([AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)). The instance type specifies the hardware of your build nodes, and the AMI contains all of the tooling and software you would like those machines to contain on startup. The Cloud Game Development Toolkit provides a number of [Packer templates](../assets/packer/index.md) for useful game development AMIs. We recommend reviewing this documentation before adding build nodes to your Simple Build Pipeline.

Your build nodes may also need access to credentials or other secrets. These can be uploaded to [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) and then passed to your Jenkins build nodes with the `jenkins_agent_secret_arns` local variable.

## Deployment

Deployment of the Simple Build Pipeline is relatively straightforward once you have completed the prerequisites. The necessary variables can be passed to Terraform configuration through the variables in the Simple Build Pipeline's [local.tf](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/local.tf) file.

``` hcl
# local.tf

locals {

  fully_qualified_domain_name = "www.example.com"

  build_farm_compute = {
      graviton_builders : {
          ami = "ami-0a1b2c3d4e5f"
          instance_type = "c7g.large"
      }
      windows_builders : {
          ami = "ami-9z8y7x6w5v"
          instance_type = "c7a.large"
      }
  }

  build_farm_fsx_openzfs_storage = {
      cache : {
        storage_type        = "SSD"
        throughput_capacity = 160
        storage_capacity    = 256
        deployment_type     = "MULTI_AZ_1"
        route_table_ids     = [aws_route_table.private_rt.id]
      }
      workspace : {
        storage_type        = "SSD"
        throughput_capacity = 160
        storage_capacity    = 564
        deployment_type     = "MULTI_AZ_1"
        route_table_ids     = [aws_route_table.private_rt.id]
      }
  }


}
```

Once you have defined your variables deploying the sample is as easy as running the following:

``` bash
terraform apply
```

The deployment can take close to ten minutes. Creating the certificates and performing DNS validation against them generally is the last thing to complete. This happens automatically.

## Postdeployment

After the Simple Build Pipeline deploys you still need to configure the underlying applications.

### 1. Jenkins

Jenkins requires a couple of plugins to be able to send build jobs to the provisioned autoscaling groups. These plugins are outlined in the [Jenkins documentation](../modules/jenkins/jenkins.md). In the future we will automate the installation of these plugins.

To gain access to your new Jenkins deployment you will need to modify the `jenkins ALB security group` to allowlist your IP address. We recommend doing this with Terraform.

Navigate to [`main.tf`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/main.tf) and add the following block at the bottom. Make sure to replace "IP_PLACEHOLDER" with your IP address.

``` hcl
resource "aws_vpc_security_group_ingress_rule" "jenkins_inbound_personal" {
  security_group_id            = module.jenkins.alb_security_group
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  cidr_blocks                  = ["IP_PLACEHOLDER/32"]
  description                  = "Grants personal access to Jenkins."
}
```

You will need to run `terraform apply` to deploy this change.

Now that you are able to access Jenkins you'll need to configure the plugins, cloud based agents, and credentials that Jenkins has access to. Please consult the [Jenkins documentation](../modules/jenkins/jenkins.md) for these steps.

### 2. Helix Authentication Service

In order to use your external identity provider with Helix Core and Helix Swarm you will need to configure a OIDC or SAML connection in the Helix Authentication Service. The Helix Authentication Service module provides a web-based UI to do this.

To gain access to this UI you will need to modify the `helix authentication service ALB security group` to allowlist your IP address. We recommend doing this with Terraform.

Navigate to [`main.tf`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/main.tf) and add the following block at the bottom. Make sure to replace "IP_PLACEHOLDER" with your IP address.

``` hcl
resource "aws_vpc_security_group_ingress_rule" "helix_auth_service_inbound_personal" {
  security_group_id            = module.helix_authentication_service.alb_security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  cidr_blocks                  = ["IP_PLACEHOLDER/32"]
  description                  = "Grants personal access Helix Authentication Service."
}
```

You will need to run `terraform apply` to deploy this change.

You should now be able to access the Helix Authentication Service's web based UI. Please consult the [Helix Authentication Service documentation](../modules/perforce/helix-authentication-service/helix-authentication-service.md) for guidance on logging in and configuring your external IDP.

### 3. Helix Core and Helix Swarm

Helix Core and Helix Swarm are configured to leverage the Helix Authentication Service for sign-in out of the box. However, they are not exposed to the public internet by default. You will need to create rules on the `helix core security group` and the `helix swarm security group` that grant personal access. As above, we recommend doing this with Terraform:


Navigate to [`main.tf`](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/samples/simple-build-pipeline/main.tf) and add the following block at the bottom. Make sure to replace "IP_PLACEHOLDER" with your IP address.

``` hcl
resource "aws_vpc_security_group_ingress_rule" "core_inbound_personal" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  cidr_blocks                  = ["IP_PLACEHOLDER/32"]
  description                  = "Enables personal access to Helix Core."
}

resource "aws_vpc_security_group_ingress_rule" "swarm_inbound_personal" {
  security_group_id            = module.perforce_helix_swarm.alb_security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  cidr_blocks                  = ["IP_PLACEHOLDER/32"]
  description                  = "Enables personal access to Helix Swarm."
}
```

Now that you have access to Helix Core and Helix Swarm you should be able to log in with the super user credentials specified or created during deployment. This will enable you to provision other users that leverage Helix Authentication Service for single-sign-on. For more information please consult the [Helix Core documentation](../modules/perforce/helix-core/helix-core.md).
