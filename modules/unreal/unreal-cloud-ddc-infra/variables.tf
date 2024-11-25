variable "name" {
  description = "Unreal Cloud DDC Workload Name"
  type        = string
  default     = "unreal-cloud-ddc"
}

variable "vpc_id" {
  description = "String for VPC ID"
  type        = string
}


variable "private_subnets" {
  type        = list(string)
  default     = []
  description = "Private subnets you want scylla and the worker nodes to be installed into."
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
}

variable "scylla_architecture" {
  type        = string
  default     = "x86_64"
  description = "The chip architecture to use when finding the scylla image. Valid"
  nullable    = false
}

variable "scylla_private_subnets" {
  type        = list(string)
  default     = []
  description = "The subnets you want Scylla to be installed into. Can repeat subnet ids to install into the same subnet/az. This will also determine how many Scylla instances are deployed."
  nullable    = false
}

# variable "peer_cidr_blocks" {
#   type        = list(string)
#   default     = []
#   description = "The peered cidr blocks you want your vpc to communicate with if you have a multi region ddc."
#   nullable    = false
# }


variable "scylla_dns" {
  type        = string
  default     = null
  description = "The local private dns name that you want Scylla to be queryable on."
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
  default     = "i3en.xlarge"
  description = "Nvme managed node group instance type"
  nullable    = false
}
variable "nvme_managed_node_desired_size" {
  type        = number
  default     = 2
  description = "Desired number of nvme managed node group instances"
  nullable    = false
}

variable "nvme_managed_node_max_size" {
  type        = number
  default     = 2
  description = "Max number of nvme managed node group instances"
  nullable    = false
}

variable "worker_managed_node_instance_type" {
  type        = string
  default     = "c5.xlarge"
  description = "Worker managed node group instance type."
  nullable    = false
}

variable "worker_managed_node_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of worker managed node group instances."
  nullable    = false
}
variable "worker_managed_node_max_size" {
  type        = number
  default     = 1
  description = "Max number of worker managed node group instances."
  nullable    = false
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
  description = "Desired number of monitoring managed node group instances."
  nullable    = false
}

variable "system_managed_node_max_size" {
  type        = number
  default     = 2
  description = "Max number of monitoring managed node group instances."
  nullable    = false
}

variable "eks_cluster_access_cidr" {
  type        = list(string)
  description = "List of the CIDR Ranges you want to grant public access to the EKS Cluster."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30"
  description = "Kubernetes version to be used by the EKS cluster."
  nullable    = false
}
