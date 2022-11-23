resource "aws_instance" "locust_server" {
  key_name                    = var.key_name
  ami                         = var.ami
  instance_type               = var.instance_type
  vpc_security_group_ids      = var.security_group_ids
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  user_data_base64            = var.user_data_base64
  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    iops        = var.root_volume_type == "io2" ? var.root_volume_iops : var.root_volume_type == "io1" ? var.root_volume_iops : null
  }

  tags = {
    Name = var.locust_role
  }
}