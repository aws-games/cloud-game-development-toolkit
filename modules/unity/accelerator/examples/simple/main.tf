module "unity_accelerator" {
  source              = "../../"
  vpc_id              = aws_vpc.unity_accelerator_vpc.id
  service_subnets     = aws_subnet.private_subnets[*].id
  lb_subnets          = aws_subnet.public_subnets[*].id
  alb_certificate_arn = aws_acm_certificate.unity_accelerator.arn
}
