locals {
  tags = merge(
    {
      "environment" = var.environment
    },
    var.tags,
  )
}
