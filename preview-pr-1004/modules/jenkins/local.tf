locals {
  jenkins_image     = "jenkins/jenkins:lts-jdk17"
  jenkins_home_path = "/var/jenkins_home"
  name_prefix       = "${var.project_prefix}-${var.name}"

  tags = merge(var.tags, {
    "environment" = var.environment
  })
}
