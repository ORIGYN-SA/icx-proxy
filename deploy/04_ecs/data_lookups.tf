data "aws_region" "current" {}

data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vps_name]
  }
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]
  }
  tags = {
    Name = "*private"
  }
}

data "aws_ecr_repository" "service" {
  name = local.ecr_name
}

data "aws_lb_target_group" "alb_tg_group" {
  name = local.alb_tg_name
}

data "aws_security_group" "ecs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]
  }
  tags = {
    Name = local.ecs_task_sg
  }
}