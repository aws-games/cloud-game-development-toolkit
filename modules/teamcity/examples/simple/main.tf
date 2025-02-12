module "teamcity" {
  source              = "../../"
  vpc_id              = aws_vpc.teamcity_vpc.id
  service_subnets     = aws_subnet.private_subnets[*].id
  alb_subnets         = aws_subnet.public_subnets[*].id
  alb_certificate_arn = aws_acm_certificate.teamcity.arn
}
