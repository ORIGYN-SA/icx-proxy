data "aws_region" "current" {}

data "aws_kms_key" "key" {
  count  = var.kms_key_enable ? 1 : 0
  key_id = "alias/${var.kms_name}"
}

data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vps_name]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]
  }
  tags = {
    Name = "*private"
  }
}

data "aws_security_group" "redis" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]
  }
  tags = {
    Name = var.redis_sg_name
  }
}

data "aws_ssm_parameter" "db_username" {
  name = var.db_username_ssm_parameter_name
}

data "aws_ssm_parameter" "db_password" {
  name = var.db_password_ssm_parameter_name
}

