locals {
  name_prefix = "${var.project_prefix}-${var.environment}"

  tags = {
    Project     = var.project_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Decision 7: Validate instance store requirement
  validate_instance_store = (
    !var.require_instance_store ||
    can(regex("^(i4i|i3en|im4gn|is4gen|c8gd|c7gd|m7gd|r7gd|r6id)", var.instance_type))
  )
}

# Cross-variable validation (Terraform can't do this in variable blocks)
check "instance_store_validation" {
  assert {
    condition     = local.validate_instance_store
    error_message = "When require_instance_store is true, instance_type must be from an instance store family (i4i, i3en, im4gn, is4gen, c8gd, c7gd, m7gd, r7gd, r6id). Set require_instance_store = false to override."
  }
}

check "ingress_cidr_not_open" {
  assert {
    condition     = !contains(var.allowed_ingress_cidrs, "0.0.0.0/0")
    error_message = "It is recommended to use specific CIDRs for your studio network rather than 0.0.0.0/0. See docs/user/security.md for guidance."
  }
}

check "tiering_days_ordering" {
  assert {
    condition = (
      var.intelligent_tiering_archive_days == 0 ||
      var.intelligent_tiering_deep_archive_days > var.intelligent_tiering_archive_days
    )
    error_message = "intelligent_tiering_deep_archive_days must be greater than intelligent_tiering_archive_days when tiering is enabled."
  }
}

check "arm64_instance_needs_arm64_image" {
  assert {
    condition = (
      !contains(["c8gd", "c8g", "c7gd", "c7g", "c7gn", "m7g", "m7gd", "m8g", "r7g", "r7gd", "r8g", "t4g", "im4gn", "is4gen", "x2gd", "hpc7g"], split(".", var.instance_type)[0]) ||
      can(regex("arm64|aarch64|graviton", lower(var.container_image)))
    )
    error_message = "ARM64/Graviton instance types (c8gd, c7g, m7g, t4g, etc.) require an ARM64 container image. Verify your image supports linux/arm64."
  }
}
