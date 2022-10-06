variable "health_check_path" {
  default = "/"
}
variable "tsl_certificate_arn" {}
variable "load_balancer_type" {
  default = "application"
}
variable "waf_enable" {
  default = false
}
variable "waf_web_acl_name" {
  default = ""
}
variable "container_port" {}
