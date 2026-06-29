output "horde_url" {
  description = "The URL of the Horde server."
  value       = "https://horde.${var.root_domain_name}"
}

output "external_alb_dns" {
  description = "The DNS name of the external ALB."
  value       = module.horde.external_alb_dns_name
}

output "mrap_arn" {
  description = "The ARN of the S3 Multi-Region Access Point."
  value       = var.enable_mrap ? aws_s3control_multi_region_access_point.horde[0].arn : null
}
