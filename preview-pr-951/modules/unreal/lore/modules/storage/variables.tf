variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name_prefix) >= 3 && length(var.name_prefix) <= 24
    error_message = "name_prefix must be 3-24 characters (S3 bucket prefix + random suffix must fit 63-char limit)."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "enable_force_destroy" {
  description = "Allow S3 bucket deletion when non-empty"
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on DynamoDB tables"
  type        = bool
  default     = true
  nullable    = false
}

variable "intelligent_tiering_archive_days" {
  description = "Days before fragments move to Archive Access tier. 0 disables Intelligent-Tiering."
  type        = number
  default     = 90
}

variable "intelligent_tiering_deep_archive_days" {
  description = "Days before fragments move to Deep Archive Access tier."
  type        = number
  default     = 180
}
