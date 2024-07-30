# Perforce Helix Core

[Jump to Terraform docs](./terraform-docs.md){ .md-button .md-button--primary }

[Perforce Helix Core](https://www.perforce.com/products/helix-core/aws) is a scalable version control system that helps teams manage code alongside large, digital assets and collaborate more effectively in one central, secure location. With AWS, teams can quickly deploy Helix Core and accelerate innovation.

This module provisions Perforce Helix Core on an EC2 Instance with three dedicated EBS volumes for Helix Core depots, metadata, and logs. It can also be configured to automatically install the required plugins to integrate with Perforce Helix Authentication Service. This allows end users to quickly set up single-sign-on for their Perforce Helix Core server.

## Deployment Architecture
![Helix Core Module Architecture](/docs/media/images/helix-core-architecture.png)

## Prerequisites

This module deploys Perforce Helix Core on AWS using an Amazon Machine Image (AMI) that is included in the Cloud Game Development Toolkit. You **must** provision this AMI using [Hashicorp Packer](https://www.packer.io/) prior to deploying this module. To get started consult [the documentation for the Perforce Helix Core AMI](/docs/assets/packer.md).

### Optional

You can optionally define the Helix Core super user's credentials prior to deployment. To do so, create a secret for the Helix Core super user's username and password:

```bash
aws secretsmanager create-secret \
    --name HelixCoreSuperUser \
    --description "Helix Core Super User" \
    --secret-string "{\"username\":\"admin\",\"password\":\"EXAMPLE-PASSWORD\"}"
```

You can then provide the relevant ARN as variables when you define the Helix Core module in your Terraform configurations:

```hcl
module "perforce_helix_core" {
    source = "modules/perforce/helix-core"
    ...
    helix_core_super_user_username_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:HelixCoreSuperUser-a1b2c3:username::"
    helix_core_super_user_password_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:HelixCoreSuperUser-a1b2c3:password::"
}
```

If you do not provide these the module will create a random Super User and create the secret for you. The ARN of this secret is then available as an output to be referenced elsewhere.
