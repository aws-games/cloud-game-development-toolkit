output "endpoints" {
  description = "DDC endpoints by region"
  value = {
    (local.region) = {
      ddc = "http://${aws_route53_record.ddc_service.name}"
      monitoring = "https://${aws_route53_record.ddc_monitoring.name}"
    }
  }
}
