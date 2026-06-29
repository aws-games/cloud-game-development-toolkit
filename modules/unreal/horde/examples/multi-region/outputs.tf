output "horde_url" {
  description = "The URL of the Horde server."
  value       = "https://horde.${var.root_domain_name}"
}

output "external_alb_dns" {
  description = "The DNS name of the external ALB."
  value       = module.horde.external_alb_dns_name
}
