output "unreal_cloud_ddc_load_balancer_name" {
  value = data.aws_lb.unreal_cloud_ddc_load_balancer.dns_name
}

output "unreal_cloud_ddc_load_balancer_zone_id" {
  value = data.aws_lb.unreal_cloud_ddc_load_balancer.zone_id
}
