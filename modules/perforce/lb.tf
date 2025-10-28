# 1. Create the NLB Target Group. This target will be the ALB
##########################################
# Perforce NLB | Target Groups
##########################################
# Send traffic from NLB to ALB
resource "aws_lb_target_group" "perforce" {
  count       = var.create_shared_network_load_balancer != false ? 1 : 0
  name        = "${var.project_prefix}-nlb-to-perforce-web-services"
  target_type = "alb"
  port        = 443
  protocol    = "TCP"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTPS"
    matcher             = "200"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }

  tags = merge(var.tags,
    {
      TrafficSource = (var.shared_network_load_balancer_name != null ? var.shared_network_load_balancer_name :
      "${var.project_prefix}-perforce-shared-nlb")
      TrafficDestination = (var.shared_application_load_balancer_name != null ?
        var.shared_application_load_balancer_name
      : "${var.project_prefix}-perforce-shared-alb")
    }
  )

  depends_on = [
    module.p4_auth,                       # Wait for auth module and its target group
    module.p4_code_review,                # Wait for code review module and its target group
    aws_lb_listener.perforce_web_services # Wait for ALB listener
  ]
}

resource "aws_lb_target_group_attachment" "perforce" {
  count            = var.create_shared_network_load_balancer != false ? 1 : 0
  target_group_arn = aws_lb_target_group.perforce[0].arn
  target_id        = aws_lb.perforce_web_services[0].arn
  port             = 443

}

# 2. Create the NLB only if the NLB Target Group has been created
##########################################
# Perforce Network Load Balancer
##########################################
resource "aws_lb" "perforce" {
  count                            = var.create_shared_network_load_balancer != false ? 1 : 0
  name_prefix                      = var.shared_network_load_balancer_name
  load_balancer_type               = "network"
  subnets                          = var.shared_nlb_subnets
  security_groups                  = concat(var.existing_security_groups, [aws_security_group.perforce_network_load_balancer[0].id])
  drop_invalid_header_fields       = true
  enable_cross_zone_load_balancing = true

  #checkov:skip=CKV_AWS_91: Access logging not required for example deployment
  #checkov:skip=CKV_AWS_150: Load balancer deletion protection disabled for example deployment
  #checkov:skip=CKV2_AWS_28: WAF not required for NLB in example deployment


  dynamic "access_logs" {
    for_each = (
      var.create_shared_application_load_balancer && var.create_shared_application_load_balancer && var.enable_shared_lb_access_logs
      ? [1] :
    [])
    content {
      enabled = var.enable_shared_lb_access_logs
      bucket = (var.shared_lb_access_logs_bucket != null ?
        var.shared_lb_access_logs_bucket :
      aws_s3_bucket.shared_lb_access_logs_bucket[0].id)
      prefix = (var.shared_nlb_access_logs_prefix != null ?
      var.shared_nlb_access_logs_prefix : "${var.project_prefix}-perforce-shared-nlb")
    }
  }

  tags = merge(var.tags,
    {
      Name = (var.shared_network_load_balancer_name != null ? var.shared_network_load_balancer_name :
      "${var.project_prefix}-perforce-shared-nlb")
      Type        = "Network Load Balancer"
      Routability = "PUBLIC"
    }
  )

}

# 3. Create the NLB Listeners only if the Target Group and NLB have been created
##########################################
# Perforce NLB | Listeners
##########################################
# forward HTTPS traffic from Public NLB to Internal ALB
resource "aws_lb_listener" "perforce" {
  count             = var.create_shared_network_load_balancer != false ? 1 : 0
  load_balancer_arn = aws_lb.perforce[0].arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.perforce[0].arn
  }

  #checkov:skip=CKV2_AWS_74: Ensure AWS Load Balancers use strong ciphers
  tags = merge(var.tags,
    {
      TrafficSource = (var.shared_network_load_balancer_name != null ? var.shared_network_load_balancer_name :
      "${var.project_prefix}-perforce-shared-nlb")
      TrafficDestination = (var.shared_application_load_balancer_name != null ?
        var.shared_application_load_balancer_name
      : "${var.project_prefix}-perforce-shared-alb")
    }
  )

  # Force replacement of this listener if changes are made to the NLB, the NLB Target Group (or its attachment), then the destroy the target group. Then recreate them in the reverse order
  lifecycle {
    replace_triggered_by = [
      aws_lb.perforce[0].arn,
      aws_lb_target_group.perforce[0],
      aws_lb_target_group_attachment.perforce[0]
    ]
  }

}


