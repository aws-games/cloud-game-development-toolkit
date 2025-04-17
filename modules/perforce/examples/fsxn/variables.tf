variable "root_domain_name" {
  type        = string
  description = "The root domain name you would like to use for DNS."
}

variable "fsxn_password" {
  description = "FSxN admin user password AWS secret manager arn"
  type        = string
}

variable "fsxn_aws_profile" {
  description = "AWS profile for managing FSxN"
  type        = string
}
