# Create Resources Complete (with Route53)
This example demonstrates how to deploy **[P4 Server (formerly Helix Core)](https://www.perforce.com/products/helix-core)**, **[P4 Code Review (formerly P4 Code Review)](https://www.perforce.com/products/helix-swarm)**, and **[P4Auth (formerly P4Auth)](https://help.perforce.com/helix-core/integrations-plugins/helix-auth-svc/current/Content/HAS/overview-of-has.html)** using Amazon Route53 as the DNS provider.


## Architecture

![perforce-complete-arch](../../assets/media/diagrams/perforce-arch-cdg-toolkit-terraform-aws-perforce-full-arch-route53-dns.png)

## Important
This example creates DNS records in an existing Rout53 Public Hosted Zone and as well as an ACM Certificate. This certificate needs to be validated, which is not a fixed amount of time. During a standard deployment this is a non-issue since multiple dependent resources take longer to deploy than the certificate takes to validate. However, if you change the name of your domain where referenced in the ACM certificate ***after*** the initial apply, you may encounter the following error:
```hcl
│ Error: modifying ELBv2 Listener (arn:aws:elasticloadbalancing:us-east-1:xx:listener/app/cgd-perforce-shared-alb/xx): operation error Elastic Load Balancing v2: ModifyListener, https response error StatusCode: 400, RequestID: xx-xx-xx-xx-xx, api error UnsupportedCertificate: The certificate 'arn:aws:acm:us-east-1:x:certificate/xx-xx-xx-xx-xx' must have a fully-qualified domain name, a supported signature, and a supported key size.
│
│   with module.terraform-aws-perforce.aws_lb_listener.perforce_web_services[0],
│   on ../../lb.tf line 161, in resource "aws_lb_listener" "perforce_web_services":
│  161: resource "aws_lb_listener" "perforce_web_services" {
```
If this occurs, it is because Terraform is attempting to attach the certificate to the ALB listener before it has finished validation. Wait a few minutes and retry `terraform apply`.
<!-- BEGIN_TF_DOCS -->
