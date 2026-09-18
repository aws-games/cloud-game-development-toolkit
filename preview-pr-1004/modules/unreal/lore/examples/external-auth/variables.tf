variable "container_image" {
  description = "Loreserver container image URI"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.", var.container_image))
    error_message = "Must be an ECR image URI. Format: <account_id>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>"
  }
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach Lore"
  type        = list(string)
}

variable "auth_jwk_endpoint" {
  description = "Your IdP's JWKS endpoint URL (e.g., https://login.yourstudio.com/.well-known/jwks.json)"
  type        = string
}

variable "auth_jwt_issuer" {
  description = "JWT issuer string from your IdP (e.g., https://login.yourstudio.com)"
  type        = string
}

variable "auth_jwt_audience" {
  description = "JWT audience values the server should accept"
  type        = list(string)
  default     = ["lore-server"]
}
