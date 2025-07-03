module "unity_accelerator" {
  source              = "../../"
  vpc_id              = aws_vpc.unity_accelerator_vpc.id
  service_subnets     = aws_subnet.private_subnets[*].id
  lb_subnets          = aws_subnet.public_subnets[*].id
  alb_certificate_arn = aws_acm_certificate.unity_accelerator.arn
  # unity_accelerator_dashboard_username_arn = "arn:aws:secretsmanager:us-east-2:637423293148:secret:dashboard-username-ainlYO"
  # unity_accelerator_dashboard_password_arn = "arn:aws:secretsmanager:us-east-2:637423293148:secret:test-pQL2a3"
}
