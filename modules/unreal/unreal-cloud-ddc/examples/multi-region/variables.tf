########################################
# General Configuration
########################################
variable "project_prefix" {
  type        = string
  description = "Prefix for resource naming"
  default     = "unreal-cloud-ddc"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

########################################
# Region Configuration
########################################
variable "regions" {
  type        = list(string)
  default     = ["us-east-1", "us-east-2"]  # Updated from us-west-2, us-east-2
  description = "List of regions to deploy the solution"
  
  validation {
    condition     = length(var.regions) == 2
    error_message = "Exactly 2 regions must be specified for multi-region deployment."
  }
}

########################################
# DNS Configuration
########################################
variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created."
  default     = "example.com"  # Provide sensible default
}

########################################
# GitHub Credentials
########################################
variable "github_credential_arn_region_1" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN for primary region"
  default     = "arn:aws:secretsmanager:us-east-1:111111111111:secret:ecr-pullthroughcache/-123xx"
}

variable "github_credential_arn_region_2" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN for secondary region"
  default     = "arn:aws:secretsmanager:us-east-2:111111111111:secret:ecr-pullthroughcache/-123xx"
}

########################################
# Infrastructure Configuration
########################################
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.31"
}

variable "scylla_instance_type" {
  description = "Instance type for ScyllaDB nodes"
  type        = string
  default     = "i4i.xlarge"
}

variable "scylla_node_count" {
  description = "Number of ScyllaDB nodes per region"
  type        = number
  default     = 3
}

########################################
# Networking Configuration
########################################
variable "vpc_cidr_region_1" {
  type        = string
  description = "CIDR block for VPC in primary region"
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_region_2" {
  type        = string
  description = "CIDR block for VPC in secondary region"
  default     = "10.1.0.0/16"
}

########################################
# Tags
########################################
variable "additional_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    "Project"     = "unreal-cloud-ddc"
    "ManagedBy"   = "terraform"
    "Module"      = "unreal-cloud-ddc"
  }
}