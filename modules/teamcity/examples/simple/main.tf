module "teamcity" {
    source = "../../"
    vpc_id = aws_vpc.teamcity_vpc.id
    service_subnets = aws_subnet.private_subnets[*].id

}