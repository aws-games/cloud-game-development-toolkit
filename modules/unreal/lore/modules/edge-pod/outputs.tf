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

output "replication_client_ca_certificate_pem" {
  description = "Dedicated CA PEM for this edge pod's mTLS client identity. Add it to the write tier's trusted_ca_pem bundle."
  value       = local.replication_client_ca_certificate_pem
}

output "iam_role_arn" {
  description = "IAM role ARN for the edge instance. Attach scoped kms:Decrypt permission here when custom identity secrets use a customer-managed KMS key."
  value       = aws_iam_role.edge.arn
}
