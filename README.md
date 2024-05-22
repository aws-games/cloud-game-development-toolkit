# Cloud Game Development Toolkit

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Governance](#governance)
- [Security](#security)
- [License](#license)

## Introduction

The **Cloud Game Development Toolkit** expedites studio setup through industry standard tools and with best practice infrastructure configuration from AWS for Games.

The **Toolkit** consists of four key components:

1. *Assets*

Reusable Amazon Machine Image (AMI) templates written in [Packer](https://www.packer.io/) for Windows and Linux build machines as well as Perforce Helix Core and Helix Swarm workloads.

2. *Modules*

Highly configurable and extensible [Terraform](https://www.terraform.io/) modules for simplified deployment of key game development infrastructure on AWS with best-practices by default.

3. *Samples*

Complete Terraform configurations for expedited studio setup that demonstrate module usage and integration with other AWS services.

4. *Playbooks*

Automation scripts written with [Ansible](https://github.com/ansible/ansible) to configure workloads after deployment.

The **Cloud Game Development Toolkit** is designed for piecemeal usage:

- Already have a CI/CD pipeline deployed but need a build machine image? :white_check_mark:
- Looking to migrate your Perforce server from on-premise to AWS? :white_check_mark:
- Starting your new studio from the ground up and looking for an end-to-end solution? :white_check_mark:

This project is under active development. As such, we have yet to solve for many developer needs. If you would like to see something in this repository please create a feature request in the Issues tab, or raise a pull-request. You'll find our contribution guidelines [here](./CONTRIBUTING.md).

## Quick Start

We recommend starting in the [samples](./samples/README.md) directory. This folder contains references for using Terraform to manage infrastructure-as-code, and demonstrates the usage of the **Cloud Game Development Toolkit** modules.

You will also need the following tools to take advantage of all the features in the **Toolkit**:
- [Terraform CLI installation instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [Packer CLI installation instructios](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)

This repository is intended to be forked and customized to support your studio's needs. The reference architectures contained in the [samples](./samples/README.md) are a great starting point for those customizations. Check out the [README for our Perforce + Jenkins Pipeline](./samples/perforce-jenkins-pipeline/README.md) sample to get started.

## Governance

The project follows a top-down tagging structure where modules are expected to expose a `tags` variable that propogates tags down to deployed resources. For example, here are the default tags for the Jenkins module:

```hcl
default = {
    "IAC_MANAGEMENT" = "CGD-Toolkit"
    "IAC_MODULE"     = "Jenkins"
    "IAC_PROVIDER"   = "Terraform"
}
```

Modules also include the `name` and `project_prefix` (defaults to "cgd" for cloud game development) variables that are collectively used to label provisioned resources. These can also be easily overwritten to match the naming and tagging conventions your organization follow.

## Security

The default network security considerations for modules enable connection *between* provisioned resources, but not from the internet. This decision is deliberate to enable infrastructure engineers to decide how connectivity to provisioned resources should be managed. Do you use a VPN? Will you allow-list individual IP addresses?

From an Identity and Access Management (IAM) standpoint there are best-practices in place to enable limited access between services and provisioned resources. Terraform Modules are subject to [Checkov](https://www.checkov.io/) static analysis before they are released through the **Cloud Game Development Toolkit**.

If you think you’ve found a potential security issue, please do not post it in the Issues.  Instead, please follow the instructions [here](https://aws.amazon.com/security/vulnerability-reporting/) or [email AWS security directly](mailto:aws-security@amazon.com).

## License

This project is licensed under the MIT-0 License. See the [LICENSE](./LICENSE) file.

> **Note**: _“The sample code; software libraries; command line tools; proofs of concept; templates; or other related technology (including any of the foregoing that are provided by our personnel) is provided to you as AWS Content under the AWS Customer Agreement, or the relevant written agreement between you and AWS (whichever applies). You should not use this AWS Content in your production accounts, or on production or other critical data. You are responsible for testing, securing, and optimizing the AWS Content, such as sample code, as appropriate for production grade use based on your specific quality control practices and standards. Deploying AWS Content may incur AWS charges for creating or using AWS chargeable resources, such as running Amazon EC2 instances or using Amazon S3 storage.”_
