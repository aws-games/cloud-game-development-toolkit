########################################
# GENERAL CONFIGURATION
########################################

variable "name" {
  description = "Unreal Cloud DDC Workload Name"
  type        = string
  default     = "unreal-cloud-ddc"
  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters. This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "terraform-aws-unreal-cloud-ddc"
    "ModuleName"     = "infrastructure"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}

variable "environment" {
  type        = string
  description = "The current environment (e.g. dev, prod, etc.)"
  default     = "dev"
}

variable "debug" {
  description = "Enable debug mode"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "String for VPC ID"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-west-2"
}

variable "create_seed_node" {
  description = "Whether this region creates the ScyllaDB seed node (bootstrap node for cluster formation)"
  type        = bool
  default     = true
}
variable "existing_security_groups" {
  description = "List of existing security groups to add to ALL Unreal DDC resources (global access)"
  type        = list(string)
  default     = []
}

variable "additional_nlb_security_groups" {
  type        = list(string)
  description = "Additional security group IDs to attach specifically to the DDC Network Load Balancer (for game developer access)"
  default     = []
}

variable "additional_eks_security_groups" {
  type        = list(string)
  description = "Additional security group IDs to attach specifically to the EKS cluster (for DevOps kubectl access)"
  default     = []
}

########################################
# ScyllaDB Configuration
########################################

variable "scylla_replication_factor" {
  type        = number
  description = "How many copies of your data are stored across the cluster. This will reflect how many scylla worker nodes are created."

}
variable "scylla_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."
}

variable "scylla_ami_name" {
  type        = string
  default     = "ScyllaDB 6.0.1"
  description = "Name of the Scylla AMI to be used to get the AMI ID"
  nullable    = false
}

variable "existing_scylla_ips" {
  type        = list(string)
  default     = []
  description = "List of existing ScyllaDB IPs to be used for the ScyllaDB instance"
}

variable "scylla_ips_by_region" {
  type        = map(list(string))
  default     = {}
  description = "Map of ScyllaDB IPs organized by region for monitoring dashboard separation"
}

variable "scylla_instance_type" {
  type        = string
  default     = "i4i.2xlarge"
  description = "The type and size of the Scylla instance."
  nullable    = false
  validation {
    condition     = contains(["i8g", "i7ie", "i4g", "i4i", "im4gn", "is4gen", "i4i", "i3", "i3en"], split(".", var.scylla_instance_type)[0])
    error_message = "Must be an instance family that contains NVME"
  }
  validation {
    condition     = (contains(["arm64"], var.scylla_architecture) && contains(["i8g", "i4g", "im4gn", "is4gen"], split(".", var.scylla_instance_type)[0])) || (contains(["x86_64"], var.scylla_architecture) && contains(["i7ie", "i4i", "i4i", "i3", "i3en"], split(".", var.scylla_instance_type)[0]))
    error_message = "Chip architecture must match instance type"
  }
}

variable "scylla_architecture" {
  type        = string
  default     = "x86_64"
  description = "The chip architecture to use when finding the scylla image. Valid"
  nullable    = false
  validation {
    condition     = contains(["x86_64", "arm64"], var.scylla_architecture)
    error_message = "Must be a supported chip architecture"
  }
}

variable "scylla_db_storage" {
  type        = number
  default     = 100
  description = "Size of gp3 ebs volumes attached to Scylla DBs"
  nullable    = false
}

variable "scylla_db_throughput" {
  type        = number
  default     = 200
  description = "Throughput of gp3 ebs volumes attached to Scylla DBs"
  nullable    = false
}



variable "existing_scylla_seed" {
  type        = string
  description = "The IP address of the seed instance of the ScyllaDB cluster"
  default     = null
}

variable "scylla_source_region" {
  type        = string
  description = "Name of the primary region for multi-region deployments"
  default     = null
}

########################################
# EKS Configurations
########################################

variable "eks_node_group_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended."
}

variable "nvme_managed_node_instance_type" {
  type        = string
  default     = "i3en.large"
  description = "Nvme managed node group instance type"
  nullable    = false
}
variable "nvme_managed_node_desired_size" {
  type        = number
  default     = 2
  description = "Desired number of nvme managed node group instances"
  nullable    = false
  validation {
    condition     = (var.nvme_managed_node_min_size <= var.nvme_managed_node_desired_size) && (var.nvme_managed_node_desired_size <= var.nvme_managed_node_max_size)
    error_message = "NVME desired size needs to be larger than min size but smaller than max size"
  }
}

variable "nvme_managed_node_max_size" {
  type        = number
  default     = 2
  description = "Max number of nvme managed node group instances"
  nullable    = false
  validation {
    condition     = (var.nvme_managed_node_max_size >= var.nvme_managed_node_min_size)
    error_message = "NVME max size needs to be larger than min size"
  }
}

variable "nvme_managed_node_min_size" {
  type        = number
  default     = 1
  description = "Min number of nvme managed node group instances"
  nullable    = false
  validation {
    condition     = (var.nvme_managed_node_min_size >= 0)
    error_message = "NVME min size needs to be smaller than max size"
  }
}

