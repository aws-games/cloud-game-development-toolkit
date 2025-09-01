# Multi-region DDC deployment outputs

# Combined DDC Connection Information
output "endpoints" {
  description = "DDC endpoints by region"
  value = {
    (local.primary_region) = {
      ddc = "http://${aws_route53_record.primary_ddc_service.name}"
      monitoring = length(aws_route53_record.primary_ddc_monitoring) > 0 ? "https://${aws_route53_record.primary_ddc_monitoring[0].name}" : null
    }
    (local.secondary_region) = {
      ddc = "http://${aws_route53_record.secondary_ddc_service.name}"
      monitoring = null
    }
  }
}



