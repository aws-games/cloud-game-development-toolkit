variable "github_credential_arn" {
  type        = string
  sensitive   = true
  description = "Github Credential ARN"
}

variable "allow_my_ip" {
  type        = bool
  default     = true
  description = "Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers"
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  default     = []
  description = <<-EOT
    CIDR blocks allowed to reach the EKS public API endpoint. When left empty,
    the sample auto-detects the caller's single public IP (via checkip) and
    uses that /32. That auto-detect path only works reliably when your egress
    is a single, stable public IP. If you are behind a NAT pool, corporate VPN,
    or run Terraform from CI (where the egress IP is not stable or differs
    between the plan and the in-cluster Helm/addon apply), set this explicitly
    to your egress CIDR(s). For production, prefer private endpoint access and
    running Terraform from inside the VPC instead of widening this list.
  EOT
  validation {
    condition     = alltrue([for c in var.eks_public_access_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry in eks_public_access_cidrs must be a valid CIDR block (e.g. \"203.0.113.4/32\")."
  }
}

variable "eks_api_local_port" {
  type        = number
  default     = null
  description = <<-EOT
    Localhost port that an SSM port-forward forwards to the EKS API server.
    Leave null (default) to connect directly to the cluster public endpoint.
    Set this (with a running SSM tunnel from scripts/eks-api-tunnel.sh) when the
    public endpoint is unreachable from your host (corporate NAT/VPN/CI) and you
    must reach the cluster's PRIVATE endpoint instead. Connections then go to
    127.0.0.1:<port> while TLS is still validated against the real cluster
    hostname (tls_server_name), so CA validation stays intact.
  EOT
  validation {
    condition     = var.eks_api_local_port == null || (var.eks_api_local_port >= 1024 && var.eks_api_local_port <= 65535)
    error_message = "eks_api_local_port must be null or a port between 1024 and 65535."
  }
}
