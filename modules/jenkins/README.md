# Jenkins Module

For more details, check out the [module documentation](https://aws-games.github.io/cloud-game-development-toolkit/latest/modules/jenkins/)

Jenkins is an open source automation server that simplifies repeatable software development tasks such as building, testing, and deploying applications. This module deploys Jenkins on an Elastic Container Service (ECS) cluster backed by AWS Fargate using the latest Jenkins container image ([jenkins/jenkins:lts-jdk17](https://hub.docker.com/r/jenkins/jenkins)). The deployment includes an Elastic File System (EFS) volume for persisting plugins and configurations, along with an Elastic Load Balancer (ELB) deployment for TLS termination. The module also includes the deployment of an EC2 Autoscaling group to serve as a flexible pool of build nodes, however the user must configure Jenkins to use the build farm.

This module deploys the following resources:

- An Elastic Container Service (ECS) cluster backed by AWS Fargate.
- An ECS service running the latest Jenkins container ([jenkins/jenkins:lts-jdk17](https://hub.docker.com/r/jenkins/jenkins)) available.
- An Elastic File System (EFS) for the Jenkins service to use as a persistent datastore.
- A user defined number of ZFS File Systems
- An Elastic Load Balancer (ELB) for TLS termination of the Jenkins service
- A configurable number of EC2 Autoscaling groups to serve as a flexible pool of build nodes for the Jenkins service
- Supporting resources including KMS keys for encryption and IAM roles to ensure security best practices
