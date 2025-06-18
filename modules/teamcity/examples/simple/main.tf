module "teamcity" {
  #checkov:skip=CKV_AWS_336: EFS is not necessary for TeamCity Agents
  #checkov:skip=CKV_AWS_338: does not need CW logs for a year
  #checkov:skip=CKV_AWS_158: CW Log Group does not need to be encrypted
  #checkov:skip=CKV_AWS_111: resources need IAM write permissions
  #checkov:skip=CKV_AWS_356: Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions

  source              = "../../"
  vpc_id              = aws_vpc.teamcity_vpc.id
  service_subnets     = aws_subnet.private_subnets[*].id
  alb_subnets         = aws_subnet.public_subnets[*].id
  alb_certificate_arn = aws_acm_certificate.teamcity.arn
  # fully_qualified_domain_name = "https://teamcity.ayatanb.people.aws.dev"
}