variable "worker_managed_node_instance_type" {
  type        = string
  default     = "c5.large"
  description = "Worker managed node group instance type."
  nullable    = false
}

variable "worker_managed_node_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of worker managed node group instances."
  nullable    = false
  validation {
    condition     = (var.worker_managed_node_min_size <= var.worker_managed_node_desired_size) && (var.worker_managed_node_desired_size <= var.worker_managed_node_max_size)
    error_message = "Worker desired size needs to be smaller than max size and larger than min size"
  }
}
variable "worker_managed_node_max_size" {
  type        = number
  default     = 1
  description = "Max number of worker managed node group instances."
  nullable    = false
  validation {
    condition     = (var.worker_managed_node_max_size >= var.worker_managed_node_min_size)
    error_message = "Worker max size needs to be larger than min size"
  }
}
variable "worker_managed_node_min_size" {
  type        = number
  default     = 0
  description = "Min number of worker managed node group instances."
  nullable    = false
  validation {
    condition     = (var.worker_managed_node_min_size >= 0)
    error_message = "Worker min size needs to be smaller than max size"
  }
}

variable "system_managed_node_instance_type" {
  type        = string
  default     = "m5.large"
  description = "Monitoring managed node group instance type."
  nullable    = false
}

variable "system_managed_node_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of system managed node group instances."
  nullable    = false
  validation {
    condition     = (var.system_managed_node_min_size <= var.system_managed_node_desired_size) && (var.system_managed_node_desired_size <= var.system_managed_node_max_size)
    error_message = "System desired size needs to be smaller than max size and larger than min size"
  }
}

variable "system_managed_node_max_size" {
  type        = number
  default     = 2
  description = "Max number of system managed node group instances."
  nullable    = false
  validation {
    condition     = (var.system_managed_node_max_size >= var.nvme_managed_node_min_size)
    error_message = "System max size needs to be larger than min size"
  }
}

variable "system_managed_node_min_size" {
  type        = number
  default     = 1
  description = "Min number of system managed node group instances."
  nullable    = false
  validation {
    condition     = (var.system_managed_node_min_size >= 0)
    error_message = "System min size needs to be smaller than max size"
  }
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "Kubernetes version to be used by the EKS cluster."
  nullable    = false
  validation {
    condition     = contains(["1.31", "1.32", "1.33"], var.kubernetes_version)
    error_message = "Version number must be supported version in AWS Kubernetes"
  }
}

variable "eks_cluster_cloudwatch_log_group_prefix" {
  type        = string
  default     = "/aws/eks/unreal-cloud-ddc/cluster"
  description = "Prefix to be used for the EKS cluster CloudWatch log group."
}

variable "eks_cluster_logging_types" {
  type = list(string)
  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  description = "List of EKS cluster log types to be enabled."
}

variable "eks_cluster_public_endpoint_access_cidr" {
  type        = list(string)
  description = "List of the CIDR Ranges you want to grant public access to the EKS Cluster's public endpoint."
  default     = []
}

variable "eks_cluster_public_access" {
  type        = bool
  default     = false
  description = "Allows public access of EKS Control Plane should be used with "
}

variable "eks_cluster_private_access" {
  type        = bool
  default     = true
  description = "Allows private access of the EKS Control Plane from subnets attached to EKS Cluster "
}

variable "worker_node_group_label" {
  type = map(string)
  default = {
    "unreal-cloud-ddc/node-type" = "worker"
  }
  description = "Label applied to worker node group. These will need to be matched in values for taints and tolerations for the worker pod definition."
}

variable "nvme_node_group_label" {
  type = map(string)
  default = {
    "unreal-cloud-ddc/node-type" = "nvme"
  }
  description = "Label applied to nvme node group. These will need to be matched in values for taints and tolerations for the worker pod definition."
}

variable "system_node_group_label" {
  type = map(string)
  default = {
    "pool" = "system-pool"
  }
  description = "Label applied to system node group"
}



########################################
# Kubernetes Configuration
########################################

variable "unreal_cloud_ddc_namespace" {
  type        = string
  description = "Namespace for Unreal Cloud DDC"
  default     = "unreal-cloud-ddc"
}

variable "unreal_cloud_ddc_service_account_name" {
  type        = string
  description = "Name of Unreal Cloud DDC service account."
  default     = "unreal-cloud-ddc-sa"
}

variable "certificate_manager_hosted_zone_arn" {
  type        = list(string)
  description = "ARN of the Certificate Manager for Ingress."
  default     = []
}

variable "enable_certificate_manager" {
  type        = bool
  description = "Enable Certificate Manager for Ingress. Required for TLS termination."
  default     = false
  validation {
    condition     = var.enable_certificate_manager ? length(var.certificate_manager_hosted_zone_arn) > 0 : true
    error_message = "Certificate Manager hosted zone ARN is required."
  }
}

variable "oidc_credentials_secret_manager_arn" {
  type        = string
  description = "ARN for OIDC credentials stored in secret manager (for external service authentication)"
  default     = null
}
