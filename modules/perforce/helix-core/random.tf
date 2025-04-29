# random.tf
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}