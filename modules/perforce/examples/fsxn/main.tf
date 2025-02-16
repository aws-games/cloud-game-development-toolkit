##########################################
# Shared ECS Cluster for Services
##########################################

resource "aws_ecs_cluster" "perforce_cluster" {
  name = "perforce-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.perforce_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

##########################################
# FSx ONTAP File System
##########################################

resource "aws_fsx_ontap_file_system" "helix_core_fs" {
  storage_capacity    = 1024
  subnet_ids          = [aws_subnet.private_subnets[0].id]
  preferred_subnet_id = aws_subnet.private_subnets[0].id
  deployment_type     = "SINGLE_AZ_1"
  throughput_capacity = 128
  fsx_admin_password = var.fsxn_password
}

resource "aws_fsx_ontap_storage_virtual_machine" "helix_core_svm" {
  file_system_id = aws_fsx_ontap_file_system.helix_core_fs.id
  name           = "helix_core_svm"
}

resource "awscc_secretsmanager_secret" "fsxn_user_password" {
  count         = var.protocol == "ISCSI" ? 1 : 0
  name          = "perforceFSxnUserPassword"
  secret_string = var.fsxn_password
}

##########################################
# Perforce Helix Core
##########################################

module "perforce_helix_core" {
  source = "../../helix-core"
  providers = {
    aws = aws
  }

  # Networking
  vpc_id                      = aws_vpc.perforce_vpc.id
  instance_subnet_id          = aws_subnet.private_subnets[0].id
  internal                    = true
  fully_qualified_domain_name = "core.helix.perforce.${var.root_domain_name}"

  # Compute and Storage
  instance_type         = "c8g.large"
  instance_architecture = "arm64"
  storage_type          = "FSxN"
  depot_volume_size     = 64
  metadata_volume_size  = 32
  logs_volume_size      = 32
  fsxn_region           = var.fsxn_region
  protocol              = var.protocol

  # FSxN configuration - FSxN NFS
  amazon_fsxn_filesystem_id = var.protocol == "NFS" ? aws_fsx_ontap_file_system.helix_core_fs.id : ""
  amazon_fsxn_svm_id        = var.protocol == "NFS" ? aws_fsx_ontap_storage_virtual_machine.helix_core_svm.id : ""

  # FSxN configuration - FSxN ISCSI
  fsxn_aws_profile     = var.protocol == "ISCSI" ? var.fsxn_aws_profile : ""
  fsxn_password        = var.protocol == "ISCSI" ? awscc_secretsmanager_secret.fsxn_user_password[0].secret_id : ""
  fsxn_mgmt_ip         = var.protocol == "ISCSI" ? "management.${aws_fsx_ontap_file_system.helix_core_fs.id}.fsx.${var.fsxn_region}.amazonaws.com" : ""
  fsxn_svm_name        = var.protocol == "ISCSI" ? aws_fsx_ontap_storage_virtual_machine.helix_core_svm.name : ""


  # Configuration
  plaintext                        = true # We will use the Perforce NLB to handle TLS termination
  server_type                      = "p4d_commit"
}

##########################################
# Perforce Helix Authentication Service
##########################################

module "perforce_helix_authentication_service" {
  source = "../../helix-authentication-service"

  # Networking
  vpc_id                               = aws_vpc.perforce_vpc.id
  create_application_load_balancer     = false # Shared Perforce web services application load balancer
  helix_authentication_service_subnets = aws_subnet.private_subnets[*].id
  fully_qualified_domain_name          = "auth.perforce.${var.root_domain_name}"

  # Compute
  cluster_name = aws_ecs_cluster.perforce_cluster.name

  # Configuration
  enable_web_based_administration = true

  depends_on = [aws_ecs_cluster.perforce_cluster]
}

##########################################
# Perforce Helix Swarm
##########################################
module "perforce_helix_swarm" {
  source = "../../helix-swarm"

  # Networking
  vpc_id                           = aws_vpc.perforce_vpc.id
  create_application_load_balancer = false # Shared Perforce web services application load balancer
  helix_swarm_service_subnets      = aws_subnet.private_subnets[*].id
  fully_qualified_domain_name      = "swarm.perforce.${var.root_domain_name}"

  # Compute
  cluster_name = aws_ecs_cluster.perforce_cluster.name

  # Configuration
  p4d_port                    = "${aws_route53_record.internal_helix_core.name}:1666"
  p4d_super_user_arn          = module.perforce_helix_core.helix_core_super_user_username_secret_arn
  p4d_super_user_password_arn = module.perforce_helix_core.helix_core_super_user_password_secret_arn
  p4d_swarm_user_arn          = module.perforce_helix_core.helix_core_super_user_username_secret_arn
  p4d_swarm_password_arn      = module.perforce_helix_core.helix_core_super_user_password_secret_arn
  enable_sso                  = true

  depends_on = [aws_ecs_cluster.perforce_cluster]
}

##########################################
# Perforce Network Load Balancer
##########################################
resource "aws_lb" "perforce" {
  name                             = "perforce"
  load_balancer_type               = "network"
  subnets                          = aws_subnet.public_subnets[*].id
  security_groups                  = [aws_security_group.perforce_network_load_balancer.id]
  drop_invalid_header_fields       = true
  enable_cross_zone_load_balancing = true
  #checkov:skip=CKV_AWS_91: Access logging not required for example deployment
  #checkov:skip=CKV_AWS_150: Load balancer deletion protection disabled for example deployment
}

###################################################
# Perforce Web Services Application Load Balancer
###################################################
resource "aws_lb" "perforce_web_services" {
  name                       = "perforce-web-services"
  load_balancer_type         = "application"
  subnets                    = aws_subnet.private_subnets[*].id
  internal                   = true
  security_groups            = [aws_security_group.perforce_web_services_alb.id]
  drop_invalid_header_fields = true
  #checkov:skip=CKV_AWS_91: Access logging not required for example deployment
  #checkov:skip=CKV_AWS_150: Load balancer deletion protection disabled for example deployment
}

##########################################
# Helix Core Target Group
##########################################
resource "aws_lb_target_group" "helix_core" {
  name        = "helix-core"
  target_type = "instance"
  port        = 1666
  protocol    = "TCP"
  vpc_id      = aws_vpc.perforce_vpc.id
}

resource "aws_lb_target_group_attachment" "helix_core" {
  target_group_arn = aws_lb_target_group.helix_core.arn
  target_id        = module.perforce_helix_core.helix_core_instance_id
  port             = 1666
}

##########################################
# Web Services Target Group
##########################################
resource "aws_lb_target_group" "perforce_web_services" {
  name        = "perforce-web-services"
  target_type = "alb"
  port        = 443
  protocol    = "TCP"
  vpc_id      = aws_vpc.perforce_vpc.id
}

# Default rule redirects to Helix Swarm
resource "aws_lb_listener" "perforce_web_services" {
  load_balancer_arn = aws_lb.perforce_web_services.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.perforce.certificate_arn

  default_action {
    type = "redirect"
    redirect {
      host        = "swarm.perforce.${var.root_domain_name}"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Helix Swarm listener rule
resource "aws_lb_listener_rule" "perforce_helix_swarm" {
  listener_arn = aws_lb_listener.perforce_web_services.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = module.perforce_helix_swarm.target_group_arn
  }
  condition {
    host_header {
      values = ["swarm.perforce.${var.root_domain_name}"]
    }
  }
}

# Helix Authentication Service listener rule
resource "aws_lb_listener_rule" "perforce_helix_authentication_service" {
  listener_arn = aws_lb_listener.perforce_web_services.arn
  priority     = 200
  action {
    type             = "forward"
    target_group_arn = module.perforce_helix_authentication_service.target_group_arn
  }
  condition {
    host_header {
      values = ["auth.perforce.${var.root_domain_name}"]
    }
  }
}

##########################################
# Helix Core Listener
##########################################
resource "aws_lb_listener" "helix_core" {
  load_balancer_arn = aws_lb.perforce.arn
  port              = 1666
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.perforce.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.helix_core.arn
  }
}

##########################################
# Perforce Web Services Listener
##########################################
resource "aws_lb_listener" "perforce_web_services_alb" {
  load_balancer_arn = aws_lb.perforce.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.perforce_web_services.arn
  }
}
