variable "alb_sg_name" {}
variable "vpc_name" {}
variable "ecs_task_sg_name" {}
variable "redis_sg_name" {}
variable "container_port" {}
variable "redis_port" {}
variable "lb_sg_rules" {
  type = list(object({
    type        = string
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    description = string
  }))
}
variable "ecs_sg_rules" {
  type = list(object({
    type        = string
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    description = string
  }))
}
variable "redis_sg_rules" {
  type = list(object({
    type        = string
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    description = string
  }))
}
variable "tags" {
  type = map(any)
}