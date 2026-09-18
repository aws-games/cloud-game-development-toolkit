variable "route53_public_hosted_zone_name" {
  description = "The name of your existing Route53 Public Hosted Zone. This is required to create the ACM certificate and Route53 records."
  type        = string
}
