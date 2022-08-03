module "ssm" {
  source             = "../../../modules/ssm"
  ssm_parameter_list = local.ssm_parameter_list
  kms_name           = local.kms_name
  tags               = local.common_tags

}