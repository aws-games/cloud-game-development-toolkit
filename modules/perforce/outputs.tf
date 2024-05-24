output "helix_core_sg" {
  value = aws_security_group.helix_core.id
}

output "helix_swarm_sg" {
  value = module.helix_swarm[0].security_group_id
}

output "helix_swarm_url" {
  value = module.helix_swarm[0].swarm_alb_dns_name
}

