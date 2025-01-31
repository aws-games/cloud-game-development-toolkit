
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
          hostPort      = var.container_port,
          protocol      = "tcp"
        }
      ],
      entryPoint = [
        "bash",
        "-c",
        "mv /srv/aws-cgd-toolkit/config/config.toml /srv/config.toml && exec node bin/www.js"
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.helix_authentication_service_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "helix-auth-svc"
        }
      },
      mountPoints = [
        {
          sourceVolume  = "helix-auth-config"
          containerPath = "/srv/aws-cgd-toolkit/config"
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
          condition     = "SUCCESS"
        }
      ]
    },
    {
      name                     = "helix-auth-svc-config"
      image                    = "public.ecr.aws/aws-cli/aws-cli:latest"
      essential                = false
      command                  = ["s3", "cp", "s3://${aws_s3_object.helix_authentication_service_config[0].bucket}/${aws_s3_object.helix_authentication_service_config[0].key}", "/aws-cgd-toolkit/config/config.toml"]
      readonly_root_filesystem = false
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
          containerPath = "/aws-cgd-toolkit/config"
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
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

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
# helix_authentication_service S3 CONFIGURATION BUCKET
########################################

# Generate random suffix for bucket name
resource "random_string" "helix_authentication_service_config_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "helix_authentication_service_config_bucket" {
  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  #checkov:skip=CKV2_AWS_61: Lifecycle policy not necessary as file is frequently modified
  bucket = "${local.name_prefix}-config-bucket-${random_string.helix_authentication_service_config_bucket_suffix.result}"
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-config-bucket-${random_string.helix_authentication_service_config_bucket_suffix.result}"
  })
}

# Conditionally create helix auth svc config object in S3
resource "aws_s3_object" "helix_authentication_service_config" {
  count                  = (var.use_local_config_file && var.local_config_file_path != null ? 1 : 0)
  bucket                 = aws_s3_bucket.helix_authentication_service_config_bucket.bucket
  key                    = basename(var.local_config_file_path)
  source                 = var.local_config_file_path
  etag                   = filemd5(var.local_config_file_path)
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_public_access_block" "helix_authentication_service_config_bucket_public_block" {
  depends_on = [
    aws_s3_bucket.helix_authentication_service_config_bucket
  ]
  bucket                  = aws_s3_bucket.helix_authentication_service_config_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
