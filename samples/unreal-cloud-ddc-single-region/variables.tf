variable "github_credential_arn" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}

variable "allow_my_ip" {
  type        = bool
  default     = true
  description = "Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers"
}
