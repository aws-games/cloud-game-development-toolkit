variable "root_domain_name" {
  type        = string
  description = "The root domain name you would like to use for DNS."
}

variable "dockerhub_secret_arn" {
  type        = string
  description = "The ARN of the AWS Secret for Docker Hub credentials used to pull the Perforce container image. This variable is used directly by the module."
  default     = null
}