# 1. Create the Target Group (this is done in p4-auth, and p4-code-review submodules)
# 2. Create the Target Group Attachment (this is not necessary as ECS handles this automatically. This is handled in the p4-auth, and p4-code-review submodules in the load_balancers block)
# 3. Create the ALB only if the target group (in submodules) has been created
###################################################
# Perforce Web Services Application Load Balancer
###################################################
resource "aws_lb" "perforce_web_services" {
  count                      = var.create_shared_application_load_balancer ? 1 : 0
  name_prefix                = var.shared_application_load_balancer_name
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = var.shared_alb_subnets
  security_groups            = concat(var.existing_security_groups, [aws_security_group.perforce_web_services_alb[0].id])
  enable_deletion_protection = var.enable_shared_alb_deletion_protection
  drop_invalid_header_fields = true
  #checkov:skip=CKV_AWS_91: Access logging not required for example deployment
  #checkov:skip=CKV_AWS_150: Load balancer deletion protection disabled for example deployment
  #checkov:skip=CKV2_AWS_28: WAF not required for ALB in example deployment
  #checkov:skip=CKV2_AWS_20: HTTP listener does not redirect to HTTPS for internal P4 server communication

  dynamic "access_logs" {
    for_each = (
      var.create_shared_application_load_balancer && var.create_shared_application_load_balancer && var.enable_shared_lb_access_logs
      ? [1] :
    [])
    content {
      enabled = var.enable_shared_lb_access_logs
      bucket = (var.shared_lb_access_logs_bucket != null ?
        var.shared_lb_access_logs_bucket :
      aws_s3_bucket.shared_lb_access_logs_bucket[0].id)
      prefix = (var.shared_alb_access_logs_prefix != null ?
      var.shared_alb_access_logs_prefix : "${var.project_prefix}-perforce-shared-alb")
    }
  }

  tags = merge(var.tags,
    {
      Name = (var.shared_application_load_balancer_name != null ? var.shared_application_load_balancer_name :
      "${var.project_prefix}-perforce-shared-alb")
      Type        = "Application Load Balancer"
      Routability = "PRIVATE"
    }
  )

}


##########################################
# Perforce Web Services (ALB) | Listeners
##########################################
# Used to set dependency on ALB from parent module, since depends_on won't work upstream
# This triggers during the first apply, or if the ALB ARN changes to a different value, such as null
resource "null_resource" "parent_module_certificate" {
  # count = var.create_application_load_balancer
  triggers = {
    certificate_arn = var.certificate_arn
  }

}

# HTTP listener - forward to services (no redirect)
resource "aws_lb_listener" "perforce_web_services_http_listener" {
  count             = var.create_shared_application_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.perforce_web_services[0].arn
  port              = "80"
  protocol          = "HTTP"

  #checkov:skip=CKV_AWS_2: HTTP protocol required for internal P4 server communication
  #checkov:skip=CKV_AWS_103: TLS not applicable for HTTP listener

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Please use a valid subdomain."
      status_code  = "200"
    }
  }

  tags = merge(var.tags,
    {
      TrafficSource      = "Internal"
      TrafficDestination = "SELF"
      Intent             = "Allow HTTP for internal P4 server communication."
    }
  )
}

