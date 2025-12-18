# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "unreal_horde_cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}

# If cluster name is not provided create a new cluster
resource "aws_ecs_cluster" "unreal_horde_cluster" {
  count = var.cluster_name != null ? 0 : 1
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "unreal_horde_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.unreal_horde_cloudwatch_log_retention_in_days
  tags              = local.tags
}

resource "aws_ecs_task_definition" "unreal_horde_task_definition" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory

  volume {
    name = "unreal-horde-config"
  }

  container_definitions = jsonencode(concat([
    {
      name  = var.container_name
      image = var.image
      repositoryCredentials = var.github_credentials_secret_arn != null ? {
        "credentialsParameter" : var.github_credentials_secret_arn
      } : null
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_api_port
          hostPort      = var.container_api_port
        },
        {
          containerPort = var.container_grpc_port
          hostPort      = var.container_grpc_port
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL", "apt update && apt install curl -y && curl http://localhost:${var.container_api_port}/health/ok || exit 1",
        ]
        interval    = 5
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }
      environment = [
        {
          name  = "P4TRUST"
          value = "/app/config/.p4trust"
        },
        {
          name  = "Horde__DataDir"
          value = "/app/config"
        },
        {
          name  = "ASPNETCORE_ENVIRONMENT"
          value = var.environment
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "[APP]"
        }
      }
      mountPoints = [
        {
          sourceVolume  = "unreal-horde-config",
          containerPath = "/app/config"
        }
      ]
      dependsOn = concat(
        [{
          containerName = "unreal-horde-config"
          condition     = "SUCCESS"
        }],
        local.need_p4_trust ? [{
          containerName = "unreal-horde-p4-trust",
          condition     = "SUCCESS"
        }] : []
      )
    },
    {
      name      = "unreal-horde-config",
      image     = "registry.gitlab.com/gitlab-ci-utils/curl-jq:latest"
      essential = false
      command = ["/bin/bash", "-exc",
        <<-EOF
        mkdir -p /app/config/

        # Pull the PEM bundle required to connect to DocDB
        wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -P /app/config/

        # Create the global config
        jq -n '{
          Version: 2,

          Macros: [
            ${join(", ", [for macro in [
        {
          Condition = var.p4_port != null
          Name      = "P4PORT"
          Value     = "\"${var.p4_port}\""
        },
        {
          Condition = var.p4_super_user_username_secret_arn != null
          Name      = "P4USER"
          Value     = "env.P4_SUPER_USERNAME"
        },
        {
          Condition = var.p4_super_user_password_secret_arn != null
          Name      = "P4PASSWD",
          Value     = "env.P4_SUPER_PASSWORD",
        },
    ] : "{ Name: \"${macro.Name}\", Value: ${macro.Value} }" if macro.Condition])}
          ],

          %{if var.config_path != null}
          Include: [
            { Path: "${var.config_path}" }
          ],
          %{endif}
        }' > /app/config/globals.json

        # Create the server config
        jq -n '{
          Horde: {
            ConfigPath: "/app/config/globals.json",
            ServerUrl: "https://${var.fully_qualified_domain_name}",
            DashboardUrl: "https://${var.fully_qualified_domain_name}",

            MongoPublicCertificate: "/app/config/global-bundle.pem",
            MongoConnectionString: "${local.database_connection_string}",
            RedisConnectionString: "${local.redis_connection_config}",

            EnableDebugEndpoints: ${var.debug},
            ForceConfigUpdateOnStartup: true,

            Plugins: {
              Build: {
                UseLocalPerforceEnv: false,
                Perforce: [{
                  %{if var.p4_port != null && var.p4_super_user_username_secret_arn != null && var.p4_super_user_password_secret_arn != null}
                  ServerAndPort: "${var.p4_port}",
                  Credentials: {
                    UserName: env.P4_SUPER_USERNAME,
                    Password: env.P4_SUPER_PASSWORD,
                  },
                  %{endif}
                }],
              },
              Compute: {
                WithAws: true,
                AutoEnrollAgents: ${var.enable_new_agents_by_default},
              }
            },

            %{for key, value in local.server_config~}
            %{if value != null~}
            ${key}: "${value}",
            %{endif~}
            %{endfor~}
          },

          AWS: {
            Region: "${data.aws_region.current.region}",
          },
        } * ${jsonencode(var.extra_server_config)}' > /app/config/server.json

        %{if var.deploy_dex~}
        echo '${yamlencode(local.dex_config)}' > /app/config/dex.yaml
        %{if var.dex_auth_secret_arn != null~}
        echo $DEX_AUTH_JSON > /app/config/dex_auth.json
        %{endif}
        %{endif}
        EOF
      ]
      secrets = [for config in [
        {
          name      = "P4_SUPER_USERNAME"
          valueFrom = var.p4_super_user_username_secret_arn
        },
        {
          name      = "P4_SUPER_PASSWORD"
          valueFrom = var.p4_super_user_password_secret_arn
        },
        {
          name      = "DEX_AUTH_JSON"
          valueFrom = var.dex_auth_secret_arn
        }
      ] : config.valueFrom != null ? config : null]
      readonly_root_filesystem = false
      mountPoints = [
        {
          sourceVolume  = "unreal-horde-config",
          containerPath = "/app/config"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "[P4CONFIG]"
        }
      },
    }],
    local.need_p4_trust ? [{
      name      = "unreal-horde-p4-trust",
      image     = "public.ecr.aws/ubuntu/ubuntu:noble"
      essential = false
      command = ["bash", "-exc", <<-EOF
        apt-get update
        apt-get install -y curl gnupg unzip
        curl -fs https://package.perforce.com/perforce.pubkey | gpg --dearmor -o /usr/share/keyrings/perforce.gpg
        echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] https://package.perforce.com/apt/ubuntu noble release" > /etc/apt/sources.list.d/perforce.list
        apt-get update
        apt-get install -y p4-cli
        p4 -p ${var.p4_port} trust -y

        # Upload the p4trust file for agents to pull
        %{if length(var.agents) > 0}
        curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
        unzip awscliv2.zip
        ./aws/install
        rm -rf awscliv2.zip aws

        aws s3 cp $P4TRUST s3://${aws_s3_bucket.ansible_playbooks[0].id}/agent/.p4trust
        %{endif}
      EOF
      ]
      readonly_root_filesystem = false
      mountPoints = [
        {
          sourceVolume  = "unreal-horde-config",
          containerPath = "/app/config"
        }
      ]
      environment = [
        {
          name  = "P4TRUST"
          value = "/app/config/.p4trust"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "[P4TRUST]"
        }
      },
    }] : [],
    var.deploy_dex ? [{
      name                     = var.dex_container_name,
      image                    = "public.ecr.aws/bitnami/dex:2"
      essential                = true
      readonly_root_filesystem = false
      command                  = ["serve", "/app/config/dex.yaml"]
      mountPoints = [
        {
          sourceVolume  = "unreal-horde-config",
          containerPath = "/app/config"
        }
      ]
      portMappings = [
        {
          containerPort = var.dex_container_port
          hostPort      = var.dex_container_port
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL", "curl http://localhost:${var.dex_container_port} || exit 1",
        ]
        interval    = 5
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.unreal_horde_log_group.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "[DEX]"
        }
      },
      dependsOn = [{
        containerName = "unreal-horde-config"
        condition     = "SUCCESS"
      }],
    }] : []
  ))
  tags = {
    Name = var.name
  }
  task_role_arn      = var.custom_unreal_horde_role != null ? var.custom_unreal_horde_role : aws_iam_role.unreal_horde_default_role[0].arn
  execution_role_arn = aws_iam_role.unreal_horde_task_execution_role.arn
}

resource "aws_ecs_service" "unreal_horde" {
  name = local.name_prefix

  cluster                = var.cluster_name != null ? data.aws_ecs_cluster.unreal_horde_cluster[0].arn : aws_ecs_cluster.unreal_horde_cluster[0].arn
  task_definition        = aws_ecs_task_definition.unreal_horde_task_definition.arn
  launch_type            = "FARGATE"
  desired_count          = var.desired_container_count
  force_new_deployment   = var.debug
  enable_execute_command = var.debug

  wait_for_steady_state = true

  # External target group for API traffic
  dynamic "load_balancer" {
    for_each = var.create_external_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_api_target_group_external[0].arn
      container_name   = var.container_name
      container_port   = var.container_api_port
    }
  }

  # External target group for GRPC traffic
  dynamic "load_balancer" {
    for_each = var.create_external_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_grpc_target_group_external[0].arn
      container_name   = var.container_name
      container_port   = var.container_grpc_port
    }
  }

  # External target group for dex traffic
  dynamic "load_balancer" {
    for_each = var.create_external_alb && var.deploy_dex ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_dex_target_group_external[0].arn
      container_name   = var.dex_container_name
      container_port   = var.dex_container_port
    }
  }

  # Internal target group for API traffic
  dynamic "load_balancer" {
    for_each = var.create_internal_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_api_target_group_internal[0].arn
      container_name   = var.container_name
      container_port   = var.container_api_port
    }
  }

  # Internal target group for GRPC traffic
  dynamic "load_balancer" {
    for_each = var.create_internal_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_grpc_target_group_internal[0].arn
      container_name   = var.container_name
      container_port   = var.container_grpc_port
    }
  }

  # Internal target group for dex traffic
  dynamic "load_balancer" {
    for_each = var.create_internal_alb && var.deploy_dex ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.unreal_horde_dex_target_group_internal[0].arn
      container_name   = var.dex_container_name
      container_port   = var.dex_container_port
    }
  }

  network_configuration {
    subnets         = var.unreal_horde_service_subnets
    security_groups = [aws_security_group.unreal_horde_sg.id]
  }

  tags = local.tags

  depends_on = [aws_docdb_cluster_instance.horde, aws_elasticache_cluster.horde]
}
