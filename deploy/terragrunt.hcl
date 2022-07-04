generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 0.13.1"
  required_providers {
    aws = ">= 3.50"
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  profile = "${local.aws_profile}"
  region  = "${local.aws_region}"
}
EOF
}

remote_state {
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  backend = "s3"
  config = {
    bucket  = "${local.aws_region}" == "us-east-1" ? "terraform-state-storage-us-east-1" : "terraform-state-storage2-eu-west-1"
    key     = "${local.application_name}/${local.environment}/${regex("[a-z]+", basename(get_terragrunt_dir()))}.tfstate"
    region  = "${local.aws_region}"
    profile = "origyn-root"
  }
}

locals {
  application_name       = "icx-proxy"
  name_prefix            = "tf-${local.application_name}"
  environment_short_name = "${local.environment}-${local.aws_region}"

  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  aws_profile = local.account_vars.locals.aws_profile
  aws_region  = local.region_vars.locals.aws_region
}

inputs = {
  vpc_name                       = "origyn-dev"
  ecs_cluster_name               = "${local.name_prefix}-cluster-${local.environment}"
  ecs_service_name               = "${local.name_prefix}-ecs-service-${local.environment_short_name}"
  image_tag_parameter_name       = "${local.name_prefix}-image-tag-${local.environment_short_name}"
  alb_name                       = "${local.name_prefix}-alb-${local.environment}"
  alb_sg_name                    = "${local.name_prefix}-alb-sg-${local.environment_short_name}"
  alb_tg_name                    = "${local.name_prefix}-alb-tg-${local.environment}"
  ecr_name                       = "${local.name_prefix}-${local.environment}"
  ecs_task_definition_name       = "${local.name_prefix}-task-${local.environment}"
  ecs_task_sg_name               = "${local.name_prefix}-ecs-task-sg-${local.environment_short_name}"
  ecs_task_sg                    = "${local.name_prefix}-ecs-task-sg-${local.environment_short_name}"
  redis_sg_name                  = "${local.name_prefix}-redis-sg-${local.environment_short_name}"
  redis_cluster                  = "${local.name_prefix}-redis-cluster-${local.environment_short_name}"
  kms_name                       = "${local.name_prefix}-kms-${local.environment_short_name}"
  db_username_ssm_parameter_name = "${local.name_prefix}-db-username-${local.environment_short_name}"
  db_password_ssm_parameter_name = "${local.name_prefix}-db-password-${local.environment_short_name}"
  tags = merge(local.account_vars.locals.tags, local.environment_vars.locals.tags,
    {
      "ogy:required:product"        = "${local.application_name}"
      "ogy:required:repository_url" = "https://github.com/ORIGYN-SA/icx-proxy"
      "ogy:required:provisioned_by" = "terraform"
  })
}
