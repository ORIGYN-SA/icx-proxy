module "redis" {
  source                         = "../../../modules/redis"
  app_name_prefix                = local.name_prefix
  engine_version                 = var.engine_version
  environment                    = var.environment
  maintenance_window             = var.maintenance_window
  node_type                      = var.node_type
  num_cache_nodes                = var.num_cache_nodes
  parameter_group_name           = var.parameter_group_name
  redis_cluster                  = local.redis_cluster
  redis_port                     = var.redis_port
  redis_sg_name                  = local.redis_sg_name
  vps_name                       = var.vps_name
  db_username_ssm_parameter_name = local.db_username_ssm_parameter_name
  db_password_ssm_parameter_name = local.db_password_ssm_parameter_name
  tags                           = local.common_tags
}