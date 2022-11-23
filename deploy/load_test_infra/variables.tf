variable "vps_name" {}

variable "target_host" {
  default = "google.com"
}

variable "cluster_name" {
  default = "testing"
}

variable "locust_ami" {
  default = "ami-08c40ec9ead489470"
}

variable "locust_master_instance_type" {
  default = "t2.micro"
}

variable "locust_slave_instance_type" {
  default = "t2.micro"
}
variable "root_volume_size" {
  default = "8"
}
variable "root_volume_type" {
  default = "gp2"
}
variable "root_volume_iops" {
  default = "100"
}
variable "master_associate_public_ip_address" {
  default = "true"
}
variable "slave_min_size_count" {
  default = 1
}
variable "slave_max_size_count" {
  default = 2
}