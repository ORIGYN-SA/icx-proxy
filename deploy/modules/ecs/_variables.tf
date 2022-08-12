variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "ecs_task_definition_name" {}
variable "security_group_ids" {}
variable "private_subnet_ids" {}
variable "ecr_name" {}
variable "container_port" {}
variable "task_definition_cpu" {}
variable "task_definition_memory" {}
variable "icx_container_cpu" {}
variable "icx_container_memory" {}
variable "varnish_container_cpu" {}
variable "varnish_container_memory" {}
variable "service_desired_count" {}
variable "alb_tg_group_arn" {}
variable "environment" {}
variable "tags" {}
variable "enable_autoScaling" {
  default = false
}
variable "scale_target_max_capacity" {
  default = 5
}
variable "scale_target_min_capacity" {
  default = 1
}
variable "max_cpu_threshold" {
  default = "60"
}
variable "min_cpu_threshold" {
  default = "10"
}
variable "max_cpu_evaluation_period" {
  default = "3"
}
variable "min_cpu_evaluation_period" {
  default = "3"
}
variable "db_username_ssm_parameter_name" {}
variable "db_password_ssm_parameter_name" {}
variable "kms_name" {}
variable "app_name_prefix" {}
variable "enable_containerInsights" {
  default = "enabled"
}