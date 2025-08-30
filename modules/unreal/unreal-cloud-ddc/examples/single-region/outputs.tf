output "unreal_ddc_url" {
  value = aws_route53_record.unreal_cloud_ddc.name
}

output "monitoring_url" {
  value = aws_route53_record.scylla_monitoring.name
}

output "ddc_connection" {
  description = "DDC connection information for Unreal Engine configuration"
  value = module.unreal_cloud_ddc.ddc_connection
}
