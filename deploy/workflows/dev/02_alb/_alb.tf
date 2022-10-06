module "alb" {
  source              = "../../../modules/alb"
  alb_name            = local.alb_name
  alb_tg_name         = local.alb_tg_name
  health_check_path   = var.health_check_path
  load_balancer_type  = var.load_balancer_type
  public_subnet_ids   = data.aws_subnets.public_subnets.ids
  security_group_ids  = data.aws_security_group.alb.id
  vpc_id              = data.aws_vpc.selected_vpc.id
  tsl_certificate_arn = var.tsl_certificate_arn
  waf_enable          = var.waf_enable
  waf_web_acl_name    = var.waf_web_acl_name
  tags                = local.common_tags
}

#module "nlb" {
#  source              = "../../../modules/nlb"
#  nlb_name            = local.nlb_name
#  nlb_tg_name         = local.nlb_tg_name
#  health_check_path   = var.health_check_path
#  container_port      = var.container_port
#  load_balancer_type  = "network"
#  public_subnet_ids   = data.aws_subnets.public_subnets.ids
#  vpc_id              = data.aws_vpc.selected_vpc.id
#  tsl_certificate_arn = var.tsl_certificate_arn
#  waf_enable          = var.waf_enable
#  waf_web_acl_name    = var.waf_web_acl_name
#  tags                = local.common_tags
#}