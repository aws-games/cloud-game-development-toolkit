output "security_group_id" {
  value = aws_security_group.swarm_alb_sg.id
}

output "swarm_alb_dns_name" {
  value = aws_lb.swarm_alb.dns_name
}
