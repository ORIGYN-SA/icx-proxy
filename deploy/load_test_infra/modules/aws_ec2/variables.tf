variable "key_name" {
  description = "The name of the PKI key pair to use"
  type        = string
}

variable "locust_role" {
  description = "The role of the server.  Either master or slave"
  type        = string
}

variable "ami" {
  description = "The AWS AMI to use"
  type        = string
}

variable "instance_type" {
  description = "The AWS AMI to use"
  type        = string
}

variable "subnet_id" {
  description = "The AWS VPC Subnet ID"
}

variable "security_group_ids" {
  description = "The AWS Security Group Ids"
  type        = list(string)
}

variable "root_volume_size" {
  description = "The AWS EC2 root volume size"
}

variable "root_volume_type" {
  description = "The AWS EC2 root volume type"
}

variable "root_volume_iops" {
  description = "The AWS EC2 root volume iops"
}

variable "associate_public_ip_address" {
  description = "Enabled public IP"
}

variable "user_data_base64" {
  default = null
}