# HTTP listener rules for P4 Code Review
resource "aws_lb_listener_rule" "p4_code_review_http" {
  count        = var.create_shared_application_load_balancer && var.p4_code_review_config != null ? 1 : 0
  listener_arn = aws_lb_listener.perforce_web_services_http_listener[0].arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = module.p4_code_review[0].target_group_arn
  }
  condition {
    host_header {
      values = [var.p4_code_review_config.fully_qualified_domain_name]
    }
  }

  tags = merge(var.tags,
    {
      TrafficSource      = "Internal"
      TrafficDestination = "${var.project_prefix}-${var.p4_code_review_config.name}-service"
    }
  )

  depends_on = [aws_ecs_cluster.perforce_web_services_cluster]
}

# HTTP listener rules for P4 Auth
resource "aws_lb_listener_rule" "perforce_p4_auth_http" {
  count        = var.create_shared_application_load_balancer && var.p4_auth_config != null ? 1 : 0
  listener_arn = aws_lb_listener.perforce_web_services_http_listener[0].arn
  priority     = 200
  action {
    type             = "forward"
    target_group_arn = module.p4_auth[0].target_group_arn
  }
  condition {
    host_header {
      values = [var.p4_auth_config.fully_qualified_domain_name]
    }
  }

  tags = merge(var.tags,
    {
      TrafficSource      = "Internal"
      TrafficDestination = "${var.project_prefix}-${var.p4_auth_config.name}-service"
    }
  )

  depends_on = [aws_ecs_cluster.perforce_web_services_cluster]
}

# 4. Create the ALB Listeners only if null_resource has completed, and target groups (in submodules) exist
# Default rule sends fixed response status code
resource "aws_lb_listener" "perforce_web_services" {
  count = (
    var.create_shared_application_load_balancer && (var.p4_auth_config != null || var.p4_code_review_config != null)
  ? 1 : 0)
  load_balancer_arn = aws_lb.perforce_web_services[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  #checkov:skip=CKV_AWS_103: TLS 1.2 policy is appropriate for this use case

  # This is to prevent the NLB's Target Group (the ALB) from failing health checks. This must be a fixed response so the NLB knows the ALB is reachable. It expects this instead of a redirect, which would give a 301 response. Otherwise the NLB's Target Group health check would need to expect a 301 (redirect).
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Please use a valid subdomain."
      status_code  = "200"
    }
  }

  tags = merge(var.tags,
    {
      TrafficSource = (var.shared_network_load_balancer_name != null ? var.shared_network_load_balancer_name :
      "${var.project_prefix}-perforce-shared-nlb")
      TrafficDestination = "SELF"
      Intent             = "Return fixed status code to confirm reachability."
    }
  )

}

# P4Auth listener rule - forward from ALB to P4Auth Service
resource "aws_lb_listener_rule" "perforce_p4_auth" {
  count        = var.create_shared_application_load_balancer && var.p4_auth_config != null ? 1 : 0
  listener_arn = aws_lb_listener.perforce_web_services[0].arn
  priority     = 200
  action {
    type = "forward"
    # Target group is created in the P4 Auth submodule
    target_group_arn = module.p4_auth[0].target_group_arn
  }
  condition {
    host_header {
      values = [var.p4_auth_config.fully_qualified_domain_name]
    }
  }


  tags = merge(var.tags,
    {
      TrafficSource = (var.shared_application_load_balancer_name != null ? var.shared_application_load_balancer_name
      : "${var.project_prefix}-perforce-shared-alb")
      TrafficDestination = "${var.project_prefix}-${var.p4_auth_config.name}-service"
    }
  )

  # Delete this listener only after the ECS Cluster is deleted and all targets are deregistered
  depends_on = [aws_ecs_cluster.perforce_web_services_cluster]

}

