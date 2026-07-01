output "unreal_ddc_url" {
  value = aws_route53_record.unreal_cloud_ddc.name
}

output "monitoring_url" {
  value = aws_route53_record.scylla_monitoring.name
}

output "unreal_cloud_ddc_bearer_token_arn" {
  value = awscc_secretsmanager_secret.unreal_cloud_ddc_token.id
}
