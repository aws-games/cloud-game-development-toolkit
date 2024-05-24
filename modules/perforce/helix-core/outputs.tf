output "helix_core_eip_address" {
  value = aws_eip.helix_core_eip[0].address
}

output "helix_core_eip_id" {
  value = aws_eip.helix_core_eip[0].id
}
