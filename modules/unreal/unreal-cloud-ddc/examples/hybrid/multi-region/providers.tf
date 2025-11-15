# Helm providers removed - using local-exec with Helm CLI for single-apply compatibility
# This eliminates bootstrap issues where Helm provider fails during terraform plan
# when EKS cluster is created in the same Terraform run

# Benefits of local-exec approach:
# ✅ Single terraform apply works reliably
# ✅ Uses same Helm CLI commands as CI/CD pipelines
# ✅ No provider bootstrap timing issues
# ✅ Future-ready for Terraform Actions migration