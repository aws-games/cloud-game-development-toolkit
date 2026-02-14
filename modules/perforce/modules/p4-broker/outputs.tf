output "service_security_group_id" {
  value       = aws_security_group.ecs_service.id
  description = "Security group associated with the ECS service running P4 Broker"
}

output "cluster_name" {
  value       = var.cluster_name != null ? var.cluster_name : aws_ecs_cluster.cluster[0].name
  description = "Name of the ECS cluster hosting P4 Broker"
}

output "target_group_arn" {
  value       = aws_lb_target_group.nlb_target_group.arn
  description = "The NLB target group ARN for P4 Broker"
}

output "service_arn" {
  value       = aws_ecs_service.service.id
  description = "The ARN of the P4 Broker ECS service"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.task_definition.arn
  description = "The ARN of the P4 Broker task definition"
}

output "config_bucket_name" {
  value       = aws_s3_bucket.broker_config.id
  description = "The name of the S3 bucket containing the broker configuration"
}
