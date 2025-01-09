variable "name" {
  description = "Unreal Cloud DDC Workload Name"
  type        = string
  default     = "unreal-cloud-ddc"
  validation {
    condition     = length(var.name) > 1 && length(var.name) <= 50
    error_message = "The defined 'name' has too many characters. This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}

variable "vpc_id" {
  description = "String for VPC ID"
  type        = string
}

variable "scylla_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."
}

variable "eks_node_group_subnets" {
  type        = list(string)
  default     = []
  description = "A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended."
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

variable "eks_cluster_public_endpoint_access_cidr" {
  type        = list(string)
  description = "List of the CIDR Ranges you want to grant public access to the EKS Cluster's public endpoint."
  default     = null
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

variable "eks_cluster_public_access" {
  type        = bool
  default     = false
  description = "Allows public access of EKS Control Plane should be used with "
  validation {
    condition     = (var.eks_cluster_public_access == true) && (length(var.eks_cluster_public_endpoint_access_cidr) > 0) && !contains(["0.0.0.0"], var.eks_cluster_public_access)
    error_message = "If public access is allowed need to set up eks_cluster_access_cidr with at least a single value."
  }
}

variable "eks_cluster_private_access" {
  type        = bool
  default     = true
  description = "Allows private access of the EKS Control Plane from subnets attached to EKS Cluster "
}
