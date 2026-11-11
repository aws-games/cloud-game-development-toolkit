mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-west-2" }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-arm64mock"
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "archive" {}

run "edge_pods_service_discovery_plans" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    instance_type         = "c8gd.8xlarge"
  }

  assert {
    condition     = output.write_tier_discovery_dns == "write-tier.lore-dev.internal"
    error_message = "write_tier_discovery_dns must resolve to Cloud Map DNS name"
  }
}

run "write_tier_enables_mtls_listener_for_edge_pods" {
  command = plan

  variables {
    project_prefix              = "lore"
    environment                 = "dev"
    container_image             = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    allowed_ingress_cidrs       = ["10.0.0.0/8"]
    instance_type               = "c8gd.8xlarge"
    enable_internal_replication = true
    trusted_ca_pem              = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
  }

  assert {
    condition = (
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__VERIFY_CLIENT_CERTS"]) == "true" &&
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__CERT_CHAIN"]) == "/etc/lore/overlay/replication-ca-bundle.pem"
    )
    error_message = "Edge-pod support must enable a fail-closed mTLS replication listener"
  }
  assert {
    condition = (
      module.compute.replication_client_certificate_secret_arn == null &&
      module.compute.replication_client_private_key_secret_arn == null
    )
    error_message = "A listener-only write tier must not share an unnecessary client identity with edge pods"
  }
}

run "edge_pod_presents_mtls_identity_and_validates_server" {
  command = plan

  module {
    source = "./modules/edge-pod"
  }

  variables {
    vpc_id                                    = "vpc-0123456789abcdef0"
    subnet_id                                 = "subnet-0123456789abcdef0"
    server_security_group_id                  = "sg-0123456789abcdef0"
    container_image                           = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    write_tier_dns                            = "write-tier.lore-dev.internal"
    ca_certificate_pem                        = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    replication_client_certificate_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:lore-client-cert-AbCdEf"
    replication_client_private_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:lore-client-key-AbCdEf"
    replication_client_ca_certificate_pem     = "-----BEGIN CERTIFICATE-----\nEDGE\n-----END CERTIFICATE-----"
    replication_client_material_version       = "rotation-2"
    allowed_ingress_cidrs                     = ["10.0.0.0/8"]
    name_prefix                               = "edge-1"
    hmac_key                                  = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition = (
      strcontains(base64decode(aws_instance.edge.user_data_base64), "Replication identity revision: rotation-2") &&
      strcontains(base64decode(aws_instance.edge.user_data_base64), "REMOTE_URL=lores://write-tier.lore-dev.internal:41340") &&
      strcontains(base64decode(aws_instance.edge.user_data_base64), "REPLICATED__CERTS__CERT_FILE=/certs/replication-client.crt") &&
      strcontains(base64decode(aws_instance.edge.user_data_base64), "REPLICATED__CERTS__PKEY_FILE=/certs/replication-client.key") &&
      strcontains(base64decode(aws_instance.edge.user_data_base64), "REPLICATED__CERTS__CERT_CHAIN=/certs/write-tier-ca.pem")
    )
    error_message = "The edge pod must use lores://, validate the write tier, and present its mTLS client identity"
  }

  assert {
    condition     = output.replication_client_ca_certificate_pem == "-----BEGIN CERTIFICATE-----\nEDGE\n-----END CERTIFICATE-----"
    error_message = "A custom edge identity must expose its dedicated CA for write-tier trust"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.write_tier_from_edge[0].from_port == 41337 &&
      aws_vpc_security_group_ingress_rule.write_tier_from_edge[0].to_port == 41337 &&
      aws_vpc_security_group_ingress_rule.write_tier_from_edge[0].ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.write_tier_from_edge_quic[0].from_port == 41337 &&
      aws_vpc_security_group_ingress_rule.write_tier_from_edge_quic[0].ip_protocol == "udp" &&
      aws_vpc_security_group_ingress_rule.write_tier_from_edge_udp[0].from_port == 41340 &&
      aws_vpc_security_group_ingress_rule.write_tier_from_edge_udp[0].ip_protocol == "udp"
    )
    error_message = "Edge-to-write-tier ingress must expose 41337 TCP/UDP and 41340 UDP only"
  }

  assert {
    condition     = aws_instance.edge.user_data_replace_on_change
    error_message = "Bootstrap changes must replace an edge instance because cloud-init runs userdata only once"
  }
}

run "edge_pod_rejects_public_ingress" {
  command = plan

  module {
    source = "./modules/edge-pod"
  }

  variables {
    vpc_id                                    = "vpc-0123456789abcdef0"
    subnet_id                                 = "subnet-0123456789abcdef0"
    container_image                           = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    write_tier_dns                            = "write-tier.lore-dev.internal"
    ca_certificate_pem                        = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    replication_client_certificate_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:lore-client-cert-AbCdEf"
    replication_client_private_key_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:lore-client-key-AbCdEf"
    replication_client_ca_certificate_pem     = "-----BEGIN CERTIFICATE-----\nEDGE\n-----END CERTIFICATE-----"
    allowed_ingress_cidrs                     = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_ingress_cidrs]
}

run "edge_pod_generates_dedicated_client_identity" {
  command = plan

  module {
    source = "./modules/edge-pod"
  }

  variables {
    vpc_id                = "vpc-0123456789abcdef0"
    subnet_id             = "subnet-0123456789abcdef0"
    container_image       = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    write_tier_dns        = "write-tier.lore-dev.internal"
    ca_certificate_pem    = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
    hmac_key              = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition = (
      length(tls_self_signed_cert.replication_client_ca) == 1 &&
      length(tls_locally_signed_cert.replication_client) == 1 &&
      tls_self_signed_cert.replication_client_ca[0].early_renewal_hours == 720 &&
      tls_locally_signed_cert.replication_client[0].early_renewal_hours == 720 &&
      toset(tls_locally_signed_cert.replication_client[0].allowed_uses) == toset(["digital_signature", "key_encipherment", "client_auth"]) &&
      length(aws_secretsmanager_secret.replication_client_cert) == 1 &&
      length(aws_secretsmanager_secret.replication_client_key) == 1
    )
    error_message = "Each edge pod must generate its own clientAuth identity and two runtime secrets"
  }
}

run "write_tier_edge_listener_requires_dedicated_client_ca" {
  command = plan

  variables {
    project_prefix              = "lore"
    environment                 = "dev"
    container_image             = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:arm64"
    allowed_ingress_cidrs       = ["10.0.0.0/8"]
    enable_internal_replication = true
    trusted_ca_pem              = null
  }

  expect_failures = [var.trusted_ca_pem]
}
