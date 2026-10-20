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
  replication_env_vars = var.enable_replication ? [
    { name = "LORE__SERVER__QUIC_INTERNAL__ENABLED", value = "true" },
    { name = "LORE__SERVER__QUIC_INTERNAL__PORT", value = "41340" },
    { name = "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__CERT_FILE", value = "/certs/fullchain.crt" },
    { name = "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__PKEY_FILE", value = "/certs/server.key" },
    { name = "LORE__SERVER__QUIC_INTERNAL__VERIFY_CLIENT_CERTS", value = "false" },
  ] : []

  # Topology overlay — Lore reads peer lists only from a TOML file layer, never from LORE__ env
  # vars, so the init container writes this into /etc/lore/overlay/local.toml and
  # LORE_CONFIG_PATH points there. default.toml is compiled into the binary, so moving the
  # config directory off the image loses nothing.
  topology_toml = length(var.replication_peers) > 0 ? join("\n", concat(
    ["[topology]", "provider = \"fixed\"", "", "[topology.fixed]", "peers = ["],
    [for p in var.replication_peers : format("  { address = \"%s\", port = %d, locality = \"%s\" },", p.address, p.port, p.locality)],
    # The replica factory block is what makes the composite store act on the peer list; without
    # it Lore logs the peers and ignores them. client_message_buffer matches Lore's
    # DEFAULT_CLIENT_MESSAGE_LIMIT (replication_store_service.rs).
    ["]", "", "[immutable_store.composite.replica_factory]", "client_message_buffer = 50000", format("enable_same_region_write = %t", var.enable_same_region_write), ""]
  )) : ""

  # Store backends — the write region uses DynamoDB for everything; a regional tier in another
  # region keeps fragments locally but forwards branch pointers to the write region.
  mutable_store_env_vars = var.mutable_store_mode == "remote" ? [
    { name = "LORE__MUTABLE_STORE__MODE", value = "remote" },
    { name = "LORE__MUTABLE_STORE__REMOTE__REMOTE_URL", value = var.mutable_store_remote_url },
    ] : [
    { name = "LORE__MUTABLE_STORE__MODE", value = "aws" },
    { name = "LORE__PLUGINS__AWS__MUTABLE_STORE__DYNAMODB_TABLE", value = var.mutable_store_table_name },
  ]

  lock_store_env_vars = var.lock_store_mode == "aws" ? concat([
    { name = "LORE__LOCK_STORE__MODE", value = "aws" },
    { name = "LORE__PLUGINS__AWS__LOCK_STORE__DYNAMODB_TABLE", value = var.locks_table_name },
    ], var.lock_store_region != null ? [
    { name = "LORE__PLUGINS__AWS__LOCK_STORE__DYNAMODB_REGION", value = var.lock_store_region },
    ] : []) : [
    { name = "LORE__LOCK_STORE__MODE", value = var.lock_store_mode },
  ]

  # Store wiring that does not depend on the TLS secrets (so tests can see it at plan time)
  immutable_store_env_vars = [

    { name = "LORE_ENV", value = "docker" },
    { name = "LORE_CONFIG_PATH", value = "/etc/lore/overlay" },
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
    { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__S3_BUCKET", value = var.fragment_bucket_name },
    { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__DYNAMODB_FRAGMENTS_TABLE", value = var.fragments_table_name },
    # loreserver >= v0.9.0 requires a fragment *state* table and treats the metadata table as a
    # fallback for objects written before v0.9.0. Both point at the same table: the key schema
    # is identical and the two row shapes coexist (Lore v0.9.0 release notes). Older servers
    # ignore the extra key.
    { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__DYNAMODB_FRAGMENT_STATE_TABLE", value = var.fragment_metadata_table_name },
    { name = "LORE__PLUGINS__AWS__IMMUTABLE_STORE__DYNAMODB_METADATA_TABLE", value = var.fragment_metadata_table_name },
  ]

  # When another tier's CA must be trusted, the server starts through sh so the CA can be appended
  # to the image's system bundle; rustls-native-certs reads SSL_CERT_FILE *instead of* the system
  # bundle, so the file must carry both or AWS SDK calls would stop verifying.
  trusted_ca_entrypoint = var.trusted_ca_pem != null ? {
    entryPoint = ["sh", "-c"]
    command    = ["cat /etc/ssl/certs/ca-certificates.crt /etc/lore/overlay/upstream-ca.pem > /tmp/ca-bundle.pem && export SSL_CERT_FILE=/tmp/ca-bundle.pem && exec loreserver"]
  } : {}

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

  volume {
    name = "lore-config"
  }

  container_definitions = jsonencode(concat(
    # Init container — writes TLS certs to shared volume
    [{
      name              = "init-certs"
      image             = "public.ecr.aws/docker/library/busybox:stable"
      essential         = false
      command           = ["sh", "-c", "echo \"$TLS_CERT\" > /certs/server.crt && echo \"$TLS_KEY\" > /certs/server.key && echo \"$TLS_CA\" > /certs/ca.crt && cat /certs/server.crt /certs/ca.crt > /certs/fullchain.crt && chown 65534:65534 /certs/server.key && chmod 600 /certs/server.key && chmod 644 /certs/server.crt /certs/ca.crt /certs/fullchain.crt && printf '%s\\n' \"$LORE_TOPOLOGY_TOML\" > /etc/lore/overlay/local.toml && printf '%s\\n' \"$LORE_UPSTREAM_CA_PEM\" > /etc/lore/overlay/upstream-ca.pem && chmod 644 /etc/lore/overlay/local.toml /etc/lore/overlay/upstream-ca.pem"]
      memoryReservation = 32

      environment = [
        { name = "LORE_TOPOLOGY_TOML", value = local.topology_toml },
        { name = "LORE_UPSTREAM_CA_PEM", value = var.trusted_ca_pem != null ? var.trusted_ca_pem : "" },
      ]

      secrets = [
        { name = "TLS_CERT", valueFrom = local.tls_cert_secret_arn },
        { name = "TLS_KEY", valueFrom = local.tls_key_secret_arn },
        { name = "TLS_CA", valueFrom = local.tls_ca_secret_arn },
      ]

      mountPoints = [
        { sourceVolume = "certs", containerPath = "/certs", readOnly = false },
        { sourceVolume = "lore-config", containerPath = "/etc/lore/overlay", readOnly = false },
      ]

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
    [merge({
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
        { sourceVolume = "lore-config", containerPath = "/etc/lore/overlay", readOnly = true },
      ]

      secrets = [
        { name = "LORE__SERVER__HTTP__PRESIGNED_URL_HMAC_KEY", valueFrom = local.hmac_key_secret_arn },
      ]

      environment = concat(local.immutable_store_env_vars, local.mutable_store_env_vars, local.lock_store_env_vars, local.auth_env_vars, local.auth_audience_env, local.replication_env_vars)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.loreserver.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "loreserver"
        }
      }
    }, local.trusted_ca_entrypoint)],

    # ADOT sidecar (conditional)
    local.otel_container
  ))

  tags = var.tags
}
