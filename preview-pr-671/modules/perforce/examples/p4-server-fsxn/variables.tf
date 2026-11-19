variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
}

variable "fsxn_password" {
  description = "Admin password to be used with FSxN"
  type        = string
}

variable "fsxn_aws_profile" {
  description = "AWS profile for managing FSxN"
  type        = string
}
