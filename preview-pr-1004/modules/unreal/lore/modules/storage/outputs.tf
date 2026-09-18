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
  value       = aws_dynamodb_table.fragments.name
}

output "fragments_table_arn" {
  description = "DynamoDB fragments table ARN"
  value       = aws_dynamodb_table.fragments.arn
}

output "fragment_metadata_table_name" {
  description = "DynamoDB fragment metadata table name"
  value       = aws_dynamodb_table.fragment_metadata.name
}

output "fragment_metadata_table_arn" {
  description = "DynamoDB fragment metadata table ARN"
  value       = aws_dynamodb_table.fragment_metadata.arn
}

output "mutable_store_table_name" {
  description = "DynamoDB mutable store table name"
  value       = aws_dynamodb_table.mutable_store.name
}

output "mutable_store_table_arn" {
  description = "DynamoDB mutable store table ARN"
  value       = aws_dynamodb_table.mutable_store.arn
}

output "locks_table_name" {
  description = "DynamoDB locks table name"
  value       = aws_dynamodb_table.locks.name
}

output "locks_table_arn" {
  description = "DynamoDB locks table ARN"
  value       = aws_dynamodb_table.locks.arn
}
