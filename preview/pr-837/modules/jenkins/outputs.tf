output "service_security_group_id" {
  description = "Security group associated with the ECS service hosting jenkins"
  value       = aws_security_group.jenkins_service_sg.id
}

output "alb_security_group_id" {
  description = "Security group associated with the Jenkins load balancer"
  value       = var.create_application_load_balancer ? aws_security_group.jenkins_alb_sg[0].id : null
}

output "build_farm_security_group_id" {
  description = "Security group associated with the build farm autoscaling groups"
  value       = aws_security_group.jenkins_build_farm_sg.id
}

output "jenkins_alb_dns_name" {
  description = "The DNS name of the Jenkins application load balancer."
  value       = var.create_application_load_balancer ? aws_lb.jenkins_alb[0].dns_name : null
}

output "jenkins_alb_zone_id" {
  description = "The zone ID of the Jenkins ALB."
  value       = var.create_application_load_balancer ? aws_lb.jenkins_alb[0].zone_id : null
}

output "service_target_group_arn" {
  value       = aws_lb_target_group.jenkins_alb_target_group.arn
  description = "The ARN of the Jenkins service target group"
}
