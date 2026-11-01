variable "container_image" {
  description = "Loreserver container image URI (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v1.0.0)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.", var.container_image))
    error_message = "Must be an ECR image URI. Format: <account_id>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>"
  }
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach Lore (e.g., your studio office CIDR)"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on DynamoDB tables"
  type        = bool
  default     = true
}

variable "enable_force_destroy" {
  description = "Allow S3 bucket deletion even when non-empty"
  type        = bool
  default     = false
}
