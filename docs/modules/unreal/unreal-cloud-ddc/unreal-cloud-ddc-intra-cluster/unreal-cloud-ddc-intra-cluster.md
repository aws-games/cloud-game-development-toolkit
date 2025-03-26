---
title: Unreal Engine Cloud Derived Data Cache Intra Cluster
description: Unreal Engine Cloud Derived Data Cache Intra Cluster Terraform module for game development on AWS
---

# Unreal Engine Cloud DDC Intra Cluster Module

[Jump to Terraform docs](./terraform-docs.md) { .md-button .md-button--primary }

[Unreal Cloud Derived Data Cache](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC) is a set of services supporting distributed team workflows to accelerate cook processes in Unreal Engine. This module deploys the [image available from the Epic Games Github organization.](https://github.com/orgs/EpicGames/packages/container/package/unreal-cloud-ddc), configures service accounts and IAM roles required to run Unreal Cloud DDC.

This module currently utilizes the [Terraform EKS Blueprints Addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons) repository to install CoreDNS, Kube-Proxy, VPC-CNI, EBS CSI Driver, AWS Load Balancer and CloudWatch Metrics Addons to the cluster with the required IAM roles and service accounts.

## Deployment Architecture
![Unreal Engine Cloud DDC Infrastructure Module Architecture](../../../media/images/unreal-cloud-ddc-single-region.png)

## Prerequisites
This module is to be used in conjunction with the Unreal Cloud DDC Infra Module which sets up all the required infrastructure for the images.

This module requires two secrets to be set up prior:

If you are using client secrets for OIDC, external_idp_oidc_credential_arn is set up for the Secrets Manager resolver for a Client Secret for  Unreal Cloud DDC("aws!arn:aws:secretsmanager:<region>:<aws-account-number>:secret:<secret-name>|<json-field>"). See [Unreal Cloud DDC Helm documentation](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Helm/UnrealCloudDDC). A sample example is as follows:
```
{
    "client_secret":"CLIENT-SECRET-PLACEHOLDER",
    "client_id":"CLIENT-ID-PLACEHOLDER"
}
```

github_credential_arn is required for the ECR pull through cache to resolve the image. This is required to have the prefix of ecr-pullthrough and the fields of username and access_token. Your structure will have be exact as the following:
```
{
    "username":"GITHUB-USER-NAME-PLACEHOLDER",
    "accessToken":"GITHUB-ACCESS-TOKEN-PLACEHOLDER"
}
```
The name of this secret is also required to be prefaced with "ecr-pullthroughcache/" as this is required by the pull through cache to function.

unreal_cloud_ddc_helm_values is an open ended way for you to include your helm values to configure the Unreal Cloud DDC deployment. We generally recommend you to use a template file. You can see a sample template file in the single region sample on how to configure the Unreal Cloud DDC in this manner.
