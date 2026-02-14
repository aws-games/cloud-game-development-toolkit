##########################################
# NLB | Target Group
##########################################
resource "aws_lb_target_group" "nlb_target_group" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-tg"
  })
}
