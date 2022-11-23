resource "aws_key_pair" "locust_key" {
  key_name   = "locust-${var.cluster_name}-key"
  public_key = tls_private_key.temp.public_key_openssh
}

resource "tls_private_key" "temp" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "locust_security_groups" {
  source = "./modules/aws_sg"

  vpc_id      = data.aws_vpc.selected_vpc.id
  master_name = "locust-${var.cluster_name}-master"
  slave_name  = "locust-${var.cluster_name}-slave"
}

module "locust_master" {
  source = "./modules/aws_ec2"

  locust_role                 = "locust-${var.cluster_name}-master"
  ami                         = var.locust_ami
  instance_type               = var.locust_master_instance_type
  key_name                    = aws_key_pair.locust_key.key_name
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  security_group_ids          = [module.locust_security_groups.id_master]
  associate_public_ip_address = var.master_associate_public_ip_address
  root_volume_size            = var.root_volume_size
  root_volume_type            = var.root_volume_type
  root_volume_iops            = var.root_volume_iops
  user_data_base64 = base64encode(
    templatefile(
      "templates/master_locust.sh",
      {
        tests_file  = file("templates/test.py")
        target_host = var.target_host
    })
  )
}

resource "aws_launch_template" "template_slave_instance" {
  name_prefix            = "locust-${var.cluster_name}-slave"
  image_id               = var.locust_ami
  instance_type          = var.locust_slave_instance_type
  vpc_security_group_ids = [module.locust_security_groups.id_slave]
  key_name               = aws_key_pair.locust_key.key_name
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type = var.root_volume_type
      volume_size = var.root_volume_size
      iops        = var.root_volume_type == "io2" ? var.root_volume_iops : var.root_volume_type == "io1" ? var.root_volume_iops : null
    }
  }
  user_data = base64encode(
    templatefile(
      "templates/slave_locust.sh",
      {
        tests_file  = file("templates/test.py")
        target_host = var.target_host
        master_host = module.locust_master.locust_server_private_ip[0]
    })
  )
  depends_on = [module.locust_master]
}
resource "aws_autoscaling_group" "slave_autoscaling" {
  name                      = "locust-${var.cluster_name}-slave"
  vpc_zone_identifier       = data.aws_subnets.private_subnets.ids
  min_size                  = var.slave_min_size_count
  max_size                  = var.slave_max_size_count
  health_check_type         = "EC2"
  health_check_grace_period = 200
  force_delete              = true
  launch_template {
    id      = aws_launch_template.template_slave_instance.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "locust-${var.cluster_name}-slave"
    propagate_at_launch = true
  }
  depends_on = [aws_launch_template.template_slave_instance]
}
