variable "vpc_id" {
  description = "VPC ID for Lambda-link function"
  default     = "vpc-3a01e05f"
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda-link function"
  type        = string
  default     = "subnet-0c95d895b82dea042"
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda-link function"
  type        = list(string)
  default     = ["sg-d20af3b7"]
}


variable "storage_type" {
  description = "Storage type"
  default     = "FSxN"
}

variable "fsxn_aws_profile" {
  description = "AWS profile with permissions"
  type        = string
  default     = ""
}

variable "fsxn_password" {
  description = "AWS secret manager admin password for FSxN"
  type        = string
  default     = ""
}

variable "fsxn_mgmt_ip" {
  description = "Management IP for FSxN"
  type        = string
  default     = ""
}

variable "fsxn_region" {
  description = "Region for FSxN"
  type        = string
  default     = ""
}

variable "protocol" {
  description = "protocol for creation FSxN volumes"
  type        = string
  default     = ""
}

variable "amazon_fsxn_svm_name" {
  description = "FSxN storage virtual machine name"
  type        = string
  default     = ""
}

variable "logs_volume_size" {
  type        = number
  description = "The size of the logs volume in GiB. Defaults to 32 GiB."
  default     = 32
}

variable "metadata_volume_size" {
  type        = number
  description = "The size of the metadata volume in GiB. Defaults to 32 GiB."
  default     = 32
}

variable "depot_volume_size" {
  type        = number
  description = "The size of the depot volume in GiB. Defaults to 128 GiB."
  default     = 128
}