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

  container_definitions = jsonencode([
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
      environment = concat([
        {
          name  = "SVC_BASE_URI"
          value = "https://${var.fully_qualified_domain_name}"
        },
        {
          name  = "ADMIN_ENABLED"
          value = var.enable_web_based_administration ? "true" : "false"
        },
        {
          name  = "TRUST_PROXY"
          value = "true"
        },
        ],
        var.enable_web_based_administration ? [
          {
            name  = "ADMIN_PASSWD_FILE",
            value = "${local.data_path}/password.txt"
          }
        ] : [],
        var.p4d_port != null ? [
          {
            name  = "P4PORT"
            value = var.p4d_port
          }
        ] : [],
        var.scim_bearer_token_arn != null ? [
          {
            name  = "BEARER_TOKEN_FILE"
            value = "${local.data_path}/bearer_token.txt"
          }
        ] : [],
      )
      secrets = concat([],
        var.p4d_super_user_password_arn != null ? [
          {
            name      = "P4PASSWD"
            valueFrom = var.p4d_super_user_password_arn
          }
        ] : [],
        var.p4d_super_user_arn != null ? [
          {
            name      = "P4USER"
            valueFrom = var.p4d_super_user_arn
          }
        ] : [],
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "${local.name_prefix}-service"
        }
      }
      mountPoints = [
        {
          sourceVolume  = local.data_volume_name
          containerPath = local.data_path
        }
      ],
      healthCheck = {
        command = [
          "CMD-SHELL", "curl http://localhost:${var.container_port} || exit 1"
        ]
      }
      dependsOn = [
        {
          containerName = "${var.container_name}-config"
          condition     = "COMPLETE"
        }
      ]
    },
    {
      name                     = "${var.container_name}-config"
      image                    = "bash"
      essential                = false
      command                  = ["sh", "-c", "echo $ADMIN_PASSWD | tee ${local.data_path}/password.txt && echo -n $BEARER_TOKEN | base64 | tee ${local.data_path}/bearer_token.txt"]
      readonly_root_filesystem = false
      secrets = concat([],
        var.enable_web_based_administration ? [
          {
            name      = "ADMIN_USERNAME"
            valueFrom = var.admin_username_secret_arn != null ? var.admin_username_secret_arn : awscc_secretsmanager_secret.admin_username[0].secret_id
          },
          {
            name      = "ADMIN_PASSWD"
            valueFrom = var.admin_password_secret_arn != null ? var.admin_password_secret_arn : awscc_secretsmanager_secret.admin_password[0].secret_id
          },
        ] : [],
        var.scim_bearer_token_arn != null ? [
          {
            name      = "BEARER_TOKEN"
            valueFrom = var.scim_bearer_token_arn
          }
        ] : [],
      )
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
    }
  ])

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
  desired_count   = "1" # P4Auth does not support horizontal scaling, so desired container count is fixed at 1
  # Allow ECS to delete a service even if deregistration is taking time. This is to prevent the ALB listener in the parent module from failing to be deleted in the event that all registered targets (ECS services) haven't been destroyed yet.
  force_delete           = true
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  wait_for_steady_state = true

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
    # create_before_destroy = true
    ignore_changes = [desired_count] # Let Application Auto Scaling manage this
  }

  timeouts {
    create = "20m"
  }

  depends_on = [aws_lb_target_group.alb_target_group]
}


##########################################
# Secrets Manager
##########################################
resource "awscc_secretsmanager_secret" "admin_username" {
  count         = var.admin_username_secret_arn == null && var.enable_web_based_administration == true ? 1 : 0
  name          = "${local.name_prefix}-AdminUsername"
  description   = "The username for the created P4Auth administrator."
  secret_string = "perforce"
}

resource "awscc_secretsmanager_secret" "admin_password" {
  count       = var.admin_password_secret_arn == null && var.enable_web_based_administration == true ? 1 : 0
  name        = "${local.name_prefix}-AdminUserPassword"
  description = "The password for the created P4Auth administrator."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
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
