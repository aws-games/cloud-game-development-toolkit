output "endpoints" {
  description = "DDC endpoints"
  value = {
    ddc = "http://${local.primary_region}.ddc.${var.route53_public_hosted_zone_name}"
    
    # Direct load balancer access
    ddc_direct = "http://${module.unreal_cloud_ddc.ddc_infra.nlb_dns_name}"
  }
}