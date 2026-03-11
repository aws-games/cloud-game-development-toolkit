################################################################################
# DDC Application Deployment Outputs
################################################################################

output "codebuild_projects" {
  description = "CodeBuild project information for monitoring deployment progress"
  value = {
    deployer = {
      name = aws_codebuild_project.ddc_deployer.name
      arn  = aws_codebuild_project.ddc_deployer.arn
    }
    tester = {
      name = aws_codebuild_project.ddc_tester.name
      arn  = aws_codebuild_project.ddc_tester.arn
    }
  }
}

output "codebuild_role_arn" {
  description = "CodeBuild IAM role ARN for cross-region sharing"
  value       = var.is_primary_region ? aws_iam_role.codebuild_role[0].arn : null
}