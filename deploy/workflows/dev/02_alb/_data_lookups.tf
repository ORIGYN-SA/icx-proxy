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
    Name = "*public"
  }
}
data "aws_security_group" "alb" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]
  }
  tags = {
    Name = local.alb_sg_name
  }
}