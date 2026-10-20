output "fragment_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.fragments.id
}

output "fragment_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.fragments.arn
}

output "fragments_table_name" {
  description = "DynamoDB fragments table name"
  value       = try(aws_dynamodb_table.fragments[0].name, null)
}

output "fragments_table_arn" {
  description = "DynamoDB fragments table ARN"
  value       = try(aws_dynamodb_table.fragments[0].arn, null)
}

output "fragment_metadata_table_name" {
  description = "DynamoDB fragment metadata table name"
  value       = try(aws_dynamodb_table.fragment_metadata[0].name, null)
}

output "fragment_metadata_table_arn" {
  description = "DynamoDB fragment metadata table ARN"
  value       = try(aws_dynamodb_table.fragment_metadata[0].arn, null)
}

output "mutable_store_table_name" {
  description = "DynamoDB mutable store table name"
  value       = try(aws_dynamodb_table.mutable_store[0].name, null)
}

output "mutable_store_table_arn" {
  description = "DynamoDB mutable store table ARN"
  value       = try(aws_dynamodb_table.mutable_store[0].arn, null)
}

output "locks_table_name" {
  description = "DynamoDB locks table name"
  value       = try(aws_dynamodb_table.locks[0].name, null)
}

output "locks_table_arn" {
  description = "DynamoDB locks table ARN"
  value       = try(aws_dynamodb_table.locks[0].arn, null)
}

output "replication_role_arn" {
  description = "IAM role used by S3 Cross-Region Replication (null when replication is disabled)"
  value       = try(aws_iam_role.replication[0].arn, null)
}

output "replication_summary" {
  description = "How this store replicates (for tests and the example README)"
  value = {
    enabled                         = local.replication_enabled
    bucket_versioning               = aws_s3_bucket_versioning.fragments.versioning_configuration[0].status
    replication_time_control        = local.replication_enabled && var.replication_time_control
    immutable_table_replica_regions = var.immutable_table_replica_regions
    immutable_table_streams         = length(var.immutable_table_replica_regions) > 0
    mutable_table_replica_regions   = length(try(aws_dynamodb_table.mutable_store[0].replica, [])) + length(try(aws_dynamodb_table.locks[0].replica, []))
  }
}

output "fragment_bucket_versioning_id" {
  description = "ID of the bucket versioning resource; known once versioning is applied. Hand it to the other region as replication_destination_ready."
  value       = try(aws_s3_bucket_versioning.fragments[0].id, null)
}
