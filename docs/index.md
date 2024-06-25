# Welcome to the Cloud Game Development Toolkit

The **Cloud Game Development Toolkit (a.k.a. CGD Toolkit)** is a collection of templates and configurations for deploying game development infrastructure and tools on AWS.

!!! info
    **This project is under active development and community contributions are welcomed!**. If you would like to see something in this repository please create a <a href="https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE" target="_blank">feature request</a> in the Issues tab. If you'd like to contribute, raise a <a href="https://github.com/aws-games/cloud-game-development-toolkit/pulls/" target="_blank">pull request</a>. You'll find our contribution guidelines [here](./contributing.md).

## Introduction

The **CGD Toolkit** consists of three key components:

<div class="grid cards" markdown>

-   __Assets__

    ---

    Assets are reusable scripts (i.e. [Ansible Playbooks](https://github.com/ansible/ansible)), pipeline definitions (i.e. [Jenkins Pipelines](https://www.jenkins.io/doc/book/pipeline/)), [Dockerfiles](https://docs.docker.com/reference/dockerfile/), [Packer](https://www.packer.io/) templates, and other resources that might prove useful for common game development workloads.

    [:octicons-arrow-right-24: Learn about Assets](./assets)

-   __Modules__

    ---

    Configurable [Terraform](https://www.terraform.io/) modules for simplified cloud deployment with best-practices by default.

    [:octicons-arrow-right-24: Learn about Modules](./modules)

-   __Samples__

    ---

    Complete Terraform configurations for expedited studio setup that demonstrate module usage and integration with other AWS services.

    [:octicons-arrow-right-24: Learn about Samples](./samples)

</div>


## Getting Started

Check the [Getting Started](getting-started.md).