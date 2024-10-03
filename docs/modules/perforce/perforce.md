# Perforce

[Perforce](https://www.perforce.com/) provides a number of products commonly used in Game development. The modules included in the Cloud Game Development Toolkit provision [Helix Core](https://www.perforce.com/products/helix-core), [Helix Swarm](https://www.perforce.com/products/helix-swarm), and the [Helix Authentication Service](https://www.perforce.com/downloads/helix-authentication-service). These modules can be stitched together to provision version control and code review tools for your developers.

## Modules

| Template | Description |
| :--------------------------------------------------------------- | :- |
| [__Helix Core__](./helix-core/helix-core.md) | A Terraform module for provisioning a [Helix Core](https://www.perforce.com/products/helix-core) version control server on AWS EC2. |
| [__Helix Swarm__](./helix-swarm/helix-swarm.md) | A Terraform module for provisioning [Helix Swarm](https://www.perforce.com/products/helix-swarm) on AWS Elastic Container Service. |
| [__Helix Authentication Service__](./helix-authentication-service/helix-authentication-service.md) | A Terraform module for provisioning the [Helix Authentication Service](https://www.perforce.com/downloads/helix-authentication-service) on AWS Elastic Container Service. |

## Examples

We currently provide a single, [complete example](./examples/complete.md) demonstrating deployment of all three modules in a single VPC. This example configures connectivity between each of the three modules and creates DNS records in an existing [AWS Route53](https://aws.amazon.com/route53/) for simple routing. Please use it as a starting point for your Perforce version control and code review deployments.
