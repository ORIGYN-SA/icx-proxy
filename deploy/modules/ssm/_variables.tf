variable "ssm_parameter_list" {
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
}
variable "kms_name" {}
variable "tags" {}