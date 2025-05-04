variable "root_domain_name" {
  type        = string
  description = "The root domain name you would like to use for DNS."
}


variable "enable_private_access_perforce" {
  type = object({
    enabled = bool
    cidr    = string
  })
  default     = null
  description = "Enable private access to Perforce and specify allowlisted CIDR range."
  validation {
    condition     = var.enable_private_access_perforce.enabled == true && var.enable_private_access_perforce.cidr != null
    error_message = "If private access to Perforce is enabled, a CIDR range must be provided."
  }
}
