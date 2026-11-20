variable "github_credential_arn_region_1" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
}

variable "github_credential_arn_region_2" {
  type        = string
  sensitive   = true
  description = "ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub"
}

variable "allow_my_ip" {
  type        = bool
  default     = true
  description = "Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers"
}

variable "regions" {
  type        = list(string)
  default     = ["us-west-2", "us-east-2"]
  description = "List of regions to deploy the solution"
}

variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created."
}

variable "eks_public_access" {
  type        = bool
  default     = true
  description = <<-EOT
    Whether the public API endpoint of both EKS clusters is enabled. Defaults to
    true so a first apply from a laptop works without extra setup. Set to false
    to close the public endpoints entirely; Terraform must then run from inside
    the VPCs (for example from a bastion or in-VPC CI runner).
    eks_public_access_cidrs is ignored when this is false.
  EOT
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  default     = []
  description = <<-EOT
    CIDR blocks allowed to reach the EKS public API endpoints. When left empty,
    the sample auto-detects the caller's public IP (via checkip) and uses that
    /32. That only works reliably when your egress is a single, stable public
    IP. Behind a NAT pool, corporate VPN or CI, set this explicitly to your
    egress CIDR(s).
  EOT
  validation {
    condition     = alltrue([for c in var.eks_public_access_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry in eks_public_access_cidrs must be a valid CIDR block (e.g. \"203.0.113.4/32\")."
  }
}


variable "ebs_csi_use_pod_identity" {
  type        = bool
  default     = true
  description = <<-EOT
    Use EKS Pod Identity (true, the default) instead of IRSA (false) for the EBS
    CSI driver in both regions. Pod Identity is the AWS-recommended mechanism and
    also works in accounts whose Organization SCP/RCP denies
    sts:AssumeRoleWithWebIdentity. Set to false for the legacy IRSA path (for
    example Fargate or Windows nodes).
  EOT
}

variable "name_prefix" {
  type        = string
  default     = "cgd-ddc-mr"
  description = "Prefix for names that must be unique per account and region or per hosted zone: the DDC NLBs, the monitoring ALB and target group, and the DNS names (<prefix>.<zone>, <prefix>-<region>.<zone>, monitoring.<prefix>.<zone>). Lets this sample run next to the single region sample. At most 11 characters."
  validation {
    condition     = can(regex("^[a-z0-9-]{1,11}$", var.name_prefix))
    error_message = "name_prefix must be 1-11 lowercase letters, digits or hyphens."
  }
}

variable "allowed_client_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDR blocks allowed to reach the DDC NLBs and the monitoring ALB on ports 80, 443 and 8080 in both regions. Added to your auto-detected IP when allow_my_ip is true. Set this when your egress comes from several IPs (NAT pool, VPN), for example [\"203.0.113.10/32\", \"203.0.113.11/32\"]."
  validation {
    condition     = alltrue([for c in var.allowed_client_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry in allowed_client_cidrs must be a valid CIDR block (e.g. \"203.0.113.4/32\")."
  }
}
