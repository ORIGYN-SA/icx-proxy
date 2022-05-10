data "aws_region" "current" {}

data "aws_kms_key" "cmk" {
  key_id = local.kms_alias
}