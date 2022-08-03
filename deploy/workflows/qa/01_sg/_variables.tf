variable "container_port" {}
variable "redis_port" {}
variable "lb_sg_rules" {
  default = null
}
variable "ecs_sg_rules" {
  default = null
}
variable "redis_sg_rules" {
  default = null
}