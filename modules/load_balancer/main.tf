resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  internal                   = false
  ip_address_type            = "ipv4"
  subnets                    = var.subnet_ids
  security_groups            = [var.security_group_id]
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"
  tags                       = { Name = var.name }
}

resource "aws_lb_target_group" "wordpress" {
  name                 = var.name
  vpc_id               = var.vpc_id
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  deregistration_delay = 120

  health_check {
    enabled             = true
    path                = "/health.php"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "cloudfront_only" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    http_header {
      http_header_name = "X-Xtremax-Origin-Verify"
      values           = [var.origin_header_value]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}
