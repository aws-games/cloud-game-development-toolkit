variable "write_region" {
  description = "Region that holds the write tier, the branch pointers and the locks (the office with the most push-heavy work)"
  type        = string
  default     = "us-east-2"
}

variable "replica_region" {
  description = "Region of the second office. Gets a regional tier with its own fragment store."
  type        = string
  default     = "us-west-2"
}

variable "container_image" {
  description = "loreserver image URI in the write region's ECR"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.", var.container_image))
    error_message = "Must be an ECR image URI: <account_id>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>"
  }
}

variable "replica_container_image" {
  description = "The same loreserver image in the replica region's ECR (replicate the repository; do not pull across regions)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.", var.replica_container_image))
    error_message = "Must be an ECR image URI: <account_id>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>"
  }
}

variable "write_office_cidrs" {
  description = "CIDR blocks of clients in the write region's office"
  type        = list(string)
}

variable "replica_office_cidrs" {
  description = "CIDR blocks of clients in the replica region's office"
  type        = list(string)
}

variable "replication_time_control" {
  description = "Enable S3 Replication Time Control (15-minute SLA, extra per-GB fee) on fragment replication"
  type        = bool
  default     = false
}
