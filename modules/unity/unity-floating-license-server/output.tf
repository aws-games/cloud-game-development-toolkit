output "unity_license_server_instance" {
  value = var.create_eip ? aws_instance.unity_license_server_eip[0].arn : aws_instance.unity_license_server_eni[0].arn
}

output "unity_license_server_security_group_id" {
  value = aws_security_group.unity_license_server_sg.id
}

output "unity_license_server_private_ip" {
  value = var.create_eip ? null : aws_instance.unity_license_server_eni[0].private_ip
}

output "unity_license_server_public_ip" {
  value = var.create_eip ? aws_instance.unity_license_server_eip[0].public_ip : null
}

output "unity_license_server_port" {
  value = var.unity_license_server_port
}
