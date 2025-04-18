output "codebuild_project_name" {
  description = "Name of the created CodeBuild project"
  value       = aws_codebuild_project.codebuild_project.name
}

output "ecr_repository_url" {
  description = "URL of the created ECR repository"
  value       = aws_ecr_repository.ecr_repository.repository_url
}