# P4 Code Review listener rule - forward from ALB to Code Review Service
resource "aws_lb_listener_rule" "p4_code_review" {
  count = var.create_shared_application_load_balancer && var.p4_code_review_config != null ? 1 : 0
  # count        = var.create_shared_application_load_balancer != false && var.p4_server_config != null ? 1 : 0
  listener_arn = aws_lb_listener.perforce_web_services[0].arn
  priority     = 100
  action {
    type = "forward"
    # Target group is created in the P4 Auth submodule
    target_group_arn = module.p4_code_review[0].target_group_arn
  }
  condition {
    host_header {
      values = [var.p4_code_review_config.fully_qualified_domain_name]
    }
  }

  tags = merge(var.tags,
    {
      TrafficSource = (var.shared_application_load_balancer_name != null ?
        var.shared_application_load_balancer_name :
        "${var.project_prefix}-perforce-shared-alb"
      )
      TrafficDestination = "${var.project_prefix}-${var.p4_code_review_config.name}-service"
    }
  )

  # Delete this listener only after the ECS Cluster is deleted and all targets are deregistered
  depends_on = [aws_ecs_cluster.perforce_web_services_cluster]
}


##########################################
# Load Balancers | Logging
##########################################
resource "random_string" "shared_lb_access_logs_bucket" {
  count = (
    (var.create_shared_application_load_balancer || var.create_shared_network_load_balancer) &&
    var.enable_shared_lb_access_logs && var.shared_lb_access_logs_bucket == null
  ? 1 : 0)

  length  = 2
  special = false
  upper   = false
}

resource "aws_s3_bucket" "shared_lb_access_logs_bucket" {
  count = (
    (var.create_shared_application_load_balancer || var.create_shared_network_load_balancer) &&
    var.enable_shared_lb_access_logs && var.shared_lb_access_logs_bucket == null
  ? 1 : 0)

  bucket        = "${var.project_prefix}-perforce-lb-access-logs-${random_string.shared_lb_access_logs_bucket[0].result}"
  force_destroy = var.s3_enable_force_destroy

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  #checkov:skip=CKV2_AWS_61: S3 lifecycle configuration can be conditionally created
  #checkov:skip=CKV2_AWS_6: S3 Buckets have public access blocked by default
  #checkov:skip=CKV_AWS_57: S3 bucket encryption is handled by AWS for ALB access logs

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-perforce-lb-access-logs-${random_string.shared_lb_access_logs_bucket[0].result}"
  })
}


data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "shared_lb_access_logs_bucket_lb_write" {
  count = (
    (var.create_shared_application_load_balancer || var.create_shared_network_load_balancer) &&
    var.enable_shared_lb_access_logs && var.shared_lb_access_logs_bucket == null
  ? 1 : 0)

  statement {
    sid     = "AllowELBRootAccount"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type = "AWS"
      # Allow the ELB service account to create the logs
      identifiers = ["arn:aws:iam::${data.aws_elb_service_account.main.id}:root"]
    }
    resources = [
      # Grant access to bucket root
      "${aws_s3_bucket.shared_lb_access_logs_bucket[0].arn}/*",
    ]
  }

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.shared_lb_access_logs_bucket[0].arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.shared_lb_access_logs_bucket[0].arn]
  }

}

resource "aws_s3_bucket_policy" "shared_lb_access_logs_bucket_policy" {
  count = (
    (var.create_shared_application_load_balancer || var.create_shared_network_load_balancer) &&
    var.enable_shared_lb_access_logs && var.shared_lb_access_logs_bucket == null
  ? 1 : 0)

  bucket = (var.shared_lb_access_logs_bucket == null ?
    aws_s3_bucket.shared_lb_access_logs_bucket[0].id :
  var.shared_lb_access_logs_bucket)
  policy = data.aws_iam_policy_document.shared_lb_access_logs_bucket_lb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "shared_access_logs_bucket_lifecycle_configuration" {
  count = (
    (var.create_shared_application_load_balancer || var.create_shared_network_load_balancer) &&
    var.enable_shared_lb_access_logs && var.shared_lb_access_logs_bucket == null
  ? 1 : 0)


  bucket = aws_s3_bucket.shared_lb_access_logs_bucket[0].id
  rule {
    filter {
      prefix = ""
    }
    id     = "access-logs-lifecycle"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [
    aws_s3_bucket.shared_lb_access_logs_bucket[0]
  ]
}
