---
title: Assets
description: Re-usable assets for game development on AWS
---

# Assets

**Assets** are reusable scripts, pipeline definitions, Dockerfiles, Packer templates, and other resources that might prove useful or are dependencies of any of the modules.

!!! info
    **Don't see an asset listed?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new asset or learn [how to contribute new assets to the project](../../CONTRIBUTING.md)

| Asset Type | Description |
| :--------------------------------------------------------------- | :- |
| [:simple-packer: **Packer Templates**](./packer/index.md)              | Packer templates provide an easy way to build machine images for commonly used game dev infrastructure. Currently the project includes Packer templates for UE5 build agents for Linux and Windows, as well as a Packer template for building a Perforce Helix Core version control AMI. |
| [:simple-jenkins: **Jenkins Pipelines**](../../assets/jenkins-pipelines/README.md) | Jenkins Pipelines for common game dev automation workflows |
| [:simple-ansible: **Ansible Playbooks**](../../assets/ansible-playbooks/perforce/p4-server/README.md)         | Automation scripts for reusable system level configurations. Unlike Packer templates, you can use these to add new functionality to existing EC2 instances. |
| [:simple-docker: **Dockerfiles (Coming Soon!)**](./dockerfiles.md)              | Dockerfiles for creating Docker images of commonly used game dev infrastructure. These are primarily used in scenarios where there aren't openly available pre-built images that address a use case, or significant customization is needed that warrants building an image |
