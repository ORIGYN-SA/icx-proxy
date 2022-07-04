terraform {
  source = "../../../../modules/sg"
}

include "root" {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config("common.hcl")
}

inputs = merge(
  local.common_vars.inputs,
  {
    lb_sg_rules    = try(local.lb_sg_rules, local.common_vars.inputs.lb_default_sg_rules)
    ecs_sg_rules   = try(local.ecs_sg_rules, local.common_vars.inputs.ecs_default_sg_rules)
    redis_sg_rules = try(local.redis_sg_rules, local.common_vars.inputs.redis_default_sg_rules)
  }
)