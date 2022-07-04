variable "node_type" {}
variable "num_cache_nodes" {}
variable "redis_port" {
  default = 6379
}
variable "maintenance_window" {
  default = "Mon:03:00-Mon:06:00"
}
variable "parameter_group_name" {
  default = "default.redis6.x"
}
variable "engine_version" {
  default = "6.x"
}
