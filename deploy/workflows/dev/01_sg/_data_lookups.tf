data "aws_region" "current" {}

data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vps_name]
  }
}
