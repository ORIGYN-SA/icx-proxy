module "ecr" {
  source   = "../../../modules/ecr"
  ecr_name = local.ecr_name
  kms_name = local.kms_name
  tags     = local.common_tags
}