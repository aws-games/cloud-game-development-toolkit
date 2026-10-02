locals {
  # ECS service drain with capacity provider managed termination protection:
  # task stop + ECS state machine polling (~2-4 min) +
  # capacity provider reconciliation (~2-5 min) + ASG scale-in signal (~1-2 min).
  # Observed: dev takes ~8-12min. Buffer generously to avoid two-pass destroys.
  service_delete_timeout = 900
}

resource "aws_ecs_service" "loreserver" {
  name            = "${var.name_prefix}-loreserver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.loreserver.arn
  desired_count   = local.asg_desired_size

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.server_security_group_id]
  }

  dynamic "service_registries" {
    for_each = var.service_discovery_registry_arn != null ? [1] : []
    content {
      registry_arn = var.service_discovery_registry_arn
    }
  }

  placement_constraints {
    type = "distinctInstance"
  }

  timeouts {
    delete = "${local.service_delete_timeout}s"
  }

  tags = var.tags
}
