# Client VPN outputs

output "client_vpn_endpoint_id" {
  description = "Client VPN endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.ddc.id
}

output "client_vpn_dns_name" {
  description = "Client VPN DNS name for connection"
  value       = aws_ec2_client_vpn_endpoint.ddc.dns_name
}

output "client_vpn_configuration_instructions" {
  description = "Instructions for configuring VPN client"
  value = <<-EOT
    1. Download client configuration:
       aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id ${aws_ec2_client_vpn_endpoint.ddc.id} --output text > ddc-client-vpn.ovpn
    
    2. Generate client certificate and key (if using certificate auth)
    
    3. Add client cert/key to .ovpn file:
       <cert>
       [client certificate content]
       </cert>
       <key>
       [client private key content]
       </key>
    
    4. Connect using OpenVPN client
  EOT
}