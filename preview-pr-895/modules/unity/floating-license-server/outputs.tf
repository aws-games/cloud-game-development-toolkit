output "eni_id" {
  description = "Elastic Network ID (ENI) used when binding the Unity Floating License Server."
  value       = local.eni_id
}

output "instance_public_ip" {
  description = "The resulting EC2 instance's public IP, if configured."
  value       = aws_instance.unity_license_server.public_ip
}

output "instance_private_ip" {
  description = "The EC2 instance's private IP address."
  value       = aws_instance.unity_license_server.private_ip
}

output "alb_dns_name" {
  description = "DNS endpoint of Application Load Balancer (ALB)."
  value       = var.create_alb ? aws_lb.unity_license_server_alb[0].dns_name : null
}

output "alb_zone_id" {
  description = "Zone ID for Application Load Balancer (ALB)."
  value       = var.create_alb ? aws_lb.unity_license_server_alb[0].zone_id : null
}

output "alb_security_group_id" {
  description = "ID of the Application Load Balancer's (ALB) security group."
  value       = var.create_alb ? aws_security_group.unity_license_server_alb_sg[0].id : null
}

output "unity_license_server_port" {
  description = "Port the Unity Floating License Server will listen on."
  value       = var.unity_license_server_port
}

output "unity_license_server_s3_bucket" {
  description = "S3 bucket name used by the Unity License Server service."
  value       = aws_s3_bucket.unity_license_server_bucket.id
}

output "created_unity_license_server_security_group_id" {
  description = "Id of the security group created by the script, for the Unity License Server instance. Null if an ENI was provided externally instead of created through the script."
  value       = !local.eni_provided ? aws_security_group.unity_license_server_sg[0].id : null
}

output "dashboard_password_secret_arn" {
  description = "ARN of the secret containing the dashboard password."
  value       = local.admin_password_arn
  depends_on  = [null_resource.wait_for_user_data]
}

output "registration_request_filename" {
  description = "Filename for the server registration request file."
  value       = "server-registration-request.xml"
}

output "registration_request_presigned_url" {
  description = "Presigned URL for downloading the server registration request file (valid for 1 hour)."
  value       = trimspace(data.local_file.registration_url.content)
}

output "services_config_filename" {
  description = "Filename for the services config file."
  value       = "services-config.json"
}

output "services_config_presigned_url" {
  description = "Presigned URL for downloading the services configuration file (valid for 1 hour)."
  value       = trimspace(data.local_file.config_url.content)
}
