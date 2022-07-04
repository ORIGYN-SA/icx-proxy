module "kms" {
  source   = "../../../modules/kms"
  kms_name = local.kms_name
  tags     = local.common_tags
}