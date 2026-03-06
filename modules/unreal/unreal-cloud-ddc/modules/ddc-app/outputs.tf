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