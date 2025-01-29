---
title: Unreal Engine Cloud Derived Data Cache
description: Unreal Engine Cloud Derived Data Cache Infrastructure Terraform module for game development on AWS
---

# Unreal Engine Cloud DDC Infrastructure Module

[Jump to Terraform docs](./terraform-docs.md) { .md-button .md-button--primary }

[Unreal Cloud Derived Data Cache](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC) is a set of services supporting distributed team workflows to accelerate cook processes in Unreal Engine. This module deploys the infrastructure for the Unreal Engine Cloud DDC on AWS.

Unreal Cloud Derived Data Cache relies on a Cassandra compatible database which Epic has recommended ScyllaDB. This module provides these services by provisioning an [EC2 Instance](https://aws.amazon.com/ec2/) with ScyllaDB either as a single node or a clustered configuration, an EKS Cluster with 3 node groups (one for system tasks, NVME, and a Worker for regional replication) and a [S3 Bucket](https://aws.amazon.com/s3/).

All instances deployed in this module have EC2 Connect allowing a user to get command line access through the AWS Console rather than through SSH.

## Deployment Architecture
![Unreal Engine Cloud DDC Infra Module Architecture](../../../media/images/unreal-cloud-ddc-infra.png)

## Prerequisites
The Unreal Engine Cloud DDC Infrastructure Module has a dependency on a VPC with Subnets. The preferred configuration is a VPC with 2 public subnets and 2 private subnets that span 2 Availability Zones and an S3 interface.

For the variable, eks_node_group_subnets adding additional subnets will register all listed subnets as subnets where nodes can be deployed.

For the variable, scylla_subnets for every subnet listed a scylla instance will be deployed into the subnet. For configurations of 2 or more these scylla instances will be configured into a clustered set-up.
