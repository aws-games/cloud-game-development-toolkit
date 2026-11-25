locals {
  # Pinned weekly build: lts-jdk17 is no longer updated and lts-jdk21 predates the
  # patched JDK (CVE-2026-114938). Move to lts-jdk21 once a build with JDK >= 21.0.13.1 ships.
  jenkins_image     = "jenkins/jenkins:2.592-jdk21"
  jenkins_home_path = "/var/jenkins_home"
  name_prefix       = "${var.project_prefix}-${var.name}"

  tags = merge(var.tags, {
    "environment" = var.environment
  })
}
