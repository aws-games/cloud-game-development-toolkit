output "external_alb_dns_name" {
  value       = var.create_external_alb ? aws_lb.unity_accelerator_external_alb[0].dns_name : null
  description = "DNS endpoint of Application Load Balancer (ALB)"
}

output "external_alb_zone_id" {
  value       = var.create_external_alb ? aws_lb.unity_accelerator_external_alb[0].zone_id : null
  description = "Zone ID for internet-facing Application Load Balancer (ALB)"
}

output "external_nlb_dns_name" {
  value       = var.create_external_nlb ? aws_lb.unity_accelerator_external_nlb[0].dns_name : null
  description = "DNS endpoint of Network Load Balancer (NLB)"
}

output "external_nlb_zone_id" {
  value       = var.create_external_nlb ? aws_lb.unity_accelerator_external_nlb[0].zone_id : null
  description = "Zone ID for internet-facing Network Load Balancer (NLB)"
}
