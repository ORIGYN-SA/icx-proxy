resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = var.load_balancer_type
  security_groups    = [data.aws_security_group.alb.id]
  subnets            = data.aws_subnets.public_subnets.ids

  enable_deletion_protection = false

  tags = {
    Name = local.alb_name
  }
}

resource "aws_alb_target_group" "main" {
  name        = local.alb_tg_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected_vpc.id
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

  tags = {
    Name = local.alb_tg_name
  }
}

# Redirect traffic to target group
resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }

}
