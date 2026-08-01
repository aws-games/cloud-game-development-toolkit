data "aws_region" "current" {}

locals {
  # Auth env vars — set when auth_mode != "none" and jwk_endpoint is provided
  auth_env_vars = var.auth_mode != "none" && var.auth_jwk_endpoint != null ? [
    { name = "LORE__SERVER__AUTH__JWK__ENDPOINT", value = var.auth_jwk_endpoint },
    { name = "LORE__SERVER__AUTH__JWT_ISSUER", value = var.auth_jwt_issuer },
  ] : []

  auth_audience_env = length(var.auth_jwt_audience) > 0 ? [
    { name = "LORE__SERVER__AUTH__JWT_AUDIENCE", value = join(",", var.auth_jwt_audience) }
  ] : []

  # Replication env vars — conditional on enable_replication
  replication_env_vars = var.enable_replication ? concat([
    { name = "LORE__SERVER__QUIC_INTERNAL__ENABLED", value = "true" },
    { name = "LORE__SERVER__QUIC_INTERNAL__PORT", value = "41340" },
    { name = "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__CERT_FILE", value = "/certs/fullchain.crt" },
    { name = "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__PKEY_FILE", value = "/certs/server.key" },
    { name = "LORE__SERVER__QUIC_INTERNAL__VERIFY_CLIENT_CERTS", value = "false" },
    ], length(var.replication_peers) > 0 ? [
    { name = "LORE__TOPOLOGY__PROVIDER", value = "fixed" },
    { name = "LORE__TOPOLOGY__FIXED__PEERS", value = jsonencode([for peer in var.replication_peers : { address = split(":", peer)[0], port = tonumber(split(":", peer)[1]), locality = "same_region" }]) },
  ] : []) : []

  # ADOT sidecar container definition
  otel_container = var.enable_otel_sidecar ? [{
    name              = "aws-otel-collector"
    image             = var.otel_collector_image
    essential         = false
    command           = ["--config=/etc/ecs/ecs-xray.yaml"]
    memoryReservation = 256
    healthCheck = {
      command     = ["CMD", "/healthcheck"]
      interval    = 5
      timeout     = 6
      retries     = 5
      startPeriod = 1
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.loreserver.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "otel"
      }
    }
  }] : []
}

resource "aws_ecs_task_definition" "loreserver" {
  family                   = "${var.name_prefix}-loreserver"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = local.is_arm64 ? "ARM64" : "X86_64"
  }

  volume {
    name      = "instance-store-cache"
    host_path = "/srv/urc"
  }

  volume {
    name = "certs"
  }

  container_definitions = jsonencode(concat(
    # Init container — writes TLS certs to shared volume
    [{
      name              = "init-certs"
      image             = "public.ecr.aws/docker/library/busybox:stable"
      essential         = false
      command           = ["sh", "-c", "echo \"$TLS_CERT\" > /certs/server.crt && echo \"$TLS_KEY\" > /certs/server.key && echo \"$TLS_CA\" > /certs/ca.crt && cat /certs/server.crt /certs/ca.crt > /certs/fullchain.crt && chown 65534:65534 /certs/server.key && chmod 600 /certs/server.key && chmod 644 /certs/server.crt /certs/ca.crt /certs/fullchain.crt"]
      memoryReservation = 32

      secrets = [
        { name = "TLS_CERT", valueFrom = local.tls_cert_secret_arn },
        { name = "TLS_KEY", valueFrom = local.tls_key_secret_arn },
        { name = "TLS_CA", valueFrom = local.tls_ca_secret_arn },
      ]

      mountPoints = [{ sourceVolume = "certs", containerPath = "/certs", readOnly = false }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.loreserver.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "init-certs"
        }
      }
    }],

    # Main loreserver container
    [{
      name              = "loreserver"
      image             = var.container_image
      user              = var.container_user
      memoryReservation = local.container_memory_reservation

      dependsOn = [{ containerName = "init-certs", condition = "SUCCESS" }]

      portMappings = concat([
        { containerPort = 41337, protocol = "tcp" },
        { containerPort = 41339, protocol = "tcp" },
        ], var.enable_replication ? [
        { containerPort = 41340, protocol = "tcp" },
      ] : [])

      mountPoints = [
        { sourceVolume = "instance-store-cache", containerPath = "/srv/urc", readOnly = false },
        { sourceVolume = "certs", containerPath = "/certs", readOnly = true },
      ]

      secrets = [
        { name = "LORE__SERVER__HTTP__PRESIGNED_URL_HMAC_KEY", valueFrom = local.hmac_key_secret_arn },
      ]

      environment = concat([
        { name = "LORE_ENV", value = "docker" },
        { name = "LORE_CONFIG_PATH", value = "/etc/lore/config" },
        { name = "LORE__SERVER__QUIC__CERTIFICATE__CERT_FILE", value = "/certs/fullchain.crt" },
        { name = "LORE__SERVER__QUIC__CERTIFICATE__PKEY_FILE", value = "/certs/server.key" },
        { name = "LORE__SERVER__GRPC__CERTIFICATE__CERT_FILE", value = "/certs/fullchain.crt" },
        { name = "LORE__SERVER__GRPC__CERTIFICATE__PKEY_FILE", value = "/certs/server.key" },
        { name = "LORE__SERVER__GRPC__VERIFY_CLIENT_CERTS", value = "false" },
        { name = "LORE__IMMUTABLE_STORE__MODE", value = "composite" },
        { name = "LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__MODE", value = "local" },
        { name = "LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__LOCAL__PATH", value = "/srv/urc" },
        { name = "LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__LOCAL__MAX_SIZE", value = tostring(local.cache_max_size) },
        { name = "LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__LOCAL__FLUSH_DELAY_SECONDS", value = "10" },
        { name = "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__MODE", value = "aws" },
        { name = "LORE__MUTABLE_STORE__MODE", value = "aws" },
        { name = "LORE__LOCK_STORE__MODE", value = "aws" },
        { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__S3_BUCKET", value = var.fragment_bucket_name },
        { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__DYNAMODB_FRAGMENTS_TABLE", value = var.fragments_table_name },
        { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__DYNAMODB_METADATA_TABLE", value = var.fragment_metadata_table_name },
        { name = "LORE__PLUGINS__AWS__MUTABLE_STORE__DYNAMODB_TABLE", value = var.mutable_store_table_name },
        { name = "LORE__PLUGINS__AWS__LOCK_STORE__DYNAMODB_TABLE", value = var.locks_table_name },
      ], local.auth_env_vars, local.auth_audience_env, local.replication_env_vars)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.loreserver.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "loreserver"
        }
      }
    }],

    # ADOT sidecar (conditional)
    local.otel_container
  ))

  tags = var.tags
}
