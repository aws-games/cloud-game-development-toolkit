# - Random String to prevent naming conflicts -
resource "random_string" "artifact_buckets" {
  length  = 4
  special = false
  upper   = false
}


resource "aws_s3_bucket" "artifact_buckets" {
  for_each = var.artifact_buckets
  bucket   = "${var.project_prefix}-${each.value.name}-${random_string.artifact_buckets.result}"

  force_destroy = each.value.enable_force_destroy

  tags = merge(
    {
      "ENVIRONMENT" = var.environment
    },
    var.tags,
  )
}
