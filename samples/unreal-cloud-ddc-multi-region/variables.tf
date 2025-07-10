variable "github_credential_arn_region_1" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}

variable "github_credential_arn_region_2" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}

variable "allow_my_ip" {
  type        = bool
  default     = true
  description = "Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers"
}

variable "regions" {
  type        = list(string)
  default     = ["us-west-2", "us-east-2"]
  description = "List of regions to deploy the solution"
}
