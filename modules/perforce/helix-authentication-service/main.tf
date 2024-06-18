
# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "HAS_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "HAS_cluster_fargate_rpvodiers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.HAS_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "awscc_secretsmanager_secret" "has_admin_password" {
  count       = var.has_admin_password_secret_arn == null && var.enable_web_based_administration == true ? 1 : 0
  name        = "hasAdminUserPassword"
  description = "The password for the created HAS administrator."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
}

resource "awscc_secretsmanager_secret" "has_admin_username" {
  count         = var.has_admin_username_secret_arn == null && var.enable_web_based_administration == true ? 1 : 0
  name          = "hasAdminUsername"
  secret_string = "perforce"
}


resource "aws_cloudwatch_log_group" "HAS_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.HAS_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Define HAS task definition
resource "aws_ecs_task_definition" "HAS_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  volume {
    name = "helix-auth-config"
  }

  container_definitions = jsonencode([
    {
      name      = var.container_name,
      image     = local.HAS_image,
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
          name  = "SVC_BASE_URL"
          value = var.fqdn
        },
        {
          name  = "ADMIN_ENABLED"
          value = var.enable_web_based_administration ? "true" : "false"
        },

        ],
        var.enable_web_based_administration ? [
          {
            name  = "ADMIN_PASSWD_FILE",
            value = "/var/has/password.txt"
          }
        ] : []
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.HAS_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "HAS"
        }
      }
      mountPoints = [
        {
          sourceVolume  = "helix-auth-config"
          containerPath = "/var/has"
        }
      ],
      dependsOn = [
        {
          containerName = "has-config"
          condition     = "COMPLETE"
        }
      ]
    },
    {
      name                     = "has-config"
      image                    = "bash"
      essential                = false
      command                  = ["sh", "-c", "echo $ADMIN_PASSWD | tee /var/has/password.txt"]
      readonly_root_filesystem = false
      secrets = var.enable_web_based_administration ? [
        {
          name      = "ADMIN_USERNAME"
          valueFrom = var.has_admin_username_secret_arn != null ? var.has_admin_username_secret_arn : awscc_secretsmanager_secret.has_admin_username[0].secret_id
        },
        {
          name      = "ADMIN_PASSWD"
          valueFrom = var.has_admin_password_secret_arn != null ? var.has_admin_username_secret_arn : awscc_secretsmanager_secret.has_admin_password[0].secret_id
        },
      ] : [],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.HAS_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "HAS-config"
        }
      }
      mountPoints = [
        {
          sourceVolume  = "helix-auth-config"
          containerPath = "/var/has"
        }
      ],
    }
  ])

  task_role_arn      = var.custom_HAS_role != null ? var.custom_HAS_role : aws_iam_role.HAS_default_role[0].arn
  execution_role_arn = aws_iam_role.HAS_task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Define HAS service
resource "aws_ecs_service" "HAS_service" {
  name = "${local.name_prefix}-service"

  cluster              = var.cluster_name != null ? data.aws_ecs_cluster.HAS_cluster[0].arn : aws_ecs_cluster.HAS_cluster[0].arn
  task_definition      = aws_ecs_task_definition.HAS_task_definition.arn
  launch_type          = "FARGATE"
  desired_count        = var.desired_container_count
  force_new_deployment = true

  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.HAS_alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets         = var.HAS_service_subnets
    security_groups = [aws_security_group.HAS_service_sg.id]
  }

  tags = local.tags
}

########################################
# HAS LOAD BALANCER SECURITY GROUP
########################################

# HAS Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "HAS_alb_sg" {
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "HAS ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "HAS_alb_outbound_service" {
  security_group_id            = aws_security_group.HAS_alb_sg.id
  description                  = "Allow outbound traffic from HAS ALB to HAS service"
  referenced_security_group_id = aws_security_group.HAS_service_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

########################################
# HAS SERVICE SECURITY GROUP
########################################

# HAS Service Security Group (attached to containers)
resource "aws_security_group" "HAS_service_sg" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "HAS Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "HAS_service_outbound_ipv4" {
  security_group_id = aws_security_group.HAS_service_sg.id
  description       = "Allow outbound traffic from HAS service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "HAS_service_outbound_ipv6" {
  security_group_id = aws_security_group.HAS_service_sg.id
  description       = "Allow outbound traffic from HAS service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "HAS_service_inbound_alb" {
  security_group_id            = aws_security_group.HAS_service_sg.id
  description                  = "Allow inbound traffic from HAS ALB to service"
  referenced_security_group_id = aws_security_group.HAS_alb_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}





