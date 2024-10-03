
# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "helix_authentication_service_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "helix_authentication_service_cluster_fargate_providers" {
  count        = var.cluster_name != null ? 0 : 1
  cluster_name = aws_ecs_cluster.helix_authentication_service_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
resource "awscc_secretsmanager_secret" "helix_authentication_service_admin_username" {
  count         = var.helix_authentication_service_admin_username_secret_arn == null && var.enable_web_based_administration == true ? 1 : 0
  name          = "helixAuthServiceAdminUsername"
  secret_string = "perforce"
}

resource "awscc_secretsmanager_secret" "helix_authentication_service_admin_password" {
  count       = var.helix_authentication_service_admin_password_secret_arn == null && var.enable_web_based_administration == true ? 1 : 0
  name        = "helixAuthServiceAdminUserPassword"
  description = "The password for the created Helix Authentication Service administrator."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
}

resource "aws_cloudwatch_log_group" "helix_authentication_service_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.helix_authentication_service_cloudwatch_log_retention_in_days
  tags              = local.tags
}

# Define helix_authentication_service task definition
resource "aws_ecs_task_definition" "helix_authentication_service_task_definition" {
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
      image     = local.helix_authentication_service_image,
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
            value = "/var/has/password.txt"
          }
        ] : []
      )
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.helix_authentication_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "helix-auth-svc"
        }
      }
      mountPoints = [
        {
          sourceVolume  = "helix-auth-config"
          containerPath = "/var/has"
        }
      ],
      healthCheck = {
        command = [
          "CMD-SHELL", "curl http://localhost:${var.container_port} || exit 1"
        ]
      }
      dependsOn = [
        {
          containerName = "helix-auth-svc-config"
          condition     = "COMPLETE"
        }
      ]
    },
    {
      name                     = "helix-auth-svc-config"
      image                    = "bash"
      essential                = false
      command                  = ["sh", "-c", "echo $ADMIN_PASSWD | tee /var/has/password.txt"]
      readonly_root_filesystem = false
      secrets = var.enable_web_based_administration ? [
        {
          name      = "ADMIN_USERNAME"
          valueFrom = var.helix_authentication_service_admin_username_secret_arn != null ? var.helix_authentication_service_admin_username_secret_arn : awscc_secretsmanager_secret.helix_authentication_service_admin_username[0].secret_id
        },
        {
          name      = "ADMIN_PASSWD"
          valueFrom = var.helix_authentication_service_admin_password_secret_arn != null ? var.helix_authentication_service_admin_username_secret_arn : awscc_secretsmanager_secret.helix_authentication_service_admin_password[0].secret_id
        },
      ] : [],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.helix_authentication_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "helix-auth-svc-config"
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

  task_role_arn      = var.custom_helix_authentication_service_role != null ? var.custom_helix_authentication_service_role : aws_iam_role.helix_authentication_service_default_role[0].arn
  execution_role_arn = aws_iam_role.helix_authentication_service_task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Define helix_authentication_service service
resource "aws_ecs_service" "helix_authentication_service" {
  name = local.name_prefix

  cluster                = var.cluster_name != null ? data.aws_ecs_cluster.helix_authentication_service_cluster[0].arn : aws_ecs_cluster.helix_authentication_service_cluster[0].arn
  task_definition        = aws_ecs_task_definition.helix_authentication_service_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = var.desired_container_count
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  wait_for_steady_state = true

  load_balancer {
    target_group_arn = aws_lb_target_group.helix_authentication_service_alb_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets         = var.helix_authentication_service_subnets
    security_groups = [aws_security_group.helix_authentication_service_sg.id]
  }

  tags = local.tags
}

########################################
# helix_authentication_service LOAD BALANCER SECURITY GROUP
########################################

# helix_authentication_service Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "helix_authentication_service_alb_sg" {
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "helix_authentication_service ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "helix_authentication_service_alb_outbound_service" {
  security_group_id            = aws_security_group.helix_authentication_service_alb_sg.id
  description                  = "Allow outbound traffic from helix_authentication_service ALB to helix_authentication_service service"
  referenced_security_group_id = aws_security_group.helix_authentication_service_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

########################################
# helix_authentication_service SERVICE SECURITY GROUP
########################################

# helix_authentication_service Service Security Group (attached to containers)
resource "aws_security_group" "helix_authentication_service_sg" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "helix_authentication_service Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "helix_authentication_service_outbound_ipv4" {
  security_group_id = aws_security_group.helix_authentication_service_sg.id
  description       = "Allow outbound traffic from helix_authentication_service service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "helix_authentication_service_outbound_ipv6" {
  security_group_id = aws_security_group.helix_authentication_service_sg.id
  description       = "Allow outbound traffic from helix_authentication_service service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "helix_authentication_service_inbound_alb" {
  security_group_id            = aws_security_group.helix_authentication_service_sg.id
  description                  = "Allow inbound traffic from helix_authentication_service ALB to service"
  referenced_security_group_id = aws_security_group.helix_authentication_service_alb_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}
