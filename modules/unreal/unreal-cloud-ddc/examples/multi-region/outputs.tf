# Primary region DDC URL
output "primary_ddc_url" {
  value = aws_route53_record.ddc_primary.name
}

# Secondary region DDC URL
output "secondary_ddc_url" {
  value = aws_route53_record.ddc_secondary.name
}

# Monitoring URL (primary region only)
output "monitoring_url" {
  value = aws_route53_record.monitoring.name
}