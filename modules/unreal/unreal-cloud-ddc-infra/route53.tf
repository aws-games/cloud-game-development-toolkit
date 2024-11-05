################################################################################
# Scylla DNS Name Record
################################################################################
resource "aws_route53_zone" "scylla_zone" {
  #checkov:skip=CKV2_AWS_38:Ensure Domain Name System Security Extensions (DNSSEC) signing is enabled for Amazon Route 53 public hosted zones
  #checkov:skip=CKV2_AWS_39:Ensure Domain Name System (DNS) query logging is enabled for Amazon Route 53 hosted zones
  name = var.scylla_dns

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "scylla_records" {
  name    = var.scylla_dns
  ttl     = 60
  type    = "A"
  zone_id = aws_route53_zone.scylla_zone.zone_id

  records = [for scylla in aws_instance.scylla_ec2_instance : scylla.private_ip]
}
