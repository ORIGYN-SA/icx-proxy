variable "node_type" {}
variable "num_cache_nodes" {}
variable "redis_port" {}
variable "maintenance_window" {
  type    = string
  default = "Mon:03:00-Mon:06:00"
}
variable "parameter_group_name" {
  type    = string
  default = "default.redis6.x"
}

variable "engine_version" {
  type    = string
  default = "6.x"
}