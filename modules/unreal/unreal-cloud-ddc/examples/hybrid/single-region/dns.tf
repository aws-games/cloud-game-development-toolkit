##########################################
# DNS Architecture Note
##########################################
# DNS records for DDC services are NOT managed in Terraform to prevent
# race conditions and dependency issues during destroy operations.
#
# Instead, DNS records are created automatically by:
# 1. AWS Load Balancer Controller (creates NLB based on Kubernetes Service annotations)
# 2. External-DNS EKS addon (creates Route53 records pointing to the NLB)
#
# This approach provides:
# - Deterministic regional endpoints for DDC (e.g. us-east-1.dev.ddc.example.com)
# - Automatic DNS management without Terraform state conflicts
# - Proper cleanup during EKS cluster destruction
# - No timing inconsistencies between Terraform destroy and EKS pod draining
#
# The annotations are set in the Helm chart values (ddc-app submodule) which
# configure both the Load Balancer Controller and External-DNS behavior.
# Terraform actions (optionally, module default) uses CodeBuild to apply these changes against the cluster.

##########################################
# Fetch Existing Route53 Public Hosted Zone
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

##########################################
# SSL Certificate for HTTPS
##########################################
resource "aws_acm_certificate" "ddc" {
  domain_name = local.ddc_fully_qualified_domain_name
  validation_method = "DNS"

  tags = merge(local.tags, {
    Name = "${module.unreal_cloud_ddc.name_prefix}-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "ddc_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ddc.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.root.id
}

resource "aws_acm_certificate_validation" "ddc" {
  certificate_arn         = aws_acm_certificate.ddc.arn
  validation_record_fqdns = [for record in aws_route53_record.ddc_cert_validation : record.fqdn]

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "15m"
  }
}
