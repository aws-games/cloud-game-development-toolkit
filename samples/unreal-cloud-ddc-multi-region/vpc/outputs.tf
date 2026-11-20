output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "vpc_id" {
  value = aws_vpc.unreal_cloud_ddc_vpc.id
}

output "vpc_private_route_table_id" {
  value = aws_route_table.private_rt.id
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat_gateway_eip.public_ip
}
