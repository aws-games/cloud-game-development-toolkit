output "instance_id" {
  description = "EC2 instance ID of the edge pod"
  value       = aws_instance.edge.id
}

output "private_ip" {
  description = "Private IP address of the edge pod"
  value       = aws_instance.edge.private_ip
}

output "security_group_id" {
  description = "Security group ID of the edge pod"
  value       = aws_security_group.edge.id
}
