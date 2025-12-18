# Cloud Game Development Toolkit

[![License: MIT-0](https://img.shields.io/badge/License-MIT-0)](LICENSE)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/aws-games/cloud-game-development-toolkit/badge)](https://api.securityscorecards.dev/projects/github.com/aws-games/cloud-game-development-toolkit)

The **Cloud Game Development Toolkit (a.k.a. CGD Toolkit)** is a collection of templates and configurations for deploying game development infrastructure and tools on AWS.

The project is designed for piecemeal usage:

- Already have a CI/CD pipeline deployed but need a build machine image? :white_check_mark:
- Looking to migrate your Perforce server from on-premise to AWS? :white_check_mark:
- Starting your new studio from the ground up and looking for pre-built templates to deploy common infrastructure? :white_check_mark:

The **Toolkit** consists of three key components:

| Component | Description
|-|-|
|**Assets**| Reusable scripts, pipeline definitions, Dockerfiles, [Packer](https://www.packer.io/) templates, [Ansible](https://github.com/ansible/ansible) Playbooks to configure workloads after deployment, and other resources that might prove useful or are dependencies of any of the modules.
|**Modules**| Highly configurable and extensible [Terraform](https://www.terraform.io/) modules for simplified deployment of key game development infrastructure on AWS with best-practices by default.
|**Samples**| Complete Terraform configurations for expedited studio setup that demonstrate module usage and integration with other AWS services.

## Getting Started

**[📖 Documentation](https://aws-games.github.io/cloud-game-development-toolkit/latest/)**  |  **[💻 Contribute to the Project](https://aws-games.github.io/cloud-game-development-toolkit/latest/contributing/)**  |  **[💬 Ask Questions](https://github.com/aws-games/cloud-game-development-toolkit/discussions/)**  |  **[🚧 Roadmap](https://github.com/orgs/aws-games/projects/1/views/1)**

## Security

If you think you’ve found a potential security issue, please do not post it in the Issues.  Instead, please follow the instructions [here](https://aws.amazon.com/security/vulnerability-reporting/) or [email AWS security directly](mailto:aws-security@amazon.com).

## License

This project is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
