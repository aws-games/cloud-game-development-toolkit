variable "github_credential_arn_region_1" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
}

variable "github_credential_arn_region_2" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
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

variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created."
}
