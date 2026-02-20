output "application_security_group_id" {
  value       = aws_security_group.application.id
  description = "Security group associated with the P4 Code Review application"
}

output "alb_security_group_id" {
  value       = var.create_application_load_balancer ? aws_security_group.alb[0].id : null
  description = "Security group associated with the P4 Code Review load balancer"
}

output "alb_dns_name" {
  value       = var.create_application_load_balancer ? aws_lb.alb[0].dns_name : null
  description = "The DNS name of the P4 Code Review ALB"
}

output "alb_zone_id" {
  value       = var.create_application_load_balancer ? aws_lb.alb[0].zone_id : null
  description = "The hosted zone ID of the P4 Code Review ALB"
}

output "target_group_arn" {
  value       = aws_lb_target_group.alb_target_group.arn
  description = "The target group ARN for P4 Code Review"
}

output "instance_profile_arn" {
  value       = aws_iam_instance_profile.ec2_instance_profile.arn
  description = "The ARN of the IAM instance profile for P4 Code Review EC2 instances"
}

output "launch_template_id" {
  value       = aws_launch_template.swarm_instance.id
  description = "The ID of the launch template for P4 Code Review instances"
}

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.swarm_asg.name
  description = "The name of the Auto Scaling Group for P4 Code Review"
}

output "ebs_volume_id" {
  value       = aws_ebs_volume.swarm_data.id
  description = "The ID of the EBS volume storing P4 Code Review persistent data"
}
