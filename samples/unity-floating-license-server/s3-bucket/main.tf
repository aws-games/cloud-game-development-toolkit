resource "aws_s3_bucket" "unity_floating_license_bucket" {
  #checkov:skip=CKV_AWS_144: Cross region replication is not required
  #checkov:skip=CKV_AWS_145: Sample not for production use
  #checkov:skip=CKV_AWS_21: Doesn't need to be versioned
  #checkov:skip=CKV_AWS_18: Sample doesnt need logging
  #checkov:skip=CKV2_AWS_62: Sample doesnt need notifications
  #checkov:skip=CKV2_AWS_61: Sample doesnt need life cycle events
  #checkov:skip=CKV2_AWS_6: Sample doesnt need public access block
  bucket_prefix = "unity-floating-license-bucket-"
  force_destroy = true
}
