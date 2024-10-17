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

variable "github_credential_arn" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}


variable "caller_ip" {
  type        = list(string)
  default     = []
  description = "IPs that will be allow listed to access cluster over internet"
}
