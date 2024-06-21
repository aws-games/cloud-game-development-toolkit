output "service_security_group" {
  description = "Security group associated with the ECS service hosting jenkins"
  value       = aws_security_group.jenkins_service_sg.id
}

output "alb_security_group" {
  description = "Security group associated with the Jenkins load balancer"
  value       = aws_security_group.jenkins_alb_sg.id
}

output "build_farm_security_group" {
  description = "Security group associated with the build farm autoscaling groups"
  value       = aws_security_group.jenkins_build_farm_sg.id
}

output "jenkins_alb_dns_name" {
  description = "The DNS name of the Jenkins application load balancer."
  value       = aws_lb.jenkins_alb.dns_name
}

output "jenkins_alb_zone_id" {
  description = "The zone ID of the Jenkins ALB."
  value       = aws_lb.jenkins_alb.zone_id
}
