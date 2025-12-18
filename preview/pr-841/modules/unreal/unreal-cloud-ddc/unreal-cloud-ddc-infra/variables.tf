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
  type = map(any)
  default = {
    "ModuleBy"   = "CGD-Toolkit"
    "ModuleName" = "Unreal DDC"
    "IaC"        = "Terraform"
  }
  description = "Tags to apply to resources."
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

variable "existing_security_groups" {
  description = "List of existing security groups to add to the monitoring and Unreal DDC load balancers"
  type        = list(string)
  default     = []
}

########################################
# ScyllaDB Configuration
########################################

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

variable "create_scylla_monitoring_stack" {
  type        = bool
  default     = true
  description = "Whether to create the Scylla monitoring stack"
  nullable    = false
}

variable "scylla_monitoring_instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = "The type and size of the Scylla monitoring instance."
  nullable    = false
}

variable "scylla_monitoring_instance_storage" {
  type        = number
  default     = 20
  description = "Size of gp3 ebs volumes in GB attached to Scylla monitoring instance"
  nullable    = false
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
  default     = "1.31"
  description = "Kubernetes version to be used by the EKS cluster."
  nullable    = false
  validation {
    condition     = contains(["1.24", "1.25", "1.26", "1.27", "1.28", "1.29", "1.30", "1.31"], var.kubernetes_version)
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
# Load Balancing
########################################
variable "create_application_load_balancer" {
  type        = bool
  description = "Whether to create an application load balancer for the Scylla monitoring dashboard."
  default     = true
}

variable "internal_facing_application_load_balancer" {
  type        = bool
  description = "Whether the application load balancer should be internal-facing."
  default     = false
}

variable "monitoring_application_load_balancer_subnets" {
  type        = list(string)
  description = "The subnets in which the ALB will be deployed"

  validation {
    condition     = (var.create_application_load_balancer && var.monitoring_application_load_balancer_subnets != null) || (!var.create_application_load_balancer && var.monitoring_application_load_balancer_subnets == null)
    error_message = "The alb_subnets variable must be set if create_application_load_balancer is true."
  }
  default = null
}

variable "alb_certificate_arn" {
  type        = string
  description = "The ARN of the certificate to use on the ALB"
  default     = null

  validation {
    condition     = (var.create_application_load_balancer && var.alb_certificate_arn != null) || (!var.create_application_load_balancer && var.alb_certificate_arn == null)
    error_message = "The alb_certificate_arn variable must be set if create_external_alb is true."
  }
}

variable "enable_scylla_monitoring_lb_deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection for the Scylla monitoring load balancer."
  default     = false

}
variable "enable_scylla_monitoring_lb_access_logs" {
  type        = bool
  description = "Whether to enable access logs for the Scylla monitoring load balancer."
  default     = false
}

variable "scylla_monitoring_lb_access_logs_bucket" {
  type        = string
  description = "Name of the S3 bucket to store the access logs for the Scylla monitoring load balancer."
  default     = null
}

variable "scylla_monitoring_lb_access_logs_prefix" {
  type        = string
  description = "Prefix to use for the access logs for the Scylla monitoring load balancer."
  default     = null
}
