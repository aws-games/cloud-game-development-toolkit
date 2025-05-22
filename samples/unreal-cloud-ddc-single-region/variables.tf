variable "github_credential_arn" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}

variable "cidr_allow_list" {
  type        = list(string)
  default     = []
  description = "IPs that will be allow listed to access cluster over internet"
}

variable "allow_my_ip" {
  type        = bool
  default     = true
  description = "Automatically add your IP to the allowlist"
}
