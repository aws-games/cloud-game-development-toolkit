---
title: Unreal Engine Cloud Derived Data Cache
description: Unreal Engine Cloud Derived Data Cache Infrastructure Terraform module for game development on AWS
---

# Unreal Engine Cloud DDC Infrastructure Module
[Jump to Terraform docs](./terraform-docs.md){.md-button .md-button--primary}

<br/>

[Unreal Cloud Derived Data Cache](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine) ([source code](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC)) is a caching system that stores additional data required to use assets, such as compiled shaders. This allows the engine to quickly retrieve this data instead of having to regenerate it, saving time and disk space for the development team. For distributed teams, a cloud-hosted DDC enables efficient collaboration by ensuring all team members have access to the same cached data regardless of their location. This module deploys the core infrastructure for Unreal Engine's Cloud Derived Data Cache (DDC) on AWS. It creates a scalable, secure, and high-performance environment that optimizes asset processing and distribution throughout your game development pipeline, reducing build times and improving team collaboration.

The Unreal Cloud Derived Data Cache (DDC) infrastructure module implements Epic's recommended architecture using ScyllaDB, a high-performance Cassandra-compatible database. This module provisions the following AWS resources:

1. ScyllaDB Database Layer:
    - Deployed on EC2 instances
    - Supports both single-node and multi-node cluster configurations
    - Optimized for high-throughput DDC operations
    - Configured with AWS Systems Manager Session Manager to provide secure shell access without requiring SSH or bastion hosts

2. Amazon EKS Cluster with specialized node groups:
    - System node group: Handles core Kubernetes components and system workloads
    - NVME node group: Optimized for high-performance storage operations
    - Worker node group: Manages regional data replication and distribution
    - Configured with AWS Systems Manager Session Manager to provide secure shell access without requiring SSH or bastion hosts

3. S3 Bucket:
    - Provides durable storage for cached assets
    - Enables cross-region asset availability
    - Serves as a persistent backup layer


## Deployment Architecture

<br/>

![Unreal Engine Cloud DDC Infra Module Architecture](../../../../media/images/unreal-cloud-ddc-infra.png)

<br/>

## Prerequisites

#### Network Infrastructure Requirements

At a minimum, the Cloud DDC Module requires a Virtual Private Cloud (VPC) with a specific subnet configuration. The suggested configuration includes:

- 2 public subnets
- 2 private subnets
- Coverage across 2 Availability Zones
- An S3 interface endpoint

This architecture ensures high availability and secure communication patterns for your DDC infrastructure.

<br/>

#### Configuring Node Groups and ScyllaDB Deployment

The footprint of your Cloud DDC deployment can be configured through 2 variables:

<br/>

EKS Node Group Configuration: `eks_node_group_subnets`

The `eks_node_group_subnets` variable defines the subnet distribution for your EKS node groups. Each specified subnet serves as a potential target for node placement, providing granular control over the geographical distribution of your EKS infrastructure. Adding more subnets to this configuration increases deployment flexibility and enables broader availability zone coverage for your workloads at the cost of increased network complexity and potential inter-AZ data transfer charges.


<br/>

ScyllaDB Instance Distribution: `scylla_subnets`

The `scylla_subnets` variable determines the deployment topology of your ScyllaDB instances. Each specified subnet receives a dedicated ScyllaDB instance, with multiple subnet configurations automatically establishing a distributed cluster architecture. Configurations of two or more subnets enable high availability and data resilience through native ScyllaDB clustering at the cost of increased infrastructure complexity and proportionally higher operational expenses.
