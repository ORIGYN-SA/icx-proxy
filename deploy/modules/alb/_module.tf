resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = var.load_balancer_type
  security_groups    = [var.security_group_ids]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge({ Name = var.alb_name }, var.tags)
}

resource "aws_alb_target_group" "main" {
  name        = var.alb_tg_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  tags = merge({ Name = var.alb_tg_name }, var.tags)
}

# Redirect traffic to target group
resource "aws_alb_listener" "http" {
  count             = var.tsl_certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }

}

resource "aws_alb_listener" "http_to_https" {
  count             = var.tsl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

}
resource "aws_alb_listener" "https" {
  count             = var.tsl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.tsl_certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }
}
