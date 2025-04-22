---
title: TeamCity Example
description: TeamCity Deployment Example
---

# TeamCity Deployment Example

This example provisions [TeamCity](https://www.jetbrains.com/teamcity/) and several AWS resources, such as VPC and DNS resources, more details below.

## Variables

This example takes in one input variables:`root_domain_name`.

### `root_domain_name`

The `root_domain_name` is expected to correspond to an existing [AWS Route53 hosted zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/route-53-concepts.html#route-53-concepts-hosted-zone). This hosted zone is used for provisioning DNS records used for external and internal routing, and enables this example to create validated SSL certificates on your behalf.

If you do not have a domain yet you can [register one through Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html#domain-register-procedure-section).

If you already have a domain with a different domain registrar you can leverage Route53 for DNS services. [Please review the documentation for migrating to Route53 as your DNS provider.](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html)

If you own the domain: "example.com" this example will deploy TeamCity to "teamcity.example.com" - this can be modified from the `dns.tf` file.


## Deployment

This example provisions the TeamCity module into a new VPC with freshly deployed resources from the module. A TeamCity server is deployed using an Amazon Elastic Container Service (ECS) service. The server will have an attached Elastic File System (EFS), which acts as a shared, persistent data store. The module also deploys an Amazon Aurora Serverless V2 Postgresql Cluster.

To deploy this example please initialize the project with `terraform init`. Deployment is then as simple as `terraform apply`.
