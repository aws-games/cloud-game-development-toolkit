# Getting Started

Welcome to the **Cloud Game Development Toolkit
**. There are a number of ways to use this repository depending on your development needs. This guide will introduce some of the key features of the project, and provide detailed instructions for deploying your game studio on AWS.

## Introduction to Repository Structure

### Assets

An _asset_ is a singular template, script, or automation document that may prove useful in isolation. Currently, the **Toolkit** contains three types of
_assets_: [Ansible playbooks](../assets/ansible-playbooks/perforce/p4-server/README.md), [Jenkins pipelines](../assets/jenkins-pipelines/README.md), and [Packer templates](../docs/assets/packer/README.md). Each of these
_assets_ can be used in isolation.

For more information about _assets_, consult the [detailed documentation](../docs/assets/index.md).

### Modules

A
_module_ is a reusable [Terraform](https://www.terraform.io/) configuration encapsulating all of the resources needed to deploy a particular workload on AWS. These modules are highly configurable through variables, and provide necessary outputs for building interconnected architectures. We recommend reviewing the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules) if you are unfamiliar with this concept. Modules are designed for you to depend on in your own Terraform modules, and we don't expect you to have to make any modifications to them; that said, if a module doesn't meet your needs, please raise an issue!

For more information about _modules_, consult the [detailed documentation](../docs/modules/index.md).

### Samples

A _sample_ is a complete reference architecture that stitches together [modules](../docs/modules/index.md) and first-party AWS services. A
_sample_ is deployed with Terraform, and is the best way to get started with the **Cloud Game Development Toolkit
**. Samples are designed for you to copy from and modify as needed to suit your architecture and needs.

> **Note:**
> Because samples may deploy resources that have unique name constraints, we cannot guarantee that two different samples can be deployed into the same AWS account without modifying either of the samples to integrate shared infrastructure or resolve conflicts. If you're interested in using functionality from multiple samples, we recommend that you use them as reference material to base your own infrastructure off of.

For more information about _samples_, consult the [detailed documentation](../samples/README.md).

If you're new to the project, we recommend starting by deploying one of the samples, such as the [Simple Build Pipeline](../samples/simple-build-pipeline/README.md).
