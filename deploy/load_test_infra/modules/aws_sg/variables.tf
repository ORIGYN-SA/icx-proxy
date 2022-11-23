variable "vpc_id" {
  description = "The AWS VPC ID that this Security Group attaches to"
}

variable "master_name" {
  description = "The name of the Security Group"
  default     = "master"
}

variable "slave_name" {
  description = "The name of the Security Group"
  default     = "slave"
}
