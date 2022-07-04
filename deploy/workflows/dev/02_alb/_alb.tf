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
  tags                = local.common_tags
}