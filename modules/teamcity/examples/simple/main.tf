module "teamcity" {
  source                     = "../../"
  vpc_id                     = aws_vpc.teamcity_vpc.id
  service_subnets            = aws_subnet.private_subnets[*].id
  alb_subnets                = aws_subnet.public_subnets[*].id
  alb_certificate_arn        = aws_acm_certificate.teamcity.arn
  database_connection_string = var.database_connection_string
  database_master_username   = var.database_master_username
  database_master_password   = var.database_master_password
}
