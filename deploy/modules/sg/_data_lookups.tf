data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}
