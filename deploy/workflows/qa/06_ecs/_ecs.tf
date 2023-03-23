module "ecs" {
  source = "../../../modules/ecs"

  ecr_name                       = local.ecr_name
  app_name_prefix                = local.name_prefix
  ecs_cluster_name               = local.ecs_cluster_name
  ecs_service_name               = local.ecs_service_name
  ecs_task_definition_name       = local.ecs_task_definition_name
  private_subnet_ids             = data.aws_subnets.private_subnets.ids
  security_group_ids             = data.aws_security_group.ecs.id
  alb_tg_group_arn               = data.aws_lb_target_group.nlb_tg_group.arn
  service_desired_count          = var.service_desired_count
  task_definition_cpu            = var.task_definition_cpu
  task_definition_memory         = var.task_definition_memory
  icx_container_cpu              = var.icx_container_cpu
  icx_container_memory           = var.icx_container_memory
  enable_varnish                 = var.enable_varnish
  varnish_container_cpu          = var.varnish_container_cpu
  varnish_container_memory       = var.varnish_container_memory
  container_port                 = var.container_port
  environment                    = var.environment
  db_password_ssm_parameter_name = local.db_password_ssm_parameter_name
  db_username_ssm_parameter_name = local.db_username_ssm_parameter_name
  kms_name                       = local.kms_name
  tags                           = local.common_tags
}
