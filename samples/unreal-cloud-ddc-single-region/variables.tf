variable "okta_domain" {
  type        = string
  sensitive   = true
  description = "Okta Domain"
}

variable "okta_auth_server_id" {
  type        = string
  sensitive   = true
  description = "Okta Auth Server ID"
}

variable "jwt_audience" {
  type        = string
  sensitive   = true
  description = "JWT Audience"
}

variable "jwt_authority" {
  type        = string
  sensitive   = true
  description = "JWT Authority"
}

variable "ghcr_username" {
  type        = string
  sensitive   = true
  description = "GHCR username"
}

variable "ghcr_password" {
  type        = string
  sensitive   = true
  description = "GHCR password"
}

variable "profile" {
  type        = string
  default     = "default"
  description = "AWS Profile name"
}

variable "caller_ip" {
  type        = list(string)
  default     = []
  description = "IPs that will be allow listed to access cluster over internet"
}
