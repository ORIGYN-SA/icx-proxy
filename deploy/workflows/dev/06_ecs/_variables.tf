variable "container_port" {}
variable "task_definition_cpu" {
  default = null
}
variable "task_definition_memory" {
  default = null
}
variable "icx_container_cpu" {
  default = null
}
variable "icx_container_memory" {
  default = null
}
variable "varnish_container_cpu" {
  default = null
}
variable "varnish_container_memory" {
  default = null
}
variable "service_desired_count" {}