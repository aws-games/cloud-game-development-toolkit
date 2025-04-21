##########################################
# ECS | Cluster
##########################################
# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-cluster"
    }
  )
}


##########################################
# ECS Cluster | Capacity Providers
##########################################
# If cluster name is not provided create a new cluster capacity providers
resource "aws_ecs_cluster_capacity_providers" "cluster_fargate_providers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}


##########################################
# ECS | Task Definition
##########################################
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${local.name_prefix}-task-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  volume {
    name = local.data_volume_name
  }

  container_definitions = jsonencode(
    [
      {
        name      = var.container_name,
        image     = local.image,
        cpu       = var.container_cpu,
        memory    = var.container_memory,
        essential = true,
        portMappings = [
          {
            containerPort = var.container_port,
            hostPort      = var.container_port
            protocol      = "tcp"
          }
        ]
        healthCheck = {
          # command = ["CMD-SHELL", "pwd || exit 1"]
          command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/login || exit 1"]
          startPeriod = 30
        }
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.log_group.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "${local.name_prefix}-service"
          }
        }
        secrets = [
          {
            name      = "P4D_SUPER",
            valueFrom = var.super_user_username_secret_arn
          },
          {
            name      = "P4D_SUPER_PASSWD",
            valueFrom = var.super_user_password_secret_arn
          },
          {
            name      = "SWARM_USER" # cannot change this until the Perforce Helix Swarm Image is updated to use the new naming for P4 Code Review
            valueFrom = var.p4_code_review_user_username_secret_arn
          },
          {
            name      = "SWARM_PASSWD" # cannot change this until the Perforce Helix Swarm Image is updated to use the new naming for P4 Code Review
            valueFrom = var.p4_code_review_user_password_secret_arn
          }
        ]
        environment = [
          {
            name  = "P4D_PORT",
            value = var.p4d_port
          },
          {
            name  = "SWARM_HOST" # cannot update naming until the Perforce container image is updated
            value = var.fully_qualified_domain_name
          },
          {
            name  = "SWARM_REDIS" # cannot update naming until the Perforce container image is updated
            value = var.existing_redis_connection != null ? var.existing_redis_connection.host : aws_elasticache_cluster.cluster[0].cache_nodes[0].address
          },
          {
            name  = "SWARM_REDIS_PORT" # cannot update naming until the Perforce container image is updated
            value = var.existing_redis_connection != null ? tostring(var.existing_redis_connection.port) : tostring(aws_elasticache_cluster.cluster[0].cache_nodes[0].port)
          }
        ],
        readonlyRootFilesystem = false
        mountPoints = [
          {
            sourceVolume  = local.data_volume_name
            containerPath = local.data_path
            readOnly      = false
          }
        ],
      },
      {
        name      = "${var.container_name}-config"
        image     = "bash"
        essential = false
        // Only run this command if enable_sso is set
        command = concat([], var.enable_sso ? [
          "sh",
          "-c",
          "echo \"/p4/a\\\t'sso' => 'enabled',\" > ${local.data_path}/sso.sed && sed -i -f ${local.data_path}/sso.sed ${local.data_path}/config.php && rm -rf ${local.data_path}/cache",
        ] : []),
        readonly_root_filesystem = false

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.log_group.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = "${local.name_prefix}-service-config"
          }
        }
        mountPoints = [
          {
            sourceVolume  = local.data_volume_name
            containerPath = local.data_path
          }
        ],
        dependsOn = [
          {
            containerName = var.container_name
            condition     = "HEALTHY"
          }
        ]
      }
    ]
  )

  task_role_arn      = var.custom_role != null ? var.custom_role : aws_iam_role.default_role[0].arn
  execution_role_arn = aws_iam_role.task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-task-definition"
    }
  )
}


##########################################
# ECS | Service
##########################################
resource "aws_ecs_service" "service" {
  name = "${local.name_prefix}-service"

  cluster         = var.cluster_name != null ? data.aws_ecs_cluster.cluster[0].arn : aws_ecs_cluster.cluster[0].arn
  task_definition = aws_ecs_task_definition.task_definition.arn
  launch_type     = "FARGATE"
  # This is set to 0 because the aws_appautoscaling_target resource will be used. This will allow us to control the desired count, especially during the terraform destroy which prevents the error where a listener cannot be destroyed because the targets managed by ECS are still registered. This resource allows us to deregister these, giving more control over how ECS registers and deregisters targets.
  desired_count = var.desired_container_count
  # Allow ECS to delete a service even if deregistration is taking time. This is to prevent the ALB listener in the parent module from failing to be deleted in the event that all registered targets (ECS services) haven't been destroyed yet.
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  # wait_for_steady_state = true

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.ecs_service.id]
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-service"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_count] # Let Application Auto Scaling manage this
  }

  timeouts {
    create = "20m"
  }



  depends_on = [aws_elasticache_cluster.cluster, aws_lb_target_group.alb_target_group]
}



##########################################
# Application Auto Scaling | Target
##########################################
# This is used
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.desired_container_count
  min_capacity       = 0 # allow ECS to scale down to 0 targets to prevent listener in parent module from failing to be deleted
  resource_id        = "service/${var.project_prefix}-perforce-web-services-shared-cluster/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [
    aws_ecs_service.service
  ]
}

# Used to set dependency on ALB from parent module, since depends_on won't work upstream
# This triggers during the first apply, or if the ALB ARN changes to a different value, such as null
resource "null_resource" "parent_alb" {
  # count = var.create_application_load_balancer
  triggers = {
    shared_alb_arn = var.existing_application_load_balancer_arn
  }

}

##########################################
# Application Auto Scaling | Policy
##########################################
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${local.name_prefix}-scale-up"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = var.desired_container_count
    }
  }

  depends_on = [
    aws_lb_target_group.alb_target_group,
    aws_ecs_service.service,
    aws_appautoscaling_target.ecs_target,
  ]
}


##########################################
# CloudWatch
##########################################
resource "aws_cloudwatch_log_group" "log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-log-group"
    }
  )
}

resource "aws_cloudwatch_log_group" "redis_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-redis-log-group"
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-redis-log-group"
    }
  )
}
