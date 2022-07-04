module "ecr" {
  source   = "../../../modules/ecr"
  ecr_name = local.ecr_name
  tags     = local.common_tags
}