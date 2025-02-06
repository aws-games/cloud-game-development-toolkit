variable "github_credential_arn" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}

variable "eks_cluster_ip_allow_list" {
  type        = list(string)
  default     = null
  description = "IPs that will be allow listed to access cluster over internet"
}
