# AWS Provider - optional, can rely on environment/credentials
# provider "aws" {
#   region = local.region
# }

################################################################################
# ⚠️  CRITICAL: Provider Configuration Requirements
################################################################################
# 
# The cluster_name in data sources MUST be a value you KNOW will exist when 
# terraform apply runs. DO NOT use module outputs or computed values here.
#
# ❌ WRONG: data.aws_eks_cluster.name = module.ddc.cluster_name
# ✅ CORRECT: data.aws_eks_cluster.name = "cgd-dev-unreal-cloud-ddc-cluster-us-east-1"
#
# WHY: Provider configurations are evaluated BEFORE resources are created.
# Using computed values creates race conditions and dependency cycles.
#
# 📖 Learn more: https://developer.hashicorp.com/terraform/language/providers/configuration
################################################################################

# Kubernetes Provider - configured with data sources and try()
provider "kubernetes" {
  host = try(data.aws_eks_cluster.main.endpoint, "https://localhost")
  cluster_ca_certificate = try(
    base64decode(data.aws_eks_cluster.main.certificate_authority[0].data),
    null
  )
  token = try(data.aws_eks_cluster_auth.main.token, null)
}

# Helm Provider - configured with data sources and try()
provider "helm" {
  kubernetes {
    host = try(data.aws_eks_cluster.main.endpoint, "https://localhost")
    cluster_ca_certificate = try(
      base64decode(data.aws_eks_cluster.main.certificate_authority[0].data),
      null
    )
    token = try(data.aws_eks_cluster_auth.main.token, null)
  }
}
