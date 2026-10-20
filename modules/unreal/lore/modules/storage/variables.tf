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

variable "enable_replication" {
  description = "Replicate fragments to another region's bucket (S3 Cross-Region Replication). Turns on bucket versioning, which CRR requires. A separate flag from the ARN because the destination bucket is usually created in the same apply and its ARN is unknown at plan time."
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the fragments bucket in the other region. Required when enable_replication is true."
  type        = string
  default     = null
}

variable "replication_time_control" {
  description = "Enable S3 Replication Time Control (15-minute SLA, extra per-GB fee) on the replication rule."
  type        = bool
  default     = false
}

variable "immutable_table_replica_regions" {
  description = "Regions to add as DynamoDB Global Table replicas of the two immutable-store tables (fragments, fragment-metadata). Never applied to the mutable store or locks tables, whose compare-and-swap semantics do not survive multi-region replication."
  type        = list(string)
  default     = []
}

variable "create_immutable_tables" {
  description = "Create the fragments and fragment-metadata tables. Set false when they already exist in this region as Global Table replicas created by the write region."
  type        = bool
  default     = true
}

variable "create_mutable_tables" {
  description = "Create the mutable-typed-store and locks tables. Only the write region holds these; a regional tier sets false."
  type        = bool
  default     = true
}

variable "replication_destination_ready" {
  description = "Any value that becomes known only once the destination bucket has versioning enabled (e.g. the other module's fragment_bucket_versioning_id). S3 rejects a replication rule whose destination is not yet versioned, and the two buckets usually belong to different modules in the same apply."
  type        = string
  default     = null
}
