---
title: Unreal Horde Example
description: Complete example of Unreal Horde for game development on AWS
---

# Unreal Engine Horde Complete Example

This example provisions [Unreal Engine Horde](https://github.com/EpicGames/UnrealEngine/tree/5.4/Engine/Source/Programs/Horde).

## Variables

This example takes a two input variables:`root_domain_name` and `github_credentials_secret_arn`.

### `root_domain_name`

The `root_domain_name` is expected to correspond to an existing [AWS Route53 hosted zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/route-53-concepts.html#route-53-concepts-hosted-zone). This hosted zone is used for provisioning DNS records used for external and internal routing, and enables this example to create validated SSL certificates on your behalf.

If you do not have a domain yet you can [register one through Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure-section).

If you already have a domain with a different domain registrar you can leverage Route53 for DNS services. [Please review the documentation for migrating to Route53 as your DNS provider.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html)

If you own the domain: "example.com" this example will deploy Horde to "horde.example.com" - this can be modified from the `dns.tf` file.

### `github_credentials_secret_arn`

Unreal Engine Horde is only available through the Epic Games Github organization's package registry or the Unreal Engine source code. In order to get access to this software you will need to [join the Epic Games organization](https://github.com/EpicGames/Signup) on Github and accept the Unreal Engine EULA.

The `github_credentials_secret_arn` corresponds to a secret stored in AWS Secrets Manager. The Unreal Engine Horde module uses the Github credentials stored in this secret to pull the Horde container from the Epic Games Github organization. We recommend using a [Github Personal Access Token (Classic)](https://github.com/settings/tokens) in place of your password. This PAT will need `read:packages` permissions. Please consult the AWS documentation on [Using non-AWS container images in Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/private-auth.html) for more information.

This command shows how to create the secret from the AWS CLI:

```bash
aws secretsmanager create-secret \
    --name HordeGithubCredentials \
    --description "Github credentials for fetching the Unreal Engine Horde container." \
    --secret-string "{\"username\":\"<YOUR GITHUB USERNAME>\",\"password\":\"<YOUR PERSONAL ACCESS TOKEN>\"}"
```

## Deployment

This example provisions the Unreal Engine Horde module into a new VPC. It also manages DNS with Amazon Route53 and provisions an autoscaling group of Ubuntu EC2 instances that will register with the Horde server as agents on startup. These machines come prepackaged with Wine to support Windows compilation.

To deploy this example please initialize the project with `terraform init`. Deployment is then as simple as `terraform apply`.
