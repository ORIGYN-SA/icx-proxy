data "aws_region" "current" {}
data "aws_kms_key" "key" {
  key_id = "alias/${var.kms_name}"
}
data "aws_ecr_repository" "service" {
  name = var.ecr_name
}
data "aws_ssm_parameter" "db_username" {
  name = var.db_username_ssm_parameter_name
}

data "aws_ssm_parameter" "db_password" {
  name = var.db_password_ssm_parameter_name
}