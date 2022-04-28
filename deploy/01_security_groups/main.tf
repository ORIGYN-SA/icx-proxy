resource "aws_security_group" "alb" {
  name   = local.alb_sg_name
  vpc_id = data.aws_vpc.selected_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = local.alb_sg_name
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = local.ecs_task_sg
  vpc_id = data.aws_vpc.selected_vpc.id


  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.ecs_task_sg
  }
}
resource "aws_security_group_rule" "alb_rule1" {
  from_port = var.container_port
  protocol = "tcp"
  security_group_id = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  to_port = var.container_port
  type = "egress"
}
resource "aws_security_group_rule" "ecs_rule1" {
  from_port = var.container_port
  protocol = "tcp"
  security_group_id = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb.id
  to_port = var.container_port
  type = "ingress"
}