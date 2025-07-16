output "unreal_ddc_url" {
  value = aws_route53_record.unreal_cloud_ddc_region_1.name
}

output "monitoring_url_region_1" {
  value = aws_route53_record.scylla_monitoring_region_1.name
}

output "unreal_cloud_ddc_bearer_token_arn" {
  value = aws_secretsmanager_secret.unreal_cloud_ddc_token.id
}
