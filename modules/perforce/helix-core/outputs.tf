output "helix_core_eip_private_ip" {
  value = aws_eip.helix_core_eip[0].private_ip
}

output "helix_core_eip_public_ip" {
  value = aws_eip.helix_core_eip[0].public_ip
}

output "helix_core_eip_id" {
  value = aws_eip.helix_core_eip[0].id
}

output "security_group_id" {
  value = aws_security_group.helix_core_security_group[0].id
}
