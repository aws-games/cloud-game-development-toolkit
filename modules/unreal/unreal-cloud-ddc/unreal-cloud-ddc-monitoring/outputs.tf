output "scylla_monitoring_security_group_id" {
  value       = aws_security_group.scylla_monitoring_security_group.id
  description = "Security group id for the scylla monitoring instance"
}
