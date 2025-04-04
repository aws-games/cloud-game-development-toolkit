output "pipeline_arn" {
  description = "ARN of the created image pipeline"
  value       = aws_imagebuilder_image_pipeline.container_image_pipeline.arn
}
